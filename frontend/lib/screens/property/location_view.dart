// START OF FILE
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:io';

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
import 'package:property_app/widgets/property_image.dart';

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

  static const LatLng _fallbackLocation = LatLng(-3.6305, 39.8499); // Kilifi
  static const Color _tenantPrimary = Color(0xFF3F37C9); // Tenant Blue
  static const Color _textDark = Color(0xFF111827);

  LatLng? _currentLocation;
  LatLng? _activePropertyLocation;
  String? _currentAddress;
  bool _loadingPlaces = false;
  bool _fetchingLocation = true;

  List<dynamic> nearbyPlaces = [];
  Property? _activeProperty;
  List<Property> _allProperties = [];

  /// GOOGLE API KEY - Leave empty or 'YOUR_GOOGLE_API_KEY' to use OpenStreetMap fallback
  static const String googleApiKey = 'YOUR_GOOGLE_API_KEY';

  bool get _hasGoogleApiKeyConfigured =>
      googleApiKey.isNotEmpty && googleApiKey != 'YOUR_GOOGLE_API_KEY';

  String get _locationTitle {
    if (_activeProperty != null) {
      return 'Property Location';
    }
    return 'Current Location';
  }

  String get _locationSubtitle {
    if (_activeProperty != null) {
      return _activeProperty!.location;
    }
    return _currentAddress ?? 'Fetching current address...';
  }

  Color? get _textLight => null;

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
      await _getCurrentLocation();

      // Resolve Property Location (Geocode if lat/lng is 0)
      if (_activeProperty != null) {
        if (_activeProperty!.lat == 0.0 && _activeProperty!.lng == 0.0) {
          _activePropertyLocation =
              await _geocodeAddress(_activeProperty!.location);
        } else {
          _activePropertyLocation =
              LatLng(_activeProperty!.lat, _activeProperty!.lng);
        }
        // Force fallback if geocoding returns null so the marker ALWAYS renders
        _activePropertyLocation ??= _fallbackLocation;
      }

      final targetLocation =
          _currentLocation ?? _activePropertyLocation ?? _fallbackLocation;

      // Fit bounds if we have both current location and a property location
      if (_currentLocation != null && _activePropertyLocation != null) {
        final bounds = LatLngBounds.fromPoints(
            [_currentLocation!, _activePropertyLocation!]);
        _mapController.fitBounds(
          bounds,
          options: const FitBoundsOptions(padding: EdgeInsets.all(80)),
        );
      } else {
        _mapController.move(targetLocation, 15);
      }

      await fetchNearbyPlaces(targetLocation);
    } catch (e) {
      debugPrint('Location init error: $e');
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    if (!_hasGoogleApiKeyConfigured) {
      // OpenStreetMap (Nominatim) Fallback
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json&limit=1');
      try {
        final res =
            await http.get(url, headers: {'User-Agent': 'PropertyApp/1.0'});
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data.isNotEmpty) {
            return LatLng(
                double.parse(data[0]['lat']), double.parse(data[0]['lon']));
          }
        }
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
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));

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
          content: Text(message, style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
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
        setState(() {
          _currentAddress =
              '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
        });
      }
      return;
    }

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=${location.latitude},${location.longitude}&key=$googleApiKey',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          setState(() {
            _currentAddress = results.first['formatted_address'] as String? ??
                'Unknown address';
          });
          return;
        }
      }
      setState(() => _currentAddress = 'Unknown address');
    } catch (_) {
      if (mounted) setState(() => _currentAddress = 'Unable to fetch address');
    }
  }

  // ─────────────────────────────────────────────
  // FETCH NEARBY PLACES
  // ─────────────────────────────────────────────

  Future<void> fetchNearbyPlaces([LatLng? target]) async {
    final location = target ??
        _currentLocation ??
        _activePropertyLocation ??
        _fallbackLocation;

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

    final url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=${location.latitude},${location.longitude}'
        '&radius=2000'
        '&key=$googleApiKey';

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
      'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&travelmode=driving',
    );

    try {
      // Force opening in Native Application (Google Maps / Apple Maps)
      final launched =
          await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
      if (!launched) {
        // Fallback to browser ONLY if native maps application is not found
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _showErrorSnackBar('Could not launch maps application.');
    }
  }

  // ─────────────────────────────────────────────
  // PLACE UI HELPERS
  // ─────────────────────────────────────────────

  Color getPlaceColor(dynamic place) {
    final types = place['types'];
    if (types is List && types.contains('property')) return _tenantPrimary;
    final name = (place['name'] ?? '').toString().toLowerCase();
    if (name.contains('school') || name.contains('university'))
      return const Color(0xFFF59E0B);
    if (name.contains('hospital') || name.contains('clinic'))
      return const Color(0xFFEF4444);
    if (name.contains('police') || name.contains('security'))
      return _tenantPrimary;
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

  Widget _buildPlaceAvatar(dynamic place) {
    final imageSource = (place['avatar'] ?? place['image'])?.toString();
    if (imageSource != null && imageSource.isNotEmpty) {
      return buildPropertyImage(imageSource,
          width: 44, height: 44, fit: BoxFit.cover);
    }
    return Container(
      color: const Color(0xFFF3F4F6),
      child: Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
          color: Color(0xFF9CA3AF), size: 20),
    );
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final location =
        _currentLocation ?? _activePropertyLocation ?? _fallbackLocation;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. FULL SCREEN MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: location,
              initialZoom: 14.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.rashoti.staynest',
              ),
              MarkerLayer(
                markers: [
                  // Map properties with valid lat/lng OR active properties with geocoded lat/lng
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
                      width: 180,
                      height: 56,
                      // Removed standard tooltip wrapper so custom touch target works perfectly
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _activeProperty = prop);
                          _activePropertyLocation = point;
                          _mapController.move(
                              point, _mapController.camera.zoom);
                          _showPropertyDrawer(context, prop);
                        },
                        child:
                            _PropertyMarker(property: prop, isActive: isActive),
                      ),
                    );
                  }),
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      width: 32,
                      height: 32,
                      child: const _MapPin(), // Clean pulsing dot, no cone
                    ),
                ],
              ),
            ],
          ),

          // 2. GLASS HEADER
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 12,
                    bottom: 16,
                    left: 20,
                    right: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    border: Border(
                        bottom:
                            BorderSide(color: Colors.white.withOpacity(0.5))),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: widget.onClose,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10)
                            ],
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              size: 20, color: _textDark),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Map View',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. FLOATING GLASS BOTTOM PANEL
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.75),
                    border: Border(
                        top: BorderSide(
                            color: Colors.white.withOpacity(0.8), width: 1.5)),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Location Info
                      Text(
                        _locationTitle,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _locationSubtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF6B7280),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => fetchNearbyPlaces(),
                            child: Icon(PhosphorIcons.arrowsClockwise(),
                                color: _tenantPrimary, size: 20),
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
                                    child: CircularProgressIndicator(
                                        color: _tenantPrimary)),
                              )
                            : nearbyPlaces.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Center(
                                      child: Text('No nearby places found.',
                                          style: GoogleFonts.poppins(
                                              color: Colors.grey)),
                                    ),
                                  )
                                : SizedBox(
                                    height:
                                        140, // Constrain height to make it scrollable/sleek
                                    child: ListView.builder(
                                      physics: const BouncingScrollPhysics(),
                                      padding: EdgeInsets.zero,
                                      itemCount: nearbyPlaces.length,
                                      itemBuilder: (context, index) {
                                        final place = nearbyPlaces[index];
                                        final Color iconColor =
                                            getPlaceColor(place);
                                        return InkWell(
                                          onTap: () {
                                            final propertyId =
                                                place['property_id'];
                                            final pLat = place['geometry']
                                                ['location']['lat'];
                                            final pLng = place['geometry']
                                                ['location']['lng'];

                                            _mapController.move(
                                                LatLng(pLat, pLng), 15.5);

                                            if (propertyId != null) {
                                              try {
                                                final prop = _allProperties
                                                    .firstWhere((p) =>
                                                        p.id ==
                                                        propertyId.toString());
                                                setState(() =>
                                                    _activeProperty = prop);
                                                _showPropertyDrawer(
                                                    context, prop);
                                              } catch (_) {}
                                            }
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 16),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                        color: iconColor,
                                                        width: 2),
                                                  ),
                                                  child: ClipOval(
                                                      child: _buildPlaceAvatar(
                                                          place)),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Text(
                                                    place['name'] ?? 'Unknown',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 14.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: _textDark,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  getDistance(place),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: _textLight,
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
                      // Actions
                      ElevatedButton(
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
                          backgroundColor: _tenantPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 54),
                        ),
                        child: Text(
                          'Get Directions',
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
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
          _openDirections(prop.lat, prop.lng);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AIRBNB STYLE DRAWER (Glass Upgraded)
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

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 1.0, end: 0.0),
      builder: (context, value, child) {
        return Transform.translate(
            offset: Offset(0, value * 100), child: child);
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              border: Border(
                  top: BorderSide(
                      color: Colors.white.withOpacity(0.9), width: 1.5)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image Carousel
                  SizedBox(
                    height: 280,
                    child: Stack(
                      children: [
                        PageView.builder(
                          itemCount: images.length,
                          onPageChanged: (idx) =>
                              setState(() => _currentImageIndex = idx),
                          itemBuilder: (context, index) {
                            return buildPropertyImage(images[index],
                                width: double.infinity,
                                height: 280,
                                fit: BoxFit.cover);
                          },
                        ),
                        if (images.length > 1)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 60,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.5)
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
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
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  width: _currentImageIndex == index ? 16 : 8,
                                  height: 8,
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
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                    height: 1.2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Color(0xFFFBBF24), size: 20),
                                const SizedBox(width: 4),
                                Text('${prop.rating}',
                                    style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black)),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          prop.location,
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: const Color(0xFF6B7280),
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 24),

                        // Price & Actions
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ksh. ${prop.price ~/ 1000}k',
                                  style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF3F37C9)),
                                ),
                                Text('per month',
                                    style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: const Color(0xFF6B7280),
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: widget.onGetDirections,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3F37C9),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text('Directions',
                                    style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                            height: 20), // Extra spacing for safe area
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PROPERTY MARKER
// ─────────────────────────────────────────────

class _PropertyMarker extends StatelessWidget {
  final Property property;
  final bool isActive;

  const _PropertyMarker({required this.property, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 180,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? Colors.black : Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
                color: isActive ? Colors.black : Colors.white, width: 1.5),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              ClipOval(
                child: buildPropertyImage(property.image,
                    width: 28, height: 28, fit: BoxFit.cover),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      property.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      'Ksh.${property.price}/m',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color:
                            isActive ? Colors.white70 : const Color(0xFF3F37C9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (isActive)
          Container(
            width: 10,
            height: 6,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.black, width: 6),
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
// MAP PIN (CURRENT LOCATION - Clean Dot)
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
        // Pulsing rings
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, _) {
            return Container(
              width: 16 + (_pulseAnim.value * 40),
              height: 16 + (_pulseAnim.value * 40),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3F37C9)
                    .withOpacity((1.0 - _pulseAnim.value) * 0.5),
              ),
            );
          },
        ),
        // Inner solid dot
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF3F37C9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3F37C9).withOpacity(0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
