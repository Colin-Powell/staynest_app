import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:property_app/theme.dart';

import 'package:property_app/services/routing_service.dart';

// ─── Transport Mode Model ─────────────────────────────────────────────────────

enum _TransportMode { drive, walk, bike, matatu }

class _ModeData {
  final _TransportMode mode;
  final String label;
  final String duration;

  const _ModeData({
    required this.mode,
    required this.label,
    required this.duration,
  });
}

// ─── Main Widget ──────────────────────────────────────────────────────────────

class CommuteMethodsView extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onStartNavigation;

  const CommuteMethodsView({
    super.key,
    required this.onClose,
    this.onStartNavigation,
  });

  @override
  State<CommuteMethodsView> createState() => _CommuteMethodsViewState();
}

class _CommuteMethodsViewState extends State<CommuteMethodsView>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  bool _fetchingLocation = false;
  LatLng? _currentLocation;

  _TransportMode _selectedMode = _TransportMode.drive;
  final _fromController = TextEditingController(text: 'Current location');
  final _toController = TextEditingController(text: 'Majengo, Kilifi');
  final List<String> _placeSuggestions = [
    'Majengo, Kilifi',
    'Mtwapa, Kilifi',
    'Matuga, Kilifi',
    'Kilifi Creek Bridge',
    'Malindi, Kilifi',
  ];
  List<String> _filteredSuggestions = [];
  bool _isRouteLoading = false;
  List<LatLng> _routePoints = const [
    LatLng(-3.6305, 39.8499),
    LatLng(-3.6200, 39.8450),
  ];
  LatLng _origin = const LatLng(-3.6305, 39.8499);
  LatLng _destination = const LatLng(-3.6200, 39.8450);

  static const _modes = [
    _ModeData(mode: _TransportMode.drive, label: 'Drive', duration: '12 min'),
    _ModeData(mode: _TransportMode.walk, label: 'Walk', duration: '29 min'),
    _ModeData(mode: _TransportMode.bike, label: 'Bike', duration: '34 min'),
    _ModeData(mode: _TransportMode.matatu, label: 'Matatu', duration: '16 min'),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim =
        Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _filteredSuggestions = List.from(_placeSuggestions);
    _toController.addListener(_onDestinationChanged);
    _animController.forward();
    _initializeLocation();
  }

  @override
  void dispose() {
    _animController.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    if (_fetchingLocation) return;
    _fetchingLocation = true;

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _fetchingLocation = false;
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      _fetchingLocation = false;
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _fromController.text = 'Current location';
          _origin = _currentLocation!;
        });
        _mapController.move(_origin, 15);
        await _updateRoute();
      }
    } catch (e) {
      debugPrint('Commute location error: $e');
    }

    _fetchingLocation = false;
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRouteInputs(),
                          const SizedBox(height: 32),
                          _buildModeSelector(),
                          const SizedBox(height: 36),
                          _buildSectionTitle('Best Routes'),
                          const SizedBox(height: 16),
                          _buildMapSection(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Floating bottom button
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                left: 24,
                right: 24,
                child: _buildBottomBar(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 24,
        right: 24,
        bottom: 16,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onClose,
            behavior: HitTestBehavior.opaque,
            child: const Icon(Icons.arrow_back, size: 28, color: Colors.black),
          ),
          const SizedBox(width: 16),
          const Text(
            'Commute Estimation',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Route Inputs ───────────────────────────────────────────────────────────

  Widget _buildRouteInputs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual Route Indicators
          Container(
            width: 24,
            margin: const EdgeInsets.only(top: 23),
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFF9CA3AF), width: 1.5),
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 15),
                const Icon(Icons.location_on_outlined,
                    color: Color(0xFFEF4444), size: 24),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Text Fields
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: const Color(0xFF3F37C9), width: 1.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _fromController,
                          readOnly: true,
                          onTap: _initializeLocation,
                          style: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'From',
                            hintStyle: TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _initializeLocation,
                        child: const Icon(Icons.my_location,
                            color: Colors.black, size: 22),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _toController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _updateRoute(),
                          style: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Enter destination',
                            hintStyle: TextStyle(
                                color: Colors.black54,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _updateRoute,
                        child: const Icon(Icons.search,
                            color: Colors.black, size: 24),
                      ),
                    ],
                  ),
                ),
                if (_filteredSuggestions.isNotEmpty &&
                    _toController.text.trim().isNotEmpty)
                  _buildSuggestionList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionList() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFe5e7eb)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 6)),
          ],
        ),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredSuggestions.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
          itemBuilder: (context, index) {
            final suggestion = _filteredSuggestions[index];
            return ListTile(
              title: Text(suggestion,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              leading: const Icon(Icons.location_on_outlined,
                  color: Color(0xFF3F37C9)),
              onTap: () {
                _toController.text = suggestion;
                _filteredSuggestions = [];
                _updateRoute();
              },
            );
          },
        ),
      ),
    );
  }

  void _onDestinationChanged() {
    final query = _toController.text.trim();
    setState(() {
      _filteredSuggestions = query.isEmpty
          ? List.from(_placeSuggestions)
          : _placeSuggestions
              .where((p) => p.toLowerCase().contains(query.toLowerCase()))
              .toList();
    });
  }

  Future<void> _updateRoute() async {
    final query = _toController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isRouteLoading = true;
      _filteredSuggestions = [];
    });

    _destination = _placeToLocation(query);
    final points =
        await fetchRouteOsrm(_origin, _destination).catchError((_) => [
              _origin,
              _destination,
            ]);

    setState(() {
      _routePoints = points.isNotEmpty ? points : [_origin, _destination];
      _isRouteLoading = false;
    });
  }

  LatLng _placeToLocation(String place) {
    final text = place.toLowerCase();
    if (text.contains('majengo')) return const LatLng(-3.6200, 39.8450);
    if (text.contains('mtwapa')) return const LatLng(-3.6315, 39.8550);
    if (text.contains('matuga')) return const LatLng(-3.6500, 39.8310);
    if (text.contains('kilifi creek')) return const LatLng(-3.6325, 39.8600);
    if (text.contains('malindi')) return const LatLng(-3.2170, 40.1164);
    return _destination;
  }
  // ─── Mode Selector ──────────────────────────────────────────────────────────

  Widget _buildModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: _modes.map((m) {
          final isSelected = m.mode == _selectedMode;
          final isLast = m == _modes.last;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: isLast ? 0 : 12),
              child: GestureDetector(
                onTap: () => setState(() => _selectedMode = m.mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : const Color(0xFFF3F4F6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        m.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? const Color(0xFF3F37C9)
                              : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m.duration,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Section Title ──────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
      ),
    );
  }

  // ─── Map Section ────────────────────────────────────────────────────────────

  Widget _buildMapSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: StayNestColors.surfaceVariantLight,
            boxShadow: AppShadow.sm,
          ),
          child: SizedBox(
            height: 380,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    center: _origin,
                    zoom: 14,
                    interactiveFlags:
                        InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.example.property_app',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          color: const Color(0xFF3B82F6).withOpacity(0.75),
                          strokeWidth: 6,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _origin,
                          width: 120,
                          height: 120,
                          child: const _MapPin(),
                        ),
                        Marker(
                          point: _destination,
                          width: 140,
                          height: 46,
                          child: const _PropertyMarker(isActive: true),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_isRouteLoading)
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Colors.black26),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Bottom Bar ─────────────────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context) {
    return ElevatedButton(
      onPressed: widget.onStartNavigation ?? () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3F37C9),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
      ),
      child: const Text(
        'Start Navigation',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ─── Property Marker ──────────────────────────────────────────────────────────

class _PropertyMarker extends StatelessWidget {
  final bool isActive;
  const _PropertyMarker({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF3F37C9) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage('assets/images/hero.jpg'), // Mock image
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '11 Green Bank',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isActive ? Colors.white : Colors.black,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'Ksh.12k/month',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: isActive ? Colors.white : const Color(0xFF3F37C9),
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
        // Small pointer triangle
        if (isActive)
          Container(
            width: 10,
            height: 6,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF3F37C9), width: 6),
                left: BorderSide(color: Colors.transparent, width: 5),
                right: BorderSide(color: Colors.transparent, width: 5),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Map Pin ──────────────────────────────────────────────────────────────────

class _MapPin extends StatefulWidget {
  const _MapPin();

  @override
  State<_MapPin> createState() => _MapPinState();
}

class _MapPinState extends State<_MapPin> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: false);

    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Vision cone simulation
        Positioned(
          top: 60, // center
          left: 60, // center
          child: Transform.rotate(
            angle: math.pi / 4, // point southeast
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3B82F6).withOpacity(0.4),
                    const Color(0xFF3B82F6).withOpacity(0.0),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(80),
                ),
              ),
            ),
          ),
        ),

        // Pulsing rings
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, _) {
            return Container(
              width: 24 + (_pulseAnim.value * 60),
              height: 24 + (_pulseAnim.value * 60),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    const Color(0xFF3B82F6).withOpacity(1.0 - _pulseAnim.value),
              ),
            );
          },
        ),

        // Inner solid dot
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
