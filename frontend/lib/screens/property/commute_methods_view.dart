// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:property_app/models/property.dart';
import 'package:property_app/services/property_service.dart';

// ─── Transport Mode ───────────────────────────────────────────────────────────

enum _TransportMode { drive, walk, bike, matatu }

class _ModeData {
  final _TransportMode mode;
  final String label;
  final IconData icon;
  final String osrmProfile; // OSRM routing profile

  const _ModeData({
    required this.mode,
    required this.label,
    required this.icon,
    required this.osrmProfile,
  });
}

// ─── Route Result ─────────────────────────────────────────────────────────────

class _RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationSeconds; // Raw OSRM duration

  const _RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationSeconds,
  });
}

// ─── OSRM Routing Service ─────────────────────────────────────────────────────

Future<_RouteResult?> _fetchOsrmRoute(
  LatLng origin,
  LatLng destination,
  String profile, // 'driving', 'walking', 'cycling'
) async {
  try {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/$profile/'
      '${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=geojson&steps=false',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if ((data['routes'] as List?)?.isEmpty ?? true) return null;

    final route = data['routes'][0] as Map<String, dynamic>;
    final distanceMeters = (route['distance'] as num).toDouble();
    final durationSec = (route['duration'] as num).toInt();

    final coords = (route['geometry']['coordinates'] as List).map((c) {
      final pair = c as List;
      return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
    }).toList();

    return _RouteResult(
      points: coords,
      distanceKm: distanceMeters / 1000.0,
      durationSeconds: durationSec,
    );
  } catch (_) {
    return null;
  }
}

// Matatu: use driving route + wait/transfer overhead
Future<_RouteResult?> _fetchMatatuRoute(
    LatLng origin, LatLng destination) async {
  final base = await _fetchOsrmRoute(origin, destination, 'driving');
  if (base == null) return null;

  // Matatu is slower than private car due to stops; add 35% to duration + 10 min wait
  const waitSeconds = 600; // 10 min average wait
  final adjustedDuration = (base.durationSeconds * 1.35).toInt() + waitSeconds;

  return _RouteResult(
    points: base.points,
    distanceKm: base.distanceKm,
    durationSeconds: adjustedDuration,
  );
}

String _formatDuration(int seconds) {
  if (seconds <= 0) return '--';
  final mins = (seconds / 60).round();
  if (mins >= 60) {
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
  return '${mins}m';
}

// ─── Main Widget ──────────────────────────────────────────────────────────────

class CommuteMethodsView extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onStartNavigation;
  final LatLng? targetLocation;
  final String? targetName;
  final Property? targetProperty;

  const CommuteMethodsView({
    super.key,
    required this.onClose,
    this.onStartNavigation,
    this.targetLocation,
    this.targetName,
    this.targetProperty,
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

  // Theme
  static const Color _primaryText = Color(0xFF3F37C9);
  static const Color _dark = Color(0xFF111827);
  static const Color _grey = Color(0xFF9CA3AF);
  static const Color _surface = Color(0xFFF8F8FF);

  // State
  final ValueNotifier<LatLng?> _locationNotifier = ValueNotifier(null);
  final ValueNotifier<double> _headingNotifier = ValueNotifier(0);

  bool _fetchingLocation = true;
  _TransportMode _selectedMode = _TransportMode.drive;

  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  bool _isRouteLoading = false;
  bool _isNavigating = false;
  bool _isRecenterPending = false; // User dragged away from GPS dot

  // Route data per mode (cached)
  final Map<_TransportMode, _RouteResult?> _routeCache = {};
  _RouteResult? get _activeRoute => _routeCache[_selectedMode];

  late LatLng _destination;
  LatLng? _lastRoutedLocation;

  Property? _activeProperty;
  Property? _hoveredProperty; // Tooltip on map
  List<Property> _allProperties = [];

  StreamSubscription<Position>? _positionStream;
  List<Map<String, dynamic>> _filteredSuggestions = [];
  Timer? _debounceTimer;
  Timer? _recenterTimer;

  int _cameraFrame = 0;

  static List<_ModeData> get _modes => [
        _ModeData(
            mode: _TransportMode.drive,
            label: 'Drive',
            icon: PhosphorIcons.carProfile(PhosphorIconsStyle.fill),
            osrmProfile: 'driving'),
        _ModeData(
            mode: _TransportMode.walk,
            label: 'Walk',
            icon: PhosphorIcons.sneaker(PhosphorIconsStyle.fill),
            osrmProfile: 'walking'),
        _ModeData(
            mode: _TransportMode.bike,
            label: 'Bike',
            icon: PhosphorIcons.bicycle(PhosphorIconsStyle.fill),
            osrmProfile: 'cycling'),
        _ModeData(
            mode: _TransportMode.matatu,
            label: 'Matatu',
            icon: PhosphorIcons.van(PhosphorIconsStyle.fill),
            osrmProfile: 'driving'),
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

    if (widget.targetProperty != null) {
      _activeProperty = widget.targetProperty;
      _toController.text = widget.targetProperty!.name;
    } else if (widget.targetName != null) {
      _toController.text = widget.targetName!;
    }

    _destination = widget.targetLocation ??
        (widget.targetProperty != null
            ? LatLng(widget.targetProperty!.lat, widget.targetProperty!.lng)
            : const LatLng(-3.6305, 39.8499));

    _animController.forward();
    _initializeData();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _debounceTimer?.cancel();
    _recenterTimer?.cancel();
    _animController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _locationNotifier.dispose();
    _headingNotifier.dispose();
    super.dispose();
  }

  // ─── Initialization ─────────────────────────────────────────────────────────

  Future<void> _initializeData() async {
    setState(() => _fetchingLocation = true);

    // Load nearby properties in parallel with location
    try {
      _allProperties = await PropertyService.instance.fetchProperties();
    } catch (_) {}

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _finishLoadingLocation('Location disabled');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      _finishLoadingLocation('Permission denied');
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      final loc = LatLng(position.latitude, position.longitude);
      _locationNotifier.value = loc;

      setState(() {
        _fromController.text = 'Current Location';
        _fetchingLocation = false;
      });

      _fitMapBounds();
      _fetchAllRoutes(); // Pre-fetch all mode routes
    } catch (e) {
      _finishLoadingLocation('Location error');
    }
  }

  void _finishLoadingLocation(String fallback) {
    if (mounted) {
      setState(() {
        _fetchingLocation = false;
        _fromController.text = fallback;
      });
    }
  }

  // Placeholder for a function to get LatLng from a city name
  Future<LatLng?> _getLatLngForCity(String city) async {
    // Implement actual geocoding API call here (e.g., Google Maps Geocoding API)
    return null; // Return null if not found or error
  }

  // ─── Routing ────────────────────────────────────────────────────────────────

  /// Fetch routes for all modes in parallel and cache them
  Future<void> _fetchAllRoutes() async {
    final origin = _locationNotifier.value;
    if (origin == null) return;

    setState(() => _isRouteLoading = true);

    for (final modeData in _modes) {
      _RouteResult? result;
      if (modeData.mode == _TransportMode.matatu) {
        result = await _fetchMatatuRoute(origin, _destination);
      } else {
        result = await _fetchOsrmRoute(origin, _destination, modeData.osrmProfile);
      }

      if (mounted) {
        setState(() {
          _routeCache[modeData.mode] = result;
        });
      }
    }
    _lastRoutedLocation = origin;

    if (mounted) setState(() => _isRouteLoading = false);
  }

  /// Re-route only for active mode (used during navigation rerouting)
  Future<void> _rerouteActive() async {
    final origin = _locationNotifier.value;
    if (origin == null) return;

    final modeData = _modes.firstWhere((m) => m.mode == _selectedMode);
    _RouteResult? result;
    if (_selectedMode == _TransportMode.matatu) {
      result = await _fetchMatatuRoute(origin, _destination);
    } else {
      result =
          await _fetchOsrmRoute(origin, _destination, modeData.osrmProfile);
    }

    if (mounted && result != null) {
      setState(() => _routeCache[_selectedMode] = result);
      _lastRoutedLocation = origin;
    }
  }

  void _fitMapBounds() {
    final origin = _locationNotifier.value;
    if (origin == null) return;

    final points = [origin, _destination];
    if (_activeRoute != null) points.addAll(_activeRoute!.points);

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitBounds(
      bounds,
      options: const FitBoundsOptions(padding: EdgeInsets.all(80)),
    );
  }

  // ─── Geocoding Autocomplete ─────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.isEmpty) {
      setState(() => _filteredSuggestions = []);
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final url = Uri.parse(
          'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=5',
        );
        final res = await http.get(url);
        if (res.statusCode == 200 && mounted) {
          final data = json.decode(res.body) as Map<String, dynamic>;
          setState(() => _filteredSuggestions =
              List<Map<String, dynamic>>.from(data['features'] as List));
        }
      } catch (_) {}
    });
  }

  // ─── Navigation ─────────────────────────────────────────────────────────────

  void _startNavigation() async {
    final origin = _locationNotifier.value;
    if (origin == null) return;

    if (_activeRoute == null) await _fetchAllRoutes();

    setState(() {
      _isNavigating = true;
      _isRecenterPending = false;
    });

    _cameraFrame = 0;
    _mapController.move(origin, 18.0);
    _mapController.rotate(0);

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      ),
    ).listen((Position pos) {
      if (!mounted || !_isNavigating) return;

      // EMA smoothing
      final old = _locationNotifier.value;
      final smoothed = old != null
          ? LatLng(
              old.latitude * 0.75 + pos.latitude * 0.25,
              old.longitude * 0.75 + pos.longitude * 0.25,
            )
          : LatLng(pos.latitude, pos.longitude);

      _locationNotifier.value = smoothed;

      // Update heading if available
      if (pos.heading >= 0) {
        _headingNotifier.value = pos.heading;
      }

      // Throttled camera follow (every 2nd update)
      _cameraFrame++;
      if (_cameraFrame % 2 == 0 && !_isRecenterPending) {
        _mapController.move(smoothed, 18.0);
      }

      // Smart rerouting (> 60m off last routed origin)
      if (_lastRoutedLocation != null) {
        final drift = const Distance()
            .as(LengthUnit.Meter, smoothed, _lastRoutedLocation!);
        if (drift > 60) _rerouteActive();
      }
    });
  }

  void _exitNavigation() {
    _positionStream?.cancel();
    setState(() {
      _isNavigating = false;
      _isRecenterPending = false;
    });
    _headingNotifier.value = 0;
    _fitMapBounds();
  }

  void _recenterOnUser() {
    final loc = _locationNotifier.value;
    if (loc == null) return;
    setState(() => _isRecenterPending = false);
    _mapController.move(loc, 18.0);
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Scaffold(
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // 1. Full-bleed map
              Positioned.fill(child: _buildMap()),

              // 2. Top UI (header + search)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
                top: _isNavigating
                    ? -320
                    : MediaQuery.of(context).padding.top + 12,
                left: 16,
                right: 16,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 14),
                      _buildRouteInputs(),
                    ],
                  ),
                ),
              ),

              // 3. Bottom commute panel
              AnimatedPositioned(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
                bottom: _isNavigating
                    ? -300
                    : MediaQuery.of(context).padding.bottom + 24,
                left: 16,
                right: 16,
                child: _buildBottomPanel(),
              ),

              // 4. Navigation overlays
              if (_isNavigating) ...[
                // Close nav button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 20,
                  child: _GlassCircleButton(
                    icon: Icons.close_rounded,
                    color: Colors.redAccent,
                    onTap: _exitNavigation,
                    isNavigating: true,
                  ),
                ),
                // Recenter button (appears when user drags away)
                if (_isRecenterPending)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 16,
                    right: 20,
                    child: _GlassCircleButton(
                      icon: Icons.my_location_rounded,
                      color: _primaryText,
                      onTap: _recenterOnUser,
                      isNavigating: true,
                    ),
                  ),
                // Live nav info panel
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                  left: 16,
                  right: 16,
                  child: _buildLiveNavPanel(),
                ),
              ],

              // 5. Hovered property tooltip (map overlay)
              if (_hoveredProperty != null)
                Positioned(
                  bottom: _isNavigating
                      ? 160 + MediaQuery.of(context).padding.bottom
                      : 200 + MediaQuery.of(context).padding.bottom,
                  left: 16,
                  right: 16,
                  child: _buildPropertyPreviewCard(_hoveredProperty!),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    final routePoints = _activeRoute?.points ?? [];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter:
            _locationNotifier.value ?? const LatLng(-3.6305, 39.8499),
        initialZoom: 14,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        // Tile layer — CartoDB light (clean, Google-like)
        TileLayer(
          urlTemplate:
              'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'property_app',
        ),

        // Route polyline with casing (Google Maps style)
        if (routePoints.isNotEmpty) ...[
          PolylineLayer(
            polylines: [
              // White casing underneath
              Polyline(
                points: routePoints,
                color: Colors.white,
                strokeWidth: 10,
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
              // Colored route on top
              Polyline(
                points: routePoints,
                color: _primaryText.withOpacity(0.9),
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
            ],
          ),
        ],

        // Nearby property markers (not shown during navigation)
        if (!_isNavigating)
          MarkerLayer(
            markers: _allProperties
                .where((p) =>
                    p.lat != 0 &&
                    p.lng != 0 &&
                    p.id != (_activeProperty?.id ?? ''))
                .map((prop) => Marker(
                      point: LatLng(prop.lat, prop.lng),
                      width: 36,
                      height: 36,
                      child: GestureDetector(
                        onTap: () => setState(
                          () => _hoveredProperty =
                              _hoveredProperty?.id == prop.id ? null : prop,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: _hoveredProperty?.id == prop.id
                                ? _primaryText
                                : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _primaryText.withOpacity(0.4),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _dark.withOpacity(0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            PhosphorIcons.house(PhosphorIconsStyle.fill),
                            color: _hoveredProperty?.id == prop.id
                                ? Colors.white
                                : _primaryText,
                            size: 18,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),

        // Destination marker with tooltip label
        MarkerLayer(
          markers: [
            Marker(
              point: _destination,
              width: 120,
              height: 72,
              alignment: Alignment.bottomCenter,
              child: _DestinationMarker(
                label: _toController.text.isNotEmpty
                    ? _toController.text
                    : 'Destination',
              ),
            ),
          ],
        ),

        // GPS dot (ValueListenable — no full rebuild)
        ValueListenableBuilder<LatLng?>(
          valueListenable: _locationNotifier,
          builder: (context, loc, _) {
            if (loc == null) return const SizedBox.shrink();
            return ValueListenableBuilder<double>(
              valueListenable: _headingNotifier,
              builder: (context, heading, _) => MarkerLayer(
                markers: [
                  Marker(
                    point: loc,
                    width: 48,
                    height: 48,
                    child:
                        _GpsDot(heading: heading, isNavigating: _isNavigating),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _GlassCircleButton(
            icon: Icons.arrow_back_ios_new_rounded, onTap: widget.onClose),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Route Preview',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _dark,
              letterSpacing: -0.5,
            ),
          ),
        ),
        if (_isRouteLoading)
          const SizedBox(
            width: 20,
            height: 20,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: _primaryText),
          ),
      ],
    );
  }

  Widget _buildRouteInputs() {
    return Column(
      children: [
        // FROM input
        _GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          height: 48,
          opacity: 0.93,
          blur: 16,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Icon(PhosphorIcons.navigationArrow(PhosphorIconsStyle.fill),
                  color: _primaryText, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _fetchingLocation ? 'Fetching GPS…' : _fromController.text,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _fetchingLocation ? _grey : _dark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_fetchingLocation)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _primaryText),
                )
              else
                const Icon(Icons.my_location_rounded, color: _primaryText, size: 18),
            ],
          ),
        ),

        // Connector dot
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Column(
              children: List.generate(
                  3,
                  (_) => Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                            color: _grey.withOpacity(0.5),
                            shape: BoxShape.circle),
                      ))),
        ),

        // TO input
        _GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          height: 48,
          opacity: 0.93,
          blur: 16,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Icon(PhosphorIcons.flagBanner(PhosphorIconsStyle.fill),
                  color: const Color(0xFFEF4444), size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _toController,
                  readOnly: _activeProperty != null,
                  onChanged: _onSearchChanged,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _dark,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'Where to?',
                    hintStyle: GoogleFonts.poppins(color: _grey, fontSize: 14),
                  ),
                ),
              ),
              if (_activeProperty != null)
                GestureDetector(
                  onTap: () => setState(() {
                    _activeProperty = null;
                    _toController.clear();
                  }),
                  child: const Icon(Icons.close_rounded, color: _grey, size: 18),
                )
              else
                const Icon(Icons.search_rounded, color: _grey, size: 18),
            ],
          ),
        ),

        // Autocomplete suggestions
        if (_filteredSuggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _GlassContainer(
              padding: EdgeInsets.zero,
              opacity: 0.97,
              borderRadius: BorderRadius.circular(16),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredSuggestions.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: _grey.withOpacity(0.15)),
                itemBuilder: (context, i) {
                  final props = _filteredSuggestions[i]['properties'] as Map;
                  final name = props['name'] ??
                      props['street'] ??
                      props['city'] ??
                      'Unknown';
                  final subtitle = [props['city'], props['country']]
                      .where((v) => v != null)
                      .join(', ');
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined,
                        color: _primaryText, size: 20),
                    title: Text(name,
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _dark)),
                    subtitle: subtitle.isNotEmpty
                        ? Text(subtitle,
                            style:
                                GoogleFonts.poppins(fontSize: 11, color: _grey))
                        : null,
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      final coords = _filteredSuggestions[i]['geometry']
                          ['coordinates'] as List;
                      setState(() {
                        _toController.text = name;
                        _destination = LatLng((coords[1] as num).toDouble(),
                            (coords[0] as num).toDouble());
                        _activeProperty = null;
                        _filteredSuggestions = [];
                        _routeCache.clear();
                      });
                      _fetchAllRoutes();
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomPanel() {
    return _GlassContainer(
      padding: const EdgeInsets.all(20),
      opacity: 0.92,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Commute Options',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w800, color: _dark)),
              if (_activeRoute != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _primaryText.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_activeRoute!.distanceKm.toStringAsFixed(1)} km',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _primaryText),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Mode selector tabs
          Row(
            children: _modes.map((m) {
              final isSelected = m.mode == _selectedMode;
              final route = _routeCache[m.mode];
              final eta = route != null
                  ? _formatDuration(route.durationSeconds)
                  : (_isRouteLoading ? '…' : '--');

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedMode = m.mode);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: isSelected ? _primaryText : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : _grey.withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _primaryText.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Icon(m.icon,
                            color: isSelected ? Colors.white : _grey, size: 20),
                        const SizedBox(height: 5),
                        Text(
                          eta,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : _dark,
                          ),
                        ),
                        Text(
                          m.label,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? Colors.white.withOpacity(0.7)
                                : _grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Start Navigation button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: (_isRouteLoading ||
                      _locationNotifier.value == null ||
                      _activeRoute == null)
                  ? null
                  : _startNavigation,
              icon: _isRouteLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(PhosphorIcons.navigationArrow(PhosphorIconsStyle.fill),
                      size: 20),
              label: Text(
                _isRouteLoading ? 'Calculating routes…' : 'Start Navigation',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryText,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _grey.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveNavPanel() {
    return ValueListenableBuilder<LatLng?>(
      valueListenable: _locationNotifier,
      builder: (context, _, __) {
        final route = _activeRoute;
        return _GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          isNavigating: true,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      route != null
                          ? _formatDuration(route.durationSeconds)
                          : '--',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: _primaryText,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      route != null
                          ? '${route.distanceKm.toStringAsFixed(1)} km · via ${_modes.firstWhere((m) => m.mode == _selectedMode).label}'
                          : 'Calculating…',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _dark.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              // Mode icon badge
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _primaryText,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primaryText.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _modes.firstWhere((m) => m.mode == _selectedMode).icon,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPropertyPreviewCard(Property property) {
    return GestureDetector(
      onTap: () => setState(() => _hoveredProperty = null),
      child: _GlassContainer(
        padding: const EdgeInsets.all(14),
        opacity: 0.96,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _primaryText.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(PhosphorIcons.house(PhosphorIconsStyle.fill),
                  color: _primaryText, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    property.name,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _dark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _distanceLabel(property),
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _grey),
                  ),
                ],
              ),
            ),
            // Route to this property
            GestureDetector(
              onTap: () {
                setState(() {
                  _activeProperty = property;
                  _toController.text = property.name;
                  _destination = LatLng(property.lat, property.lng);
                  _hoveredProperty = null;
                  _routeCache.clear();
                });
                _fetchAllRoutes();
                _fitMapBounds();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _primaryText,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Route',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _distanceLabel(Property property) {
    final origin = _locationNotifier.value;
    if (origin == null) return 'Nearby property';
    final meters = const Distance()
        .as(LengthUnit.Meter, origin, LatLng(property.lat, property.lng));
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m away';
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }
}

// ─── Destination Marker with Tooltip Label ───────────────────────────────────

class _DestinationMarker extends StatelessWidget {
  final String label;

  const _DestinationMarker({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tooltip bubble
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        // Tooltip tail
        CustomPaint(
          size: const Size(10, 6),
          painter: _TooltipTailPainter(),
        ),
        // Flag pin
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.4),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            PhosphorIcons.flagBanner(PhosphorIconsStyle.fill),
            color: Colors.white,
            size: 13,
          ),
        ),
      ],
    );
  }
}

class _TooltipTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = ui.Paint()..color = const Color(0xFF111827);
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── GPS Dot (Heading Arrow + Pulse) ─────────────────────────────────────────

class _GpsDot extends StatefulWidget {
  final double heading;
  final bool isNavigating;

  const _GpsDot({required this.heading, required this.isNavigating});

  @override
  State<_GpsDot> createState() => _GpsDotState();
}

class _GpsDotState extends State<_GpsDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const dotColor = Color(0xFF3F37C9);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final pulseSize = 16.0 + (_pulse.value * 32.0);
        final pulseOpacity = (1.0 - _pulse.value) * 0.35;

        return Transform.rotate(
          angle: widget.isNavigating ? (widget.heading * math.pi / 180) : 0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulse ring
              Container(
                width: pulseSize,
                height: pulseSize,
                decoration: BoxDecoration(
                  color: dotColor.withOpacity(pulseOpacity),
                  shape: BoxShape.circle,
                ),
              ),
              // Accuracy ring
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: dotColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: dotColor.withOpacity(0.4), width: 1),
                ),
              ),
              // Core dot
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withOpacity(0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              // Heading cone (only during navigation)
              if (widget.isNavigating)
                Positioned(
                  top: 0,
                  child: CustomPaint(
                    size: const Size(14, 14),
                    painter: _HeadingConePainter(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HeadingConePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = ui.Paint()
      ..color = const Color(0xFF3F37C9).withOpacity(0.5)
      ..style = ui.PaintingStyle.fill;

     final path = ui.Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


// ─── Glass UI Utilities ───────────────────────────────────────────────────────

class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final bool isNavigating;

  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
    this.color = const Color(0xFF111827),
    this.isNavigating = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: isNavigating ? 0 : 12, sigmaY: isNavigating ? 0 : 12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  isNavigating ? Colors.white : Colors.white.withOpacity(0.65),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.85)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)
              ],
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final double blur;
  final double opacity;
  final double? height;
  final bool isNavigating;

  const _GlassContainer({required this.child, this.padding = EdgeInsets.zero, this.borderRadius, this.blur = 16.0, this.opacity = 0.1, this.borderWidth = 1.0});

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(22);

    if (isNavigating) {
      return Container(
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 20, offset: Offset(0, 4))
          ],
        ),
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: radius,
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 4))
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
