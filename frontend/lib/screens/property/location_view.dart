import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:property_app/utils/responsive_modal_sheet.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:property_app/models/property.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/property_service.dart';
import 'package:property_app/services/cache_engine.dart';
import 'package:property_app/widgets/property_image.dart';

// ─── Tenant Design System Constants ───────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _primary = Color(0xFF3F37C9); // Tenant Blue Theme
const Color _desktopAccent = Color(0xFF087F73);
const Color _desktopAccentSoft = Color(0xFFE8F4F1);
const Color _desktopBorder = Color(0xFFE5E7EB);

enum _LocationTravelMode { drive, walk, bike, matatu }

class _LocationTravelOption {
  final _LocationTravelMode mode;
  final String label;
  final String profile;
  final String googleMode;
  final IconData icon;

  const _LocationTravelOption({
    required this.mode,
    required this.label,
    required this.profile,
    required this.googleMode,
    required this.icon,
  });
}

const _locationTravelOptions = [
  _LocationTravelOption(
    mode: _LocationTravelMode.drive,
    label: 'Drive',
    profile: 'car',
    googleMode: 'driving',
    icon: PhosphorIconsRegular.car,
  ),
  _LocationTravelOption(
    mode: _LocationTravelMode.walk,
    label: 'Walk',
    profile: 'foot',
    googleMode: 'walking',
    icon: PhosphorIconsRegular.personSimpleWalk,
  ),
  _LocationTravelOption(
    mode: _LocationTravelMode.bike,
    label: 'Bike',
    profile: 'bike',
    googleMode: 'bicycling',
    icon: PhosphorIconsRegular.bicycle,
  ),
  _LocationTravelOption(
    mode: _LocationTravelMode.matatu,
    label: 'Matatu',
    profile: 'car',
    googleMode: 'transit',
    icon: PhosphorIconsRegular.van,
  ),
];

class _LocationSearchSuggestion {
  final String title;
  final String subtitle;
  final Property? property;
  final LatLng? location;

  const _LocationSearchSuggestion({
    required this.title,
    required this.subtitle,
    this.property,
    this.location,
  });
}

class LocationView extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onNearbyPlaces;
  final VoidCallback? onGetDirections;
  final Property? property;

  const LocationView({
    super.key,
    required this.onClose,
    this.onNearbyPlaces,
    this.onGetDirections,
    this.property,
  });

  @override
  State<LocationView> createState() => _LocationViewState();
}

class _LocationViewState extends State<LocationView> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng? _currentLocation;
  LatLng? _activePropertyLocation;
  LatLng? _desktopPopupLocation;
  String? _currentAddress;
  String _searchQuery = '';
  Property? _desktopPopupProperty;
  bool _desktopSearchFocused = false;
  bool _desktopSidebarCollapsed = false;

  bool _loadingPlaces = false;
  bool _fetchingLocation = true;
  bool _mapReady = false;
  bool _checkingBookingAccess = false;
  bool _hasCompletedBooking = true;
  bool _commuteLoading = false;
  String? _commuteError;
  String? _locationError;
  _LocationTravelMode _selectedTravelMode = _LocationTravelMode.drive;
  List<LatLng> _commutePoints = [];
  double? _commuteDistanceKm;
  int? _commuteDurationSeconds;
  int _commuteRequestId = 0;

  List<dynamic> nearbyPlaces = [];
  Property? _activeProperty;
  List<Property> _allProperties = [];

  /// GOOGLE API KEY - Leave empty or 'YOUR_GOOGLE_API_KEY' to use OpenStreetMap fallback
  static const String googleApiKey = 'YOUR_GOOGLE_API_KEY';

  bool get _hasGoogleApiKeyConfigured =>
      googleApiKey.isNotEmpty && googleApiKey != 'YOUR_GOOGLE_API_KEY';

  String get _locationTitle {
    if (_activeProperty != null) return 'Property Location';
    return 'Current Location';
  }

  String get _locationSubtitle {
    if (_activeProperty != null) return _activeProperty!.location;
    return _currentAddress ?? 'Fetching current address...';
  }

  @override
  void initState() {
    super.initState();
    _activeProperty = widget.property;
    _checkingBookingAccess = widget.property != null;
    _hasCompletedBooking = widget.property == null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareLocation();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _prepareLocation() async {
    if (_activeProperty != null) {
      var hasCompletedBooking = false;
      if (!AppSession.isGuest) {
        try {
          final eligibility = await RemoteDatabaseRepository()
              .getReviewEligibility(_activeProperty!.id);
          hasCompletedBooking =
              eligibility['bookingId']?.toString().isNotEmpty == true;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _checkingBookingAccess = false;
        _hasCompletedBooking = hasCompletedBooking;
      });
      if (!hasCompletedBooking) return;
    }

    await _initializeLocation();
  }

  // ─────────────────────────────────────────────
  // INITIALIZE LOCATION & GEOCODING
  // ─────────────────────────────────────────────

  Future<void> _initializeLocation() async {
    setState(() => _fetchingLocation = true);

    try {
      _allProperties = await PropertyService.instance.fetchProperties();
      await _getCurrentLocation(); // Safe fetch, won't throw if denied

      // Resolve Property Location (Geocode if lat/lng is missing)
      if (_activeProperty != null) {
        if (_activeProperty!.lat == 0.0 || _activeProperty!.lng == 0.0) {
          _activePropertyLocation =
              await _geocodeAddress(_activeProperty!.location);
        } else {
          _activePropertyLocation =
              LatLng(_activeProperty!.lat, _activeProperty!.lng);
        }
      }

      final targetLocation = _activePropertyLocation ?? _currentLocation;

      if (mounted) {
        setState(() => _mapReady = targetLocation != null);

        // Wait for map widget to be built before moving
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_currentLocation != null && _activePropertyLocation != null) {
            final bounds = LatLngBounds.fromPoints(
                [_currentLocation!, _activePropertyLocation!]);
            _mapController.fitBounds(
              bounds,
              options: const FitBoundsOptions(padding: EdgeInsets.all(80)),
            );
          } else if (targetLocation != null) {
            _mapController.move(targetLocation, 14.5);
          }
        });
      }

      if (targetLocation != null) await fetchNearbyPlaces(targetLocation);
      if (mounted &&
          MediaQuery.sizeOf(context).width >= 900 &&
          _currentLocation != null &&
          _activePropertyLocation != null) {
        await _loadDesktopCommuteRoute();
      }
    } catch (e) {
      debugPrint('Location init error: $e');
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    if (address.trim().isEmpty) return null;
    if (!_hasGoogleApiKeyConfigured) {
      try {
        final cacheKey =
            'property_geocode_${Uri.encodeComponent(address.trim().toLowerCase())}';
        final cached =
            await CacheEngine.instance.getOrFetch<Map<String, dynamic>>(
          key: cacheKey,
          ttl: const Duration(days: 30),
          networkFetcher: () async {
            final url = Uri.parse(
                'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json&limit=1');
            final res =
                await http.get(url, headers: {'User-Agent': 'PropertyApp/1.0'});
            if (res.statusCode != 200) throw StateError('Geocoding failed');
            final data = json.decode(res.body);
            if (data is! List || data.isEmpty) {
              throw StateError('Location not found');
            }
            return {'lat': data[0]['lat'], 'lng': data[0]['lon']};
          },
        );
        final lat = double.tryParse(cached['lat']?.toString() ?? '');
        final lng = double.tryParse(cached['lng']?.toString() ?? '');
        if (lat != null && lng != null) return LatLng(lat, lng);
      } catch (_) {}
      return null;
    }

    // Google Maps Geocoding
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$googleApiKey');
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['results'].isNotEmpty) {
          final loc = data['results'][0]['geometry']['location'];
          return LatLng(loc['lat'], loc['lng']);
        }
      }
    } catch (_) {}
    return null;
  }

  // ─────────────────────────────────────────────
  // GET CURRENT LOCATION & ACTIONS
  // ─────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _reportLocationError(
          'Turn on location services to calculate your commute.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _reportLocationError(
            'Allow location access in your browser to calculate travel times.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _reportLocationError(
          'Location access is blocked. Change this site’s browser permissions and retry.');
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _currentAddress = 'Fetching address...';
          _locationError = null;
        });
        await _reverseGeocode();
      }
    } catch (e) {
      debugPrint('Location fetch error: $e');
      _reportLocationError(
          'Could not get your location. Check browser permissions and try again.');
    }
  }

  void _reportLocationError(String message) {
    if (!mounted) return;
    setState(() => _locationError = message);
    _showErrorSnackBar(message);
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message,
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: _dark,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _reverseGeocode() async {
    final location = _currentLocation;
    if (location == null) return;

    if (!_hasGoogleApiKeyConfigured) {
      try {
        final url = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}');
        final response = await http.get(url, headers: {
          'User-Agent': 'PropertyApp/1.0'
        }).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (mounted) {
            setState(() {
              _currentAddress = data['display_name'] ?? 'Unknown address';
            });
          }
          return;
        }
      } catch (_) {}

      if (mounted) {
        setState(() => _currentAddress =
            '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}');
      }
      return;
    }

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${location.latitude},${location.longitude}&key=$googleApiKey');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          if (mounted) {
            setState(() => _currentAddress =
                results.first['formatted_address'] as String? ??
                    'Unknown address');
          }
          return;
        }
      }
      if (mounted) setState(() => _currentAddress = 'Unknown address');
    } catch (_) {
      if (mounted) setState(() => _currentAddress = 'Unable to fetch address');
    }
  }

  // ─────────────────────────────────────────────
  // MAP CONTROLS LOGIC
  // ─────────────────────────────────────────────

  void _zoomIn() {
    if (_mapReady) {
      _mapController.move(
          _mapController.camera.center, _mapController.camera.zoom + 1);
    }
  }

  void _zoomOut() {
    if (_mapReady) {
      _mapController.move(
          _mapController.camera.center, _mapController.camera.zoom - 1);
    }
  }

  void _goToMyLocation() async {
    if (_currentLocation != null && _mapReady) {
      _mapController.move(_currentLocation!, 15.0);
    } else {
      await _getCurrentLocation();
      if (_currentLocation != null && _mapReady) {
        _mapController.move(_currentLocation!, 15.0);
      }
    }
  }

  List<_LocationSearchSuggestion> get _searchSuggestions {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return const [];

    final suggestions = <_LocationSearchSuggestion>[];
    final seenPropertyIds = <String>{};
    for (final property in _allProperties) {
      if (!property.name.toLowerCase().contains(query) &&
          !property.location.toLowerCase().contains(query)) {
        continue;
      }
      seenPropertyIds.add(property.id);
      suggestions.add(_LocationSearchSuggestion(
        title: property.name,
        subtitle: property.location,
        property: property,
        location: property.lat != 0 && property.lng != 0
            ? LatLng(property.lat, property.lng)
            : null,
      ));
    }

    for (final place in nearbyPlaces) {
      if (place is! Map) continue;
      final title = place['name']?.toString() ?? '';
      if (!title.toLowerCase().contains(query)) continue;

      final property = _propertyForPlace(place);
      if (property != null && !seenPropertyIds.add(property.id)) continue;

      final geometry = place['geometry'];
      final locationData = geometry is Map ? geometry['location'] : null;
      final location = locationData is Map &&
              locationData['lat'] is num &&
              locationData['lng'] is num
          ? LatLng(
              (locationData['lat'] as num).toDouble(),
              (locationData['lng'] as num).toDouble(),
            )
          : null;
      suggestions.add(_LocationSearchSuggestion(
        title: title,
        subtitle: property?.location ?? 'Nearby place',
        property: property,
        location: location,
      ));
    }

    return suggestions.take(6).toList(growable: false);
  }

  Future<void> _searchLocation(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return;
    setState(() {
      _searchQuery = normalizedQuery;
    });
    final suggestions = _searchSuggestions;
    if (suggestions.isEmpty) {
      _showErrorSnackBar(
          'No results. Try a property name, neighborhood, or landmark.');
      return;
    }
    await _selectSearchSuggestion(suggestions.first);
  }

  Future<bool> _hasLocationAccess(Property property) async {
    if (widget.property?.id == property.id && _hasCompletedBooking) return true;
    if (AppSession.isGuest) return false;
    try {
      final eligibility =
          await RemoteDatabaseRepository().getReviewEligibility(property.id);
      return eligibility['bookingId']?.toString().isNotEmpty == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openDesktopProperty(Property property, LatLng? location) async {
    if (!await _hasLocationAccess(property)) {
      _showErrorSnackBar(
          'Complete a booking for this property to access its location.');
      return;
    }

    final target = location ??
        (property.lat != 0 && property.lng != 0
            ? LatLng(property.lat, property.lng)
            : await _geocodeAddress(property.location));
    if (!mounted) return;
    if (target == null) {
      _showErrorSnackBar(
          'A precise location is unavailable for this property.');
      return;
    }

    setState(() {
      _activeProperty = property;
      _activePropertyLocation = target;
      _desktopPopupProperty = property;
      _desktopPopupLocation = target;
    });
    _mapController.move(target, 15.0);
    await fetchNearbyPlaces(target);
    await _loadDesktopCommuteRoute();
  }

  Future<void> _selectSearchSuggestion(
      _LocationSearchSuggestion suggestion) async {
    _searchController.text = suggestion.title;
    setState(() => _searchQuery = '');
    if (suggestion.property != null) {
      await _openDesktopProperty(suggestion.property!, suggestion.location);
      return;
    }
    final location = suggestion.location;
    if (location == null) {
      _showErrorSnackBar('This place does not have a precise location.');
      return;
    }
    setState(() {
      _desktopPopupProperty = null;
      _desktopPopupLocation = null;
    });
    _mapController.move(location, 15.0);
  }

  Future<void> _loadDesktopCommuteRoute() async {
    final origin = _currentLocation;
    final destination = _activePropertyLocation;
    if (origin == null || destination == null) {
      setState(() {
        _commutePoints = [];
        _commuteDistanceKm = null;
        _commuteDurationSeconds = null;
        _commuteError = _locationError ??
            'Allow location access to compare your travel time to this property.';
      });
      return;
    }

    final requestId = ++_commuteRequestId;
    final option = _locationTravelOptions
        .firstWhere((item) => item.mode == _selectedTravelMode);
    setState(() {
      _commuteLoading = true;
      _commuteError = null;
    });

    try {
      final uri = Uri.parse(
        'https://routing.openstreetmap.de/routed-${option.profile}/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=false',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) throw StateError('Route unavailable');
      final data = jsonDecode(response.body);
      if (data is! Map || data['routes'] is! List || data['routes'].isEmpty) {
        throw StateError('Route unavailable');
      }

      final route = data['routes'].first;
      if (route is! Map ||
          route['distance'] is! num ||
          route['duration'] is! num) {
        throw StateError('Route unavailable');
      }
      final geometry = route['geometry'];
      final coordinates = geometry is Map ? geometry['coordinates'] : null;
      if (coordinates is! List) throw StateError('Route unavailable');

      final points = <LatLng>[];
      for (final coordinate in coordinates) {
        if (coordinate is List &&
            coordinate.length >= 2 &&
            coordinate[0] is num &&
            coordinate[1] is num) {
          points.add(LatLng(
            (coordinate[1] as num).toDouble(),
            (coordinate[0] as num).toDouble(),
          ));
        }
      }
      if (points.isEmpty) throw StateError('Route unavailable');

      final distanceKm = (route['distance'] as num).toDouble() / 1000;
      var durationSeconds = (route['duration'] as num).toInt();
      if (_selectedTravelMode == _LocationTravelMode.matatu) {
        durationSeconds = (durationSeconds * 1.35).toInt() + 600;
      }
      if (!mounted || requestId != _commuteRequestId) return;
      setState(() {
        _commutePoints = points;
        _commuteDistanceKm = distanceKm;
        _commuteDurationSeconds = durationSeconds;
        _commuteLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _commuteRequestId) return;
      setState(() {
        _commutePoints = [];
        _commuteDistanceKm = null;
        _commuteDurationSeconds = null;
        _commuteError =
            'Route unavailable. Check your connection or try another travel mode.';
        _commuteLoading = false;
      });
    }
  }

  Future<void> _retryDesktopCommute() async {
    if (_currentLocation == null) await _getCurrentLocation();
    await _loadDesktopCommuteRoute();
  }

  String _formatCommuteDuration(int seconds) {
    final minutes = (seconds / 60).round();
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return remainingMinutes == 0
          ? '${hours}h'
          : '${hours}h ${remainingMinutes}m';
    }
    return '$minutes min';
  }

  // ─────────────────────────────────────────────
  // FETCH NEARBY PLACES
  // ─────────────────────────────────────────────

  Future<void> fetchNearbyPlaces([LatLng? target]) async {
    final location = target ?? _currentLocation ?? _activePropertyLocation;

    if (location == null) {
      if (mounted) setState(() => nearbyPlaces = []);
      return;
    }

    setState(() => _loadingPlaces = true);

    if (!_hasGoogleApiKeyConfigured) {
      if (mounted) {
        setState(() {
          nearbyPlaces = _localNearbyPlaces(location);
          _loadingPlaces = false;
        });
      }
      return;
    }

    final url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${location.latitude},${location.longitude}&radius=2000&key=$googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (mounted &&
            data['results'] != null &&
            (data['results'] as List).isNotEmpty) {
          setState(() => nearbyPlaces = data['results']);
        } else if (mounted) {
          setState(() => nearbyPlaces = _localNearbyPlaces(location));
        }
      } else if (mounted) {
        setState(() => nearbyPlaces = _localNearbyPlaces(location));
      }
    } catch (_) {
      if (mounted) setState(() => nearbyPlaces = _localNearbyPlaces(location));
    }

    if (mounted) setState(() => _loadingPlaces = false);
  }

  List<Map<String, dynamic>> _localNearbyPlaces(LatLng origin) {
    final results = _allProperties
        .where((prop) =>
            prop.lat != 0 || prop.lng != 0 || prop.id == _activeProperty?.id)
        .map((prop) {
      final pLat =
          (prop.id == _activeProperty?.id && _activePropertyLocation != null)
              ? _activePropertyLocation!.latitude
              : prop.lat;
      final pLng =
          (prop.id == _activeProperty?.id && _activePropertyLocation != null)
              ? _activePropertyLocation!.longitude
              : prop.lng;

      final dist = Geolocator.distanceBetween(
          origin.latitude, origin.longitude, pLat, pLng);
      return {
        'name': prop.name,
        'property_id': prop.id,
        'types': ['property'],
        'dist': '${(dist / 1000).toStringAsFixed(1)} km',
        'geometry': {
          'location': {'lat': pLat, 'lng': pLng},
        },
        'image': prop.image,
      };
    }).toList();

    results.sort((a, b) {
      final aDist =
          double.tryParse(a['dist'].toString().replaceAll(' km', '')) ?? 0;
      final bDist =
          double.tryParse(b['dist'].toString().replaceAll(' km', '')) ?? 0;
      return aDist.compareTo(bDist);
    });

    return results.take(4).toList();
  }

  // ─────────────────────────────────────────────
  // NATIVE DIRECTIONS LAUNCHER
  // ─────────────────────────────────────────────

  Future<void> _openDirections(
    double destLat,
    double destLng, {
    String travelMode = 'driving',
  }) async {
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&travelmode=$travelMode');
    try {
      final launched =
          await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
      if (!launched) await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showErrorSnackBar('Could not launch maps application.');
    }
  }

  // ─────────────────────────────────────────────
  // PLACE UI HELPERS
  // ─────────────────────────────────────────────

  Color getPlaceColor(dynamic place) {
    final types = place['types'];
    if (types is List && types.contains('property')) return _primary;
    final name = (place['name'] ?? '').toString().toLowerCase();
    if (name.contains('school') || name.contains('university')) {
      return const Color(0xFFF59E0B);
    }
    if (name.contains('hospital') || name.contains('clinic')) {
      return const Color(0xFFEF4444);
    }
    if (name.contains('police') || name.contains('security')) return _primary;
    return const Color(0xFF6B7280);
  }

  String getDistance(dynamic place) {
    if (place['dist'] != null) return place['dist'];
    if (place['geometry'] != null && _currentLocation != null) {
      final pLat = place['geometry']['location']['lat'];
      final pLng = place['geometry']['location']['lng'];
      double dist = Geolocator.distanceBetween(
          _currentLocation!.latitude, _currentLocation!.longitude, pLat, pLng);
      return '${(dist / 1000).toStringAsFixed(1)} km';
    }
    return 'N/A';
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_checkingBookingAccess) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    if (widget.property != null && !_hasCompletedBooking) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          leading: IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.arrow_back_rounded, color: _dark),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Complete a booking for this property to access its location services.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: _dark,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // If the screen width is >= 900px, use the Desktop Google Maps style layout
          final isDesktop = constraints.maxWidth >= 900;
          return isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // RESPONSIVE LAYOUT BUILDS
  // ─────────────────────────────────────────────

  Widget _buildDesktopLayout() {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          // 1. FULL SCREEN MAP
          Positioned.fill(
            child: _buildMapCore(),
          ),

          // 2. FLOATING LEFT PANEL (Google Maps Style)
          if (!_desktopSidebarCollapsed)
            Positioned(
              top: 16,
              left: 16,
              bottom: 16,
              width: 400,
              child: Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Close location view',
                                onPressed: widget.onClose,
                                icon: const Icon(Icons.close_rounded,
                                    color: _dark),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Focus(
                                  onFocusChange: (focused) {
                                    if (_desktopSearchFocused != focused) {
                                      setState(() =>
                                          _desktopSearchFocused = focused);
                                    }
                                  },
                                  child: Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: _desktopSearchFocused
                                          ? Colors.white
                                          : const Color(0xFFF7F9F8),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _desktopSearchFocused
                                            ? _desktopAccent
                                            : _desktopBorder,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                            PhosphorIconsRegular
                                                .magnifyingGlass,
                                            color: _desktopAccent,
                                            size: 19),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: TextField(
                                            controller: _searchController,
                                            onChanged: (value) => setState(
                                              () => _searchQuery = value.trim(),
                                            ),
                                            onSubmitted: _searchLocation,
                                            textInputAction:
                                                TextInputAction.search,
                                            decoration: InputDecoration(
                                              hintText:
                                                  'Search a property or nearby place',
                                              hintStyle: GoogleFonts.poppins(
                                                color: _grey,
                                                fontSize: 13,
                                              ),
                                              filled: false,
                                              fillColor: Colors.transparent,
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              disabledBorder: InputBorder.none,
                                              errorBorder: InputBorder.none,
                                              isDense: true,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            cursorColor: _desktopAccent,
                                            textAlignVertical:
                                                TextAlignVertical.center,
                                            style: GoogleFonts.poppins(
                                              color: _dark,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        if (_searchQuery.isNotEmpty)
                                          IconButton(
                                            tooltip: 'Clear search',
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() => _searchQuery = '');
                                            },
                                            icon: const Icon(
                                                Icons.close_rounded,
                                                size: 18,
                                                color: _grey),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: 'Collapse sidebar',
                                onPressed: () => setState(
                                    () => _desktopSidebarCollapsed = true),
                                icon: const Icon(
                                  Icons.keyboard_double_arrow_left_rounded,
                                  color: _dark,
                                ),
                              ),
                            ],
                          ),
                          if (_searchQuery.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 56, top: 7),
                              child: Text(
                                'Try a property name, neighborhood, or landmark.',
                                style: GoogleFonts.poppins(
                                  color: _grey,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          if (_searchQuery.isNotEmpty)
                            _buildDesktopSearchSuggestions(),
                        ],
                      ),
                    ),

                    // PANEL DETAILS
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: _buildDetailsContent(isDesktop: true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_desktopSidebarCollapsed)
            Positioned(
              top: 16,
              left: 16,
              child: Material(
                color: _surface,
                elevation: 4,
                borderRadius: BorderRadius.circular(10),
                child: IconButton(
                  tooltip: 'Expand location sidebar',
                  onPressed: () =>
                      setState(() => _desktopSidebarCollapsed = false),
                  icon: const Icon(
                    Icons.keyboard_double_arrow_right_rounded,
                    color: _desktopAccent,
                  ),
                ),
              ),
            ),

          // 3. MAP CONTROLS (Floating Bottom Right)
          Positioned(
            right: 24,
            bottom: 24,
            child: _buildMapControls(isDesktop: true),
          ),
          if (_desktopPopupProperty != null && _desktopPopupLocation != null)
            Builder(
              builder: (context) {
                final popupWidth =
                    (constraints.maxWidth - 464).clamp(320.0, 480.0).toDouble();
                final markerPoint = _mapController.camera
                    .latLngToScreenPoint(_desktopPopupLocation!);
                const minLeft = 432.0;
                final maxLeft = (constraints.maxWidth - popupWidth - 16)
                    .clamp(minLeft, constraints.maxWidth)
                    .toDouble();
                final left = (markerPoint.x - popupWidth / 2)
                    .clamp(minLeft, maxLeft)
                    .toDouble();
                final maxTop = (constraints.maxHeight - 390)
                    .clamp(16.0, constraints.maxHeight)
                    .toDouble();
                final top =
                    (markerPoint.y - 290).clamp(16.0, maxTop).toDouble();
                return Positioned(
                  left: left,
                  top: top,
                  width: popupWidth,
                  child: _buildDesktopPropertyPopup(_desktopPopupProperty!),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Stack(
      children: [
        // 1. FULL SCREEN MAP
        _buildMapCore(),

        // 2. CLEAN FLOATING HEADER
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 24,
          right: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(32), // Pill shape
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
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
                    'Map View',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. FLOATING MAP CONTROLS
        Positioned(
          right: 16,
          bottom: 300, // Float above bottom panel
          child: _buildMapControls(),
        ),

        // 4. FLOATING SOLID BOTTOM PANEL
        Positioned(
          bottom: 24,
          left: 24,
          right: 24,
          child: Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 10))
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: _buildDetailsContent(isDesktop: false),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopSearchSuggestions() {
    final suggestions = _searchSuggestions;
    return Container(
      margin: const EdgeInsets.only(left: 56, top: 8),
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: suggestions.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'No matching properties or nearby places.',
                style: GoogleFonts.poppins(fontSize: 12, color: _grey),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: suggestions.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 44, endIndent: 12),
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: InkWell(
                    onTap: () => _selectSearchSuggestion(suggestion),
                    hoverColor: _desktopAccentSoft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            suggestion.property == null
                                ? PhosphorIconsRegular.mapPin
                                : PhosphorIconsRegular.house,
                            size: 18,
                            color: _primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  suggestion.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: _dark,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  suggestion.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: _grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.north_west_rounded,
                              size: 15, color: _grey),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ─────────────────────────────────────────────
  // REUSABLE COMPONENTS
  // ─────────────────────────────────────────────

  Widget _buildMapCore() {
    if (_mapReady) {
      return FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter:
              _activePropertyLocation ?? _currentLocation ?? const LatLng(0, 0),
          initialZoom: 14.5,
          interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.drag |
                  InteractiveFlag.pinchZoom |
                  InteractiveFlag.doubleTapZoom |
                  InteractiveFlag.scrollWheelZoom),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.rashoti.staynest',
          ),
          if (_commutePoints.length > 1 &&
              MediaQuery.sizeOf(context).width >= 900)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _commutePoints,
                  color: Colors.white,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  strokeJoin: StrokeJoin.round,
                ),
                Polyline(
                  points: _commutePoints,
                  color: _desktopAccent,
                  strokeWidth: 5,
                  strokeCap: StrokeCap.round,
                  strokeJoin: StrokeJoin.round,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              ..._allProperties
                  .where((prop) =>
                      (prop.lat != 0 && prop.lng != 0) ||
                      (prop.id == _activeProperty?.id &&
                          _activePropertyLocation != null))
                  .map((prop) {
                final isActive = _activeProperty?.id == prop.id;
                final point = (isActive && _activePropertyLocation != null)
                    ? _activePropertyLocation!
                    : LatLng(prop.lat, prop.lng);

                return Marker(
                  point: point,
                  width: 100, // Adjusted width for cleaner pill shape
                  height: 40,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () {
                      if (MediaQuery.sizeOf(context).width >= 900) {
                        unawaited(_openDesktopProperty(prop, point));
                        return;
                      }
                      setState(() => _activeProperty = prop);
                      _activePropertyLocation = point;
                      _mapController.move(point, _mapController.camera.zoom);
                      _showPropertyDrawer(context, prop);
                    },
                    child: _PropertyMarker(property: prop, isActive: isActive),
                  ),
                );
              }),
              if (_currentLocation != null)
                Marker(
                  point: _currentLocation!,
                  width: 32,
                  height: 32,
                  child: const _MapPin(),
                ),
            ],
          ),
        ],
      );
    } else if (_fetchingLocation) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    } else {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'A precise location is not available for this property yet.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: _dark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildMapControls({bool isDesktop = false}) {
    final accent = isDesktop ? _desktopAccent : _primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // My Location Button
        FloatingActionButton(
          mini: true,
          heroTag: 'my_location',
          backgroundColor: _surface,
          foregroundColor: accent,
          onPressed: _goToMyLocation,
          child: const Icon(PhosphorIconsRegular.crosshair, size: 20),
        ),
        const SizedBox(height: 16),

        // Zoom Controls
        Container(
          decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ]),
          child: Column(
            children: [
              InkWell(
                onTap: _zoomIn,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: const Padding(
                  padding: EdgeInsets.all(10.0),
                  child:
                      Icon(PhosphorIconsRegular.plus, size: 20, color: _dark),
                ),
              ),
              Container(height: 1, width: 36, color: _grey.withOpacity(0.2)),
              InkWell(
                onTap: _zoomOut,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(12)),
                child: const Padding(
                  padding: EdgeInsets.all(10.0),
                  child:
                      Icon(PhosphorIconsRegular.minus, size: 20, color: _dark),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsContent({required bool isDesktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Location Info
        Text(
          _locationTitle,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _locationSubtitle,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: _grey,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 24),

        // Nearby Places Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nearby Places',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            IconButton(
              tooltip: 'Refresh nearby places',
              onPressed: () => fetchNearbyPlaces(),
              icon: const Icon(PhosphorIconsRegular.arrowsClockwise,
                  color: _desktopAccent, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Nearby Places List
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _fetchingLocation || _loadingPlaces
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child:
                      Center(child: CircularProgressIndicator(color: _primary)),
                )
              : nearbyPlaces.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text('No nearby places found.',
                            style: GoogleFonts.poppins(color: _grey)),
                      ),
                    )
                  : _buildPlacesList(isDesktop: isDesktop),
        ),

        if (isDesktop)
          _buildDesktopCommutePanel()
        else ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: widget.onGetDirections ??
                  () {
                    final targetLoc = _activePropertyLocation ??
                        (nearbyPlaces.isNotEmpty
                            ? LatLng(
                                nearbyPlaces.first['geometry']['location']
                                    ['lat'],
                                nearbyPlaces.first['geometry']['location']
                                    ['lng'])
                            : null);
                    if (targetLoc != null) {
                      _openDirections(targetLoc.latitude, targetLoc.longitude);
                    } else {
                      _showErrorSnackBar('No destination available.');
                    }
                  },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32)),
                elevation: 0,
              ),
              child: Text(
                'Get Directions',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDesktopCommutePanel() {
    final option = _locationTravelOptions
        .firstWhere((item) => item.mode == _selectedTravelMode);
    final destination = _activePropertyLocation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Divider(height: 24),
        Row(
          children: [
            const Icon(PhosphorIconsRegular.path,
                color: _desktopAccent, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Commute to ${_activeProperty?.name ?? 'selected location'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: _dark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_commuteLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Compare estimated times from your current location.',
          style: GoogleFonts.poppins(color: _grey, fontSize: 11),
        ),
        const SizedBox(height: 10),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SegmentedButton<_LocationTravelMode>(
            showSelectedIcon: false,
            segments: _locationTravelOptions
                .map(
                  (item) => ButtonSegment<_LocationTravelMode>(
                    value: item.mode,
                    icon: Icon(item.icon, size: 16),
                    label: Text(
                      item.label,
                      style: GoogleFonts.poppins(fontSize: 10),
                    ),
                  ),
                )
                .toList(growable: false),
            selected: {_selectedTravelMode},
            onSelectionChanged: (selection) {
              if (selection.isEmpty) return;
              setState(() => _selectedTravelMode = selection.first);
              unawaited(_loadDesktopCommuteRoute());
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              backgroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? _desktopAccent
                      : Colors.white),
              foregroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? Colors.white : _dark),
              side: WidgetStateProperty.resolveWith((states) => BorderSide(
                    color: states.contains(WidgetState.selected)
                        ? _desktopAccent
                        : _desktopBorder,
                  )),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_commuteLoading)
          const LinearProgressIndicator(
            minHeight: 2,
            color: _desktopAccent,
            backgroundColor: Color(0xFFE5E7EB),
          )
        else if (_commuteDurationSeconds != null && _commuteDistanceKm != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCommuteDuration(_commuteDurationSeconds!),
                style: GoogleFonts.poppins(
                  color: _dark,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${_commuteDistanceKm!.toStringAsFixed(1)} km by ${option.label.toLowerCase()}',
                  style: GoogleFonts.poppins(color: _grey, fontSize: 12),
                ),
              ),
            ],
          )
        else if (_commuteError != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _commuteError!,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFB42318),
                    fontSize: 11,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _retryDesktopCommute,
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Retry'),
                style: TextButton.styleFrom(
                  foregroundColor: _desktopAccent,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          )
        else
          Text(
            'Select a travel mode to calculate your route.',
            style: GoogleFonts.poppins(color: _grey, fontSize: 11),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: destination == null
                ? null
                : () => _openDirections(
                      destination.latitude,
                      destination.longitude,
                      travelMode: option.googleMode,
                    ),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Open route in Maps'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _desktopAccent,
              side: const BorderSide(color: _desktopAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlacesList({required bool isDesktop}) {
    final normalizedQuery = isDesktop ? _searchQuery.toLowerCase() : '';
    final visiblePlaces = nearbyPlaces.where((place) {
      if (normalizedQuery.isEmpty) return true;
      return place['name']
              ?.toString()
              .toLowerCase()
              .contains(normalizedQuery) ==
          true;
    }).toList();

    if (visiblePlaces.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          normalizedQuery.isEmpty
              ? 'No nearby places found.'
              : 'No matches found.',
          style: GoogleFonts.poppins(color: _grey, fontSize: 13),
        ),
      );
    }

    final listView = ListView.builder(
      physics: isDesktop
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      shrinkWrap: isDesktop,
      padding: EdgeInsets.zero,
      itemCount: visiblePlaces.length,
      itemBuilder: (context, index) {
        final place = visiblePlaces[index];
        final property = _propertyForPlace(place);
        final Color iconColor = isDesktop && property != null
            ? _desktopAccent
            : getPlaceColor(place);
        final placeImage =
            place is Map ? place['image']?.toString().trim() ?? '' : '';
        final imageUrl =
            placeImage.isNotEmpty ? placeImage : property?.image ?? '';

        return GestureDetector(
          onTap: () {
            final propertyId =
                place is Map ? place['property_id']?.toString() : null;
            final geometry = place is Map ? place['geometry'] : null;
            final locationData = geometry is Map ? geometry['location'] : null;
            if (locationData is! Map ||
                locationData['lat'] is! num ||
                locationData['lng'] is! num) {
              return;
            }
            final location = LatLng(
              (locationData['lat'] as num).toDouble(),
              (locationData['lng'] as num).toDouble(),
            );

            if (isDesktop) {
              if (property != null) {
                unawaited(_openDesktopProperty(property, location));
              } else {
                _mapController.move(location, 15.5);
              }
              return;
            }

            _mapController.move(location, 15.5);

            if (propertyId != null) {
              final prop = property;
              if (prop != null) {
                setState(() {
                  _activeProperty = prop;
                  _activePropertyLocation = location;
                });
                _showPropertyDrawer(context, prop, location: location);
              }
            }
          },
          behavior: HitTestBehavior.opaque,
          child: MouseRegion(
            cursor: isDesktop ? SystemMouseCursors.click : MouseCursor.defer,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  if (isDesktop) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl.isNotEmpty
                          ? buildPropertyImage(
                              imageUrl,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 56,
                              height: 56,
                              color: iconColor.withOpacity(0.1),
                              child: Icon(PhosphorIconsFill.mapPin,
                                  color: iconColor, size: 20),
                            ),
                    ),
                    const SizedBox(width: 12),
                  ] else ...[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(PhosphorIconsFill.mapPin,
                          color: iconColor, size: 16),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      place is Map
                          ? place['name']?.toString() ?? 'Unknown'
                          : 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _dark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    getDistance(place),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return isDesktop
        ? listView
        : SizedBox(height: 120, child: listView); // Constrain height on mobile
  }

  Property? _propertyForPlace(dynamic place) {
    final propertyId = place is Map ? place['property_id']?.toString() : null;
    if (propertyId == null) return null;
    for (final property in _allProperties) {
      if (property.id == propertyId) return property;
    }
    return null;
  }

  void _showPropertyDrawer(
    BuildContext context,
    Property prop, {
    LatLng? location,
  }) {
    if (MediaQuery.sizeOf(context).width >= 900) {
      setState(() {
        _desktopPopupProperty = prop;
        _desktopPopupLocation = location ??
            (prop.lat != 0 && prop.lng != 0
                ? LatLng(prop.lat, prop.lng)
                : _activePropertyLocation);
      });
      return;
    }

    showResponsiveModalSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PropertyDrawer(
        property: prop,
        onGetDirections: () {
          Navigator.pop(context);
          final destination = prop.id == _activeProperty?.id
              ? _activePropertyLocation
              : (prop.lat != 0 && prop.lng != 0
                  ? LatLng(prop.lat, prop.lng)
                  : null);
          if (destination == null) {
            _showErrorSnackBar('A precise property location is unavailable.');
            return;
          }
          _openDirections(destination.latitude, destination.longitude);
        },
      ),
    );
  }

  Widget _buildDesktopPropertyPopup(Property property) {
    final images = <String>{
      if (property.image.trim().isNotEmpty) property.image,
      ...property.images.where((image) => image.trim().isNotEmpty),
    }.toList();
    final location = _desktopPopupLocation;

    return Material(
      color: _surface,
      elevation: 12,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 190,
            child: Stack(
              children: [
                if (images.isEmpty)
                  Container(
                    color: const Color(0xFFE5E7EB),
                    alignment: Alignment.center,
                    child: const Icon(PhosphorIconsRegular.house,
                        size: 42, color: _grey),
                  )
                else
                  ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    itemCount: images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 3),
                    itemBuilder: (context, index) => SizedBox(
                      width: 264,
                      child: buildPropertyImage(
                        images[index],
                        width: 264,
                        height: 190,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.white.withOpacity(0.94),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Close property preview',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() {
                        _desktopPopupProperty = null;
                        _desktopPopupLocation = null;
                      }),
                      icon: const Icon(Icons.close_rounded,
                          size: 19, color: _dark),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: _dark,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  property.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(color: _grey, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ksh ${property.price.toStringAsFixed(0)} / month',
                        style: GoogleFonts.poppins(
                          color: _dark,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: location == null
                          ? null
                          : () => _openDirections(
                                location.latitude,
                                location.longitude,
                              ),
                      icon: const Icon(Icons.directions_rounded, size: 18),
                      label: const Text('Directions'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AIRBNB STYLE DRAWER
// ─────────────────────────────────────────────

class _PropertyDrawer extends StatefulWidget {
  final Property property;
  final VoidCallback onGetDirections;

  const _PropertyDrawer(
      {required this.property, required this.onGetDirections});

  @override
  State<_PropertyDrawer> createState() => _PropertyDrawerState();
}

class _PropertyDrawerState extends State<_PropertyDrawer> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final prop = widget.property;
    final images = (prop.images.isNotEmpty) ? prop.images : [prop.image];

    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Carousel with rounded top corners
            SizedBox(
              height: 260,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(32)),
                    child: PageView.builder(
                      itemCount: images.length,
                      onPageChanged: (idx) =>
                          setState(() => _currentImageIndex = idx),
                      itemBuilder: (context, index) {
                        return buildPropertyImage(images[index],
                            width: double.infinity,
                            height: 260,
                            fit: BoxFit.cover);
                      },
                    ),
                  ),
                  // Dark gradient at bottom of image for pagination dots visibility
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6)
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  // Bottom sheet handle
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  // Pagination dots
                  if (images.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          images.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentImageIndex == index ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _currentImageIndex == index
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          prop.name,
                          style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _dark,
                              letterSpacing: -0.5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          const Icon(PhosphorIconsFill.star,
                              color: Color(0xFFF59E0B), size: 16),
                          const SizedBox(width: 4),
                          Text('${prop.rating}',
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _dark)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    prop.location,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: _grey,
                        fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 24),

                  // Price & Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ksh. ${prop.price}',
                            style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _dark),
                          ),
                          Text('/month',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: _grey,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Flexible(
                        child: ElevatedButton(
                          onPressed: widget.onGetDirections,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 24),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32)),
                            elevation: 0,
                          ),
                          child: Text('Directions',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PROPERTY MARKER (Airbnb Style Pill)
// ─────────────────────────────────────────────

class _PropertyMarker extends StatelessWidget {
  final Property property;
  final bool isActive;

  const _PropertyMarker({required this.property, required this.isActive});

  String _formatPrice(num price) {
    final value = price.toDouble();
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? _dark : _surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
                color: isActive ? _dark : _grey.withOpacity(0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Text(
            'Ksh ${_formatPrice(property.price)}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : _dark,
            ),
          ),
        ),
        // Small triangle pointing down
        if (isActive)
          Container(
            width: 10,
            height: 6,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: _dark, width: 6),
                left: BorderSide(color: Colors.transparent, width: 5),
                right: BorderSide(color: Colors.transparent, width: 5),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// MAP PIN (CURRENT LOCATION)
// ─────────────────────────────────────────────

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
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, _) {
            return Container(
              width: 16 + (_pulseAnim.value * 32),
              height: 16 + (_pulseAnim.value * 32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primary.withOpacity((1.0 - _pulseAnim.value) * 0.4),
              ),
            );
          },
        ),
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: _primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: _primary.withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 1),
            ],
          ),
        ),
      ],
    );
  }
}
