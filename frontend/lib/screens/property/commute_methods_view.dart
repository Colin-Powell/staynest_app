import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:property_app/models/property.dart';
import 'package:property_app/services/property_service.dart';
import 'package:property_app/services/cache_engine.dart';
import 'package:property_app/widgets/property_image.dart';

// ─── Tenant Design System Constants ───────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _primary = Color(0xFF087F73);
const Color _primarySoft = Color(0xFFE8F4F1);

// ─── Transport Mode ───────────────────────────────────────────────────────────

enum _TransportMode { drive, walk, bike, matatu }

class _ModeData {
  final _TransportMode mode;
  final String label;
  final IconData icon;
  final String routerProfile;

  const _ModeData({
    required this.mode,
    required this.label,
    required this.icon,
    required this.routerProfile,
  });
}

// ─── Route Result ─────────────────────────────────────────────────────────────

class _RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationSeconds;

  const _RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationSeconds,
  });
}

// ─── OSRM Routing Service (100% Free) ─────────────────────────────────────────

Future<_RouteResult?> _fetchOsmRoute(
    LatLng origin, LatLng destination, String routerProfile) async {
  try {
    // These public OSM-backed routers use distinct road graphs for cars,
    // pedestrians, and bicycles. The OSRM demo endpoint does not reliably
    // expose all three profiles.
    final url = Uri.parse(
      'https://routing.openstreetmap.de/routed-$routerProfile/route/v1/driving/'
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

Future<_RouteResult?> _fetchMatatuRoute(
    LatLng origin, LatLng destination) async {
  final base = await _fetchOsmRoute(origin, destination, 'car');
  if (base == null) return null;

  const waitSeconds = 600; // 10 min average wait
  final adjustedDuration = (base.durationSeconds * 1.35).toInt() + waitSeconds;

  return _RouteResult(
    points: base.points,
    distanceKm: base.distanceKm,
    durationSeconds: adjustedDuration,
  );
}

Map<String, dynamic> _routeToMap(_RouteResult route) => {
      'points': route.points
          .map((point) => {'lat': point.latitude, 'lng': point.longitude})
          .toList(),
      'distanceKm': route.distanceKm,
      'durationSeconds': route.durationSeconds,
    };

_RouteResult? _routeFromMap(Map<String, dynamic> data) {
  final points = data['points'];
  if (points is! List || points.isEmpty) return null;
  final parsedPoints = <LatLng>[];
  for (final point in points) {
    if (point is! Map) return null;
    final lat = double.tryParse(point['lat']?.toString() ?? '');
    final lng = double.tryParse(point['lng']?.toString() ?? '');
    if (lat == null || lng == null) return null;
    parsedPoints.add(LatLng(lat, lng));
  }
  final distanceKm = double.tryParse(data['distanceKm']?.toString() ?? '');
  final durationSeconds =
      int.tryParse(data['durationSeconds']?.toString() ?? '');
  if (distanceKm == null || durationSeconds == null) return null;
  return _RouteResult(
    points: parsedPoints,
    distanceKm: distanceKm,
    durationSeconds: durationSeconds,
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

  final ValueNotifier<LatLng?> _locationNotifier = ValueNotifier(null);
  final ValueNotifier<double> _headingNotifier = ValueNotifier(0);

  bool _fetchingLocation = true;
  _TransportMode _selectedMode = _TransportMode.drive;
  String? _locationError;
  Set<_TransportMode> _failedModes = {};
  bool _searchLoading = false;
  String? _searchError;
  int _searchRequestId = 0;

  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  bool _isRouteLoading = false;
  bool _isNavigating = false;
  bool _isRecenterPending = false;

  final Map<_TransportMode, _RouteResult?> _routeCache = {};
  _RouteResult? get _activeRoute => _routeCache[_selectedMode];

  LatLng? _destination;
  LatLng? _lastRoutedLocation;

  Property? _activeProperty;
  Property? _hoveredProperty;
  List<Property> _allProperties = [];

  StreamSubscription<Position>? _positionStream;
  List<Map<String, dynamic>> _filteredSuggestions = [];
  Timer? _debounceTimer;
  int _cameraFrame = 0;

  static List<_ModeData> get _modes => [
        const _ModeData(
            mode: _TransportMode.drive,
            label: 'Drive',
            icon: PhosphorIconsFill.carProfile,
            routerProfile: 'car'),
        const _ModeData(
            mode: _TransportMode.walk,
            label: 'Walk',
            icon: PhosphorIconsFill.sneaker,
            routerProfile: 'foot'),
        const _ModeData(
            mode: _TransportMode.bike,
            label: 'Bike',
            icon: PhosphorIconsFill.bicycle,
            routerProfile: 'bike'),
        const _ModeData(
            mode: _TransportMode.matatu,
            label: 'Matatu',
            icon: PhosphorIconsFill.van,
            routerProfile: 'car'),
      ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _animController, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);

    if (widget.targetProperty != null) {
      _activeProperty = widget.targetProperty;
      _toController.text = widget.targetProperty!.name;
    } else if (widget.targetName != null) {
      _toController.text = widget.targetName!;
    }

    final prop = widget.targetProperty;
    final hasPropCoords = prop != null && prop.lat != 0 && prop.lng != 0;
    _destination = widget.targetLocation ??
        (hasPropCoords ? LatLng(prop!.lat, prop.lng) : null);

    _animController.forward();
    _initializeData();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _debounceTimer?.cancel();
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

    try {
      _allProperties = await PropertyService.instance.fetchProperties();
    } catch (_) {}

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _finishLoadingLocation(
        error: 'Turn on location services to calculate travel times.',
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      _finishLoadingLocation(
        error: 'Allow location access in your browser settings, then retry.',
      );
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      final loc = LatLng(position.latitude, position.longitude);
      _locationNotifier.value = loc;

      setState(() {
        _fromController.text = 'Current Location';
        _fetchingLocation = false;
        _locationError = null;
      });

      _fitMapBounds();
      _fetchAllRoutes();
    } catch (e) {
      _finishLoadingLocation(
        error: 'Could not read your location. Check permissions and try again.',
      );
    }
  }

  void _finishLoadingLocation({required String error}) {
    if (mounted) {
      setState(() {
        _fetchingLocation = false;
        _fromController.text = 'Current location unavailable';
        _locationError = error;
      });
      _fitMapBounds();
      _fetchAllRoutes();
    }
  }

  // ─── Routing ────────────────────────────────────────────────────────────────

  Future<void> _fetchAllRoutes() async {
    final origin = _locationNotifier.value;
    final destination = _destination;
    if (origin == null || destination == null) return;

    setState(() => _isRouteLoading = true);
    final failedModes = <_TransportMode>{};

    for (final modeData in _modes) {
      final cacheKey =
          'route_v3_${origin.latitude.toStringAsFixed(4)}_${origin.longitude.toStringAsFixed(4)}_${destination.latitude.toStringAsFixed(4)}_${destination.longitude.toStringAsFixed(4)}_${modeData.routerProfile}';
      _RouteResult? result;
      try {
        final cached =
            await CacheEngine.instance.getOrFetch<Map<String, dynamic>>(
          key: cacheKey,
          ttl: const Duration(hours: 6),
          networkFetcher: () async {
            final route = modeData.mode == _TransportMode.matatu
                ? await _fetchMatatuRoute(origin, destination)
                : await _fetchOsmRoute(
                    origin, destination, modeData.routerProfile);
            if (route == null) throw StateError('Route unavailable');
            return _routeToMap(route);
          },
        );
        result = _routeFromMap(cached);
      } catch (_) {
        failedModes.add(modeData.mode);
      }

      if (mounted) setState(() => _routeCache[modeData.mode] = result);
    }

    _lastRoutedLocation = origin;
    if (mounted) {
      setState(() {
        _isRouteLoading = false;
        _failedModes = failedModes;
      });
    }
    _fitMapBounds();
  }

  Future<void> _retryRoutes() async {
    if (_locationNotifier.value == null) {
      await _initializeData();
      return;
    }
    await _fetchAllRoutes();
  }

  Future<void> _rerouteActive() async {
    final origin = _locationNotifier.value;
    final destination = _destination;
    if (origin == null || destination == null) return;

    final modeData = _modes.firstWhere((m) => m.mode == _selectedMode);
    _RouteResult? result;
    if (_selectedMode == _TransportMode.matatu) {
      result = await _fetchMatatuRoute(origin, destination);
    } else {
      result =
          await _fetchOsmRoute(origin, destination, modeData.routerProfile);
    }

    if (mounted && result != null) {
      setState(() => _routeCache[_selectedMode] = result);
      _lastRoutedLocation = origin;
    }
  }

  void _fitMapBounds() {
    final origin = _locationNotifier.value;
    final destination = _destination;
    if (destination == null) return;
    final points = <LatLng>[destination];
    if (origin != null) points.add(origin);
    if (_activeRoute != null) points.addAll(_activeRoute!.points);

    if (points.length > 1) {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitBounds(bounds,
          options: const FitBoundsOptions(padding: EdgeInsets.all(80)));
    } else if (points.isNotEmpty) {
      _mapController.move(points.first, 14.5);
    }
  }

  // ─── Autocomplete (Photon API - Free) ───────────────────────────────────────

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final requestId = ++_searchRequestId;
    if (query.isEmpty) {
      setState(() {
        _filteredSuggestions = [];
        _searchLoading = false;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _searchLoading = true;
      _searchError = null;
    });
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final url = Uri.parse(
            'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=5');
        final res = await http.get(url);
        if (!mounted || requestId != _searchRequestId) return;
        if (res.statusCode != 200) throw StateError('Search unavailable');
        final data = json.decode(res.body) as Map<String, dynamic>;
        final features = List<Map<String, dynamic>>.from(
            data['features'] as List? ?? const []);
        setState(() {
          _filteredSuggestions = features;
          _searchLoading = false;
          _searchError = features.isEmpty
              ? 'No places found. Try a neighborhood or nearby landmark.'
              : null;
        });
      } catch (_) {
        if (!mounted || requestId != _searchRequestId) return;
        setState(() {
          _filteredSuggestions = [];
          _searchLoading = false;
          _searchError =
              'Search is unavailable. Check your connection and try again.';
        });
      }
    });
  }

  // ─── Navigation ─────────────────────────────────────────────────────────────

  void _startNavigation() async {
    final origin = _locationNotifier.value;
    if (origin == null) return;

    if (_activeRoute == null) await _fetchAllRoutes();
    if (!mounted || _activeRoute == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No route is available. Retry or choose another mode.'),
        ),
      );
      return;
    }

    setState(() {
      _isNavigating = true;
      _isRecenterPending = false;
    });

    _cameraFrame = 0;
    _mapController.move(origin, 18.0);
    _mapController.rotate(0);

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 2),
    ).listen((Position pos) {
      if (!mounted || !_isNavigating) return;

      final old = _locationNotifier.value;
      final smoothed = old != null
          ? LatLng(old.latitude * 0.75 + pos.latitude * 0.25,
              old.longitude * 0.75 + pos.longitude * 0.25)
          : LatLng(pos.latitude, pos.longitude);

      _locationNotifier.value = smoothed;

      if (pos.heading >= 0) _headingNotifier.value = pos.heading;

      _cameraFrame++;
      if (_cameraFrame % 2 == 0 && !_isRecenterPending) {
        _mapController.move(smoothed, 18.0);
      }

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

  Future<void> _openDirectionsNative(double destLat, double destLng) async {
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&travelmode=driving');
    try {
      final launched =
          await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
      if (!launched) await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch maps.')));
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_destination == null) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Text(
            'This property does not have a valid location yet.',
            style:
                GoogleFonts.poppins(color: _dark, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Scaffold(
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset: false,
          backgroundColor: _surface,
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
                    : MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
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
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 20,
                  child: _SolidCircleButton(
                    icon: PhosphorIconsRegular.x,
                    color: Colors.redAccent,
                    onTap: _exitNavigation,
                  ),
                ),
                if (_isRecenterPending)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 16,
                    right: 20,
                    child: _SolidCircleButton(
                      icon: PhosphorIconsRegular.crosshair,
                      color: _primary,
                      onTap: _recenterOnUser,
                    ),
                  ),
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                  left: 16,
                  right: 16,
                  child: _buildLiveNavPanel(),
                ),
              ],

              // 5. Hovered property tooltip
              if (_hoveredProperty != null && !_isNavigating)
                Positioned(
                  bottom: 220 + MediaQuery.of(context).padding.bottom,
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
    final destination = _destination;
    if (destination == null) return const SizedBox.shrink();
    final routePoints = _activeRoute?.points ?? [];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _locationNotifier.value ?? destination,
        initialZoom: 14,
        interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom |
                InteractiveFlag.drag |
                InteractiveFlag.doubleTapZoom |
                InteractiveFlag.scrollWheelZoom),
        onPositionChanged: (pos, hasGesture) {
          if (hasGesture && _isNavigating && !_isRecenterPending) {
            setState(() => _isRecenterPending = true);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'property_app',
        ),
        if (routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                  points: routePoints,
                  color: Colors.white,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  strokeJoin: StrokeJoin.round),
              Polyline(
                  points: routePoints,
                  color: _primary,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  strokeJoin: StrokeJoin.round),
            ],
          ),
        if (!_isNavigating)
          MarkerLayer(
            markers: _allProperties
                .where((p) =>
                    p.lat != 0 &&
                    p.lng != 0 &&
                    p.id != (_activeProperty?.id ?? ''))
                .map((prop) => Marker(
                      point: LatLng(prop.lat, prop.lng),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _hoveredProperty =
                              _hoveredProperty?.id == prop.id ? null : prop);
                          _mapController.move(LatLng(prop.lat, prop.lng), 15);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: _hoveredProperty?.id == prop.id
                                ? _primary
                                : _surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: _primary.withOpacity(0.4), width: 2),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: Icon(PhosphorIconsFill.house,
                              color: _hoveredProperty?.id == prop.id
                                  ? Colors.white
                                  : _primary,
                              size: 20),
                        ),
                      ),
                    ))
                .toList(),
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: destination,
              width: 120,
              height: 72,
              alignment: Alignment.bottomCenter,
              child: _DestinationMarker(
                  label: _toController.text.isNotEmpty
                      ? _toController.text
                      : 'Destination'),
            ),
          ],
        ),
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
                      child: _GpsDot(
                          heading: heading, isNavigating: _isNavigating))
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onClose,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration:
                  const BoxDecoration(color: _bg, shape: BoxShape.circle),
              child: const Icon(PhosphorIconsRegular.caretLeft,
                  size: 20, color: _dark),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Route Preview',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                  letterSpacing: -0.5),
            ),
          ),
          if (_isRouteLoading)
            const SizedBox(
                width: 20,
                height: 20,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: _primary)),
        ],
      ),
    );
  }

  Widget _buildRouteInputs() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          // FROM
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 48,
            decoration: BoxDecoration(
                color: _grey.withOpacity(0.05), // Soft grey background
                borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(PhosphorIconsFill.navigationArrow,
                    color: _primary, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _fetchingLocation ? 'Fetching GPS…' : _fromController.text,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _fetchingLocation ? _grey : _dark),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_fetchingLocation)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _primary))
                else
                  const Icon(PhosphorIconsRegular.crosshair,
                      color: _primary, size: 18),
              ],
            ),
          ),

          // Connectors
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 4, bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                children: List.generate(
                    3,
                    (_) => Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                            color: _grey.withOpacity(0.4),
                            shape: BoxShape.circle))),
              ),
            ),
          ),

          // TO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 48,
            decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _grey.withOpacity(0.2))),
            child: Row(
              children: [
                const Icon(PhosphorIconsFill.flagBanner,
                    color: Color(0xFFEF4444), size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _toController,
                    readOnly: _activeProperty != null,
                    onChanged: _onSearchChanged,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _dark),
                    decoration: InputDecoration(
                      hintText: 'Where to?',
                      hintStyle: GoogleFonts.poppins(
                          color: _grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w400),
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    cursorColor: _primary,
                    textAlignVertical: TextAlignVertical.center,
                  ),
                ),
                if (_activeProperty != null || _toController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() {
                      _activeProperty = null;
                      _toController.clear();
                      _filteredSuggestions.clear();
                    }),
                    child: const Icon(PhosphorIconsFill.xCircle,
                        color: _grey, size: 20),
                  )
                else
                  const Icon(PhosphorIconsRegular.magnifyingGlass,
                      color: _grey, size: 20),
              ],
            ),
          ),

          if (_filteredSuggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredSuggestions.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: _grey.withOpacity(0.1)),
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
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                          color: _bg, shape: BoxShape.circle),
                      child: const Icon(PhosphorIconsRegular.mapPin,
                          color: _dark, size: 18),
                    ),
                    title: Text(name,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _dark)),
                    subtitle: subtitle.isNotEmpty
                        ? Text(subtitle,
                            style:
                                GoogleFonts.poppins(fontSize: 12, color: _grey))
                        : null,
                    hoverColor: _primarySoft,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
          if (_searchLoading)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Searching nearby places…',
                    style: GoogleFonts.poppins(fontSize: 12, color: _grey),
                  ),
                ],
              ),
            )
          else if (_searchError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _searchError!,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFFB42318),
                      ),
                    ),
                  ),
                  if (_toController.text.trim().isNotEmpty)
                    IconButton(
                      tooltip: 'Retry place search',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _onSearchChanged(_toController.text),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                    ),
                ],
              ),
            )
          else if (_toController.text.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Search a place, then select a suggestion to preview its route.',
                style: GoogleFonts.poppins(fontSize: 11, color: _grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Commute Options',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700, color: _dark)),
              if (_activeRoute != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: _primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '${_activeRoute!.distanceKm.toStringAsFixed(1)} km',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: _modes.map((m) {
              final isSelected = m.mode == _selectedMode;
              final route = _routeCache[m.mode];
              final eta = route != null
                  ? _formatDuration(route.durationSeconds)
                  : (_isRouteLoading ? '…' : '--');

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMode = m.mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? _primary : _surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: isSelected ? _primary : _grey.withOpacity(0.2),
                          width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Icon(m.icon,
                            color: isSelected ? Colors.white : _dark, size: 22),
                        const SizedBox(height: 6),
                        Text(eta,
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : _dark)),
                        Text(m.label,
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? Colors.white.withOpacity(0.8)
                                    : _grey)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            'Times are estimates from your current location. Matatu includes an estimated wait; actual travel conditions may vary.',
            style: GoogleFonts.poppins(
              color: _grey,
              fontSize: 11,
              height: 1.45,
            ),
          ),
          if (!_isRouteLoading && _activeRoute == null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: _primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationError ??
                          (_failedModes.contains(_selectedMode)
                              ? 'No ${_modes.firstWhere((mode) => mode.mode == _selectedMode).label.toLowerCase()} route is available. Check your connection or try another mode.'
                              : 'Choose a destination to calculate travel times.'),
                      style: GoogleFonts.poppins(
                        color: _dark,
                        fontSize: 11,
                        height: 1.45,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _retryRoutes,
                    icon: const Icon(Icons.refresh_rounded, size: 15),
                    label: const Text('Retry'),
                    style: TextButton.styleFrom(
                      foregroundColor: _primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
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
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(PhosphorIconsFill.navigationArrow,
                      size: 20, color: Colors.white),
              label: Text(
                _isRouteLoading ? 'Calculating…' : 'Start Navigation',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                disabledBackgroundColor: _grey.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32)),
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
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10))
            ],
          ),
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
                          fontWeight: FontWeight.w800,
                          color: _primary,
                          height: 1.0),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      route != null
                          ? '${route.distanceKm.toStringAsFixed(1)} km · via ${_modes.firstWhere((m) => m.mode == _selectedMode).label}'
                          : 'Calculating…',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(
                    _modes.firstWhere((m) => m.mode == _selectedMode).icon,
                    color: _primary,
                    size: 28),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPropertyPreviewCard(Property property) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: buildPropertyImage(property.image,
                width: 64, height: 64, fit: BoxFit.cover),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  property.name,
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700, color: _dark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _distanceLabel(property),
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w500, color: _grey),
                ),
              ],
            ),
          ),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                  color: _primary, borderRadius: BorderRadius.circular(20)),
              child: Text('Route',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
        ],
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

// ─── Shared Components ────────────────────────────────────────────────────────

class _DestinationMarker extends StatelessWidget {
  final String label;
  const _DestinationMarker({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _dark,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.redAccent.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 1)
            ],
          ),
          child: const Icon(PhosphorIconsFill.flagBanner,
              color: Colors.white, size: 16),
        ),
      ],
    );
  }
}

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
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return Transform.rotate(
          angle: widget.isNavigating ? (widget.heading * math.pi / 180) : 0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 16 + (_pulse.value * 32.0),
                height: 16 + (_pulse.value * 32.0),
                decoration: BoxDecoration(
                    color: _primary.withOpacity((1.0 - _pulse.value) * 0.4),
                    shape: BoxShape.circle),
              ),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                        color: _primary.withOpacity(0.5),
                        blurRadius: 6,
                        spreadRadius: 1)
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SolidCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _SolidCircleButton(
      {required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
