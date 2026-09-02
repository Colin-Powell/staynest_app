import 'dart:async';
import 'dart:convert';
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
const Color _primary = Color(0xFF3F37C9); // Tenant Blue Theme

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

  LatLng? _currentLocation;
  LatLng? _activePropertyLocation;
  String? _currentAddress;

  bool _loadingPlaces = false;
  bool _fetchingLocation = true;
  bool _mapReady = false;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocation();
    });
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
            if (data is! List || data.isEmpty)
              throw StateError('Location not found');
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
  // GET CURRENT LOCATION
  // ─────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorSnackBar('Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorSnackBar('Location permission denied.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorSnackBar('Location permissions are permanently denied.');
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
        });
        await _reverseGeocode();
      }
    } catch (e) {
      debugPrint('Location fetch error: $e');
    }
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

      if (mounted)
        setState(() => _currentAddress =
            '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}');
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
          if (mounted)
            setState(() => _currentAddress =
                results.first['formatted_address'] as String? ??
                    'Unknown address');
          return;
        }
      }
      if (mounted) setState(() => _currentAddress = 'Unknown address');
    } catch (_) {
      if (mounted) setState(() => _currentAddress = 'Unable to fetch address');
    }
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

  Future<void> _openDirections(double destLat, double destLng) async {
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&travelmode=driving');
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
    if (name.contains('school') || name.contains('university'))
      return const Color(0xFFF59E0B);
    if (name.contains('hospital') || name.contains('clinic'))
      return const Color(0xFFEF4444);
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
    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. FULL SCREEN MAP
          if (_mapReady)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _activePropertyLocation ??
                    _currentLocation ??
                    const LatLng(0, 0),
                initialZoom: 14.5,
                interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.rashoti.staynest',
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
                      final point =
                          (isActive && _activePropertyLocation != null)
                              ? _activePropertyLocation!
                              : LatLng(prop.lat, prop.lng);

                      return Marker(
                        point: point,
                        width: 100, // Adjusted width for cleaner pill shape
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _activeProperty = prop);
                            _activePropertyLocation = point;
                            _mapController.move(
                                point, _mapController.camera.zoom);
                            _showPropertyDrawer(context, prop);
                          },
                          child: _PropertyMarker(
                              property: prop, isActive: isActive),
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
            )
          else if (_fetchingLocation)
            const Center(child: CircularProgressIndicator(color: _primary))
          else
            Center(
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
            ),

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
                      decoration: const BoxDecoration(
                          color: _bg, shape: BoxShape.circle),
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

          // 3. FLOATING SOLID BOTTOM PANEL
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
              child: Column(
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
                      GestureDetector(
                        onTap: () => fetchNearbyPlaces(),
                        child: const Icon(PhosphorIconsRegular.arrowsClockwise,
                            color: _primary, size: 20),
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
                            child: Center(
                                child:
                                    CircularProgressIndicator(color: _primary)),
                          )
                        : nearbyPlaces.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(20),
                                child: Center(
                                  child: Text('No nearby places found.',
                                      style: GoogleFonts.poppins(color: _grey)),
                                ),
                              )
                            : SizedBox(
                                height: 120, // Constrain height for sleekness
                                child: ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: nearbyPlaces.length,
                                  itemBuilder: (context, index) {
                                    final place = nearbyPlaces[index];
                                    final Color iconColor =
                                        getPlaceColor(place);

                                    return GestureDetector(
                                      onTap: () {
                                        final propertyId = place['property_id'];
                                        final pLat = place['geometry']
                                            ['location']['lat'];
                                        final pLng = place['geometry']
                                            ['location']['lng'];

                                        _mapController.move(
                                            LatLng(pLat, pLng), 15.5);

                                        if (propertyId != null) {
                                          try {
                                            final prop =
                                                _allProperties.firstWhere((p) =>
                                                    p.id ==
                                                    propertyId.toString());
                                            setState(
                                                () => _activeProperty = prop);
                                            _showPropertyDrawer(context, prop);
                                          } catch (_) {}
                                        }
                                      },
                                      behavior: HitTestBehavior.opaque,
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 16),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color:
                                                    iconColor.withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                  PhosphorIconsFill.mapPin,
                                                  color: iconColor,
                                                  size: 16),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                place['name'] ?? 'Unknown',
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
                                    );
                                  },
                                ),
                              ),
                  ),

                  const SizedBox(height: 16),
                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: widget.onGetDirections ??
                          () {
                            final targetLoc = _activePropertyLocation ??
                                (nearbyPlaces.isNotEmpty
                                    ? LatLng(
                                        nearbyPlaces.first['geometry']
                                            ['location']['lat'],
                                        nearbyPlaces.first['geometry']
                                            ['location']['lng'])
                                    : null);
                            if (targetLoc != null) {
                              _openDirections(
                                  targetLoc.latitude, targetLoc.longitude);
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPropertyDrawer(BuildContext context, Property prop) {
    showModalBottomSheet(
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
