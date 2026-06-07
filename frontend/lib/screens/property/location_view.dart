import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:property_app/models/property.dart';
import 'package:property_app/services/property_service.dart';
import 'package:property_app/theme.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:latlong2/latlong.dart';

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

  static const LatLng _fallbackLocation = LatLng(-3.6305, 39.8499);

  LatLng? _currentLocation;
  String? _currentAddress;
  bool _loadingPlaces = false;
  bool _fetchingLocation = false;

  List<dynamic> nearbyPlaces = [];
  Property? _activeProperty;
  List<Property> _allProperties = [];

  /// GOOGLE API KEY - Leave empty or 'YOUR_GOOGLE_API_KEY' to use OpenStreetMap fallback
  static const String googleApiKey = 'YOUR_GOOGLE_API_KEY';

  bool get _hasGoogleApiKeyConfigured =>
      googleApiKey.isNotEmpty && googleApiKey != 'YOUR_GOOGLE_API_KEY';

  String get _locationTitle {
    if (_activeProperty != null) {
      return 'Property location';
    }
    return 'Current location';
  }

  String get _locationSubtitle {
    if (_activeProperty != null) {
      return _activeProperty!.location;
    }
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
  // INITIALIZE LOCATION
  // ─────────────────────────────────────────────

  Future<void> _initializeLocation() async {
    if (_fetchingLocation) return;
    _fetchingLocation = true;

    try {
      _allProperties = await PropertyService.instance.fetchProperties();
      await _getCurrentLocation();

      final targetLocation = _currentLocation ??
          (_activeProperty != null
              ? LatLng(_activeProperty!.lat, _activeProperty!.lng)
              : _fallbackLocation);

      if (_currentLocation != null && _activeProperty != null) {
        final propertyPoint =
            LatLng(_activeProperty!.lat, _activeProperty!.lng);
        final bounds = LatLngBounds.fromPoints([
          _currentLocation!,
          propertyPoint,
        ]);
        _mapController.fitBounds(
          bounds,
          options: const FitBoundsOptions(padding: EdgeInsets.all(48)),
        );
      } else {
        _mapController.move(targetLocation, 15);
      }

      await fetchNearbyPlaces(targetLocation);
    } catch (e) {
      debugPrint('Location init error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _fetchingLocation = false;
        });
      }
    }
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
          _currentLocation = LatLng(
            position.latitude,
            position.longitude,
          );
          _currentAddress = 'Fetching address...';
        });
        await _reverseGeocode();
      }
    } catch (e) {
      debugPrint('Location fetch error: $e');
      _showErrorSnackBar('Unable to fetch current location.');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
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
        final response = await http
            .get(url, headers: {'User-Agent': 'PropertyApp/1.0'})
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (mounted) {
            setState(() {
              _currentAddress = data['display_name'] ?? 'Unknown address';
            });
          }
          return;
        }
      } catch (e) {
        debugPrint('Nominatim fallback error: $e');
      }

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
            _currentAddress =
                results.first['formatted_address'] as String? ?? 'Unknown address';
          });
          return;
        }
      }
      setState(() => _currentAddress = 'Unknown address');
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
      if (mounted) setState(() => _currentAddress = 'Unable to fetch address');
    }
  }

  // ─────────────────────────────────────────────
  // FETCH NEARBY PLACES
  // ─────────────────────────────────────────────

  Future<void> fetchNearbyPlaces([LatLng? target]) async {
    final location = target ??
        _currentLocation ??
        (_activeProperty != null
            ? LatLng(_activeProperty!.lat, _activeProperty!.lng)
            : _fallbackLocation);

    setState(() {
      _loadingPlaces = true;
    });

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
    } catch (e) {
      debugPrint('Places fetch error: $e');
      if (mounted) setState(() => nearbyPlaces = _localNearbyPlaces(location));
    }

    if (mounted) {
      setState(() {
        _loadingPlaces = false;
      });
    }
  }

  List<Map<String, dynamic>> _localNearbyPlaces(LatLng origin) {
    final results = _allProperties
        .where((prop) => prop.lat != 0 || prop.lng != 0)
        .map((prop) {
      final dist = Geolocator.distanceBetween(
        origin.latitude,
        origin.longitude,
        prop.lat,
        prop.lng,
      );
      return {
        'name': prop.name,
        'property_id': prop.id,
        'types': ['property'],
        'dist': '${(dist / 1000).toStringAsFixed(1)} km',
        'geometry': {
          'location': {'lat': prop.lat, 'lng': prop.lng},
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

    // We don't filter out the active property here so it remains clickable in the nearby list
    return results.take(4).toList();
  }

  // ─────────────────────────────────────────────
  // DIRECTIONS LAUNCHER
  // ─────────────────────────────────────────────

  Future<void> _openDirections(double destLat, double destLng) async {
    final origin = _currentLocation;
    final originParam =
        origin != null ? '${origin.latitude},${origin.longitude}' : '';
    final destParam = '$destLat,$destLng';

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$originParam&destination=$destParam&travelmode=driving',
    );

    try {
      // By skipping canLaunchUrl, we bypass Android 11 intent visibility strictness
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showErrorSnackBar('Could not launch maps application.');
    }
  }

  // ─────────────────────────────────────────────
  // PLACE UI HELPERS
  // ─────────────────────────────────────────────

  Color getPlaceColor(dynamic place) {
    final types = place['types'];
    if (types is List && types.contains('property')) {
      return const Color(0xFF3F37C9);
    }
    final name = (place['name'] ?? '').toString().toLowerCase();
    if (name.contains('school') || name.contains('university')) {
      return const Color(0xFFF59E0B);
    }
    if (name.contains('hospital') || name.contains('clinic')) {
      return const Color(0xFFEF4444);
    }
    if (name.contains('police') || name.contains('security')) {
      return const Color(0xFF3F37C9);
    }
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
      return buildPropertyImage(
        imageSource,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
      );
    }

    return Container(
      color: const Color(0xFFF3F4F6),
      child: const Icon(
        Icons.place_rounded,
        color: Color(0xFF6B7280),
        size: 22,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentLocation = _currentLocation;
    final propertyLocation = _activeProperty != null
        ? LatLng(_activeProperty!.lat, _activeProperty!.lng)
        : null;
    final location = currentLocation ?? propertyLocation ?? _fallbackLocation;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              // HEADER
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 24,
                  right: 24,
                  bottom: 16,
                ),
                color: Colors.white,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onClose,
                      behavior: HitTestBehavior.opaque,
                      child: const Icon(
                        Icons.arrow_back,
                        size: 28,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // BODY
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // MAP SECTION
                      SizedBox(
                        height: 380,
                        child: ClipRRect(
                          borderRadius: AppRadius.cardBorderRadius,
                          child: Container(
                            decoration: BoxDecoration(
                              color: StayNestColors.surfaceVariantLight,
                              boxShadow: AppShadow.sm,
                            ),
                            child: FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: location,
                                initialZoom: 15.5,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.drag |
                                      InteractiveFlag.pinchZoom,
                                ),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
                                  subdomains: const ['a', 'b', 'c', 'd'],
                                  userAgentPackageName:
                                      'com.example.property_app',
                                ),
                                MarkerLayer(
                                  markers: [
                                    ..._allProperties
                                        .where((prop) =>
                                            prop.lat != 0 || prop.lng != 0)
                                        .map((prop) {
                                      final isActive =
                                          _activeProperty?.id == prop.id;
                                      return Marker(
                                        point: LatLng(prop.lat, prop.lng),
                                        width: 180,
                                        height: 56,
                                        child: Tooltip(
                                          message:
                                              '${prop.name}\n${prop.lat.toStringAsFixed(4)}, ${prop.lng.toStringAsFixed(4)}',
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _activeProperty = prop;
                                              });
                                              _mapController.move(
                                                  LatLng(prop.lat, prop.lng),
                                                  _mapController.camera.zoom);
                                              _showPropertyDrawer(
                                                  context, prop);
                                            },
                                            child: _PropertyMarker(
                                              property: prop,
                                              isActive: isActive,
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                    if (currentLocation != null)
                                      Marker(
                                        point: currentLocation,
                                        width: 120,
                                        height: 120,
                                        child: Tooltip(
                                          message:
                                              'Current location\n${currentLocation.latitude.toStringAsFixed(4)}, ${currentLocation.longitude.toStringAsFixed(4)}',
                                          child: const _MapPin(),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // CONTENT CARD
                      Transform.translate(
                        offset: const Offset(0, -32),
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(32)),
                          ),
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // LOCATION TITLE
                              Text(
                                _locationTitle,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _locationSubtitle,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                              const SizedBox(height: 36),

                              // HEADER
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Nearby Places',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => fetchNearbyPlaces(),
                                    child: const Text(
                                      'Refresh',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF3F37C9),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: _loadingPlaces
                                    ? Column(
                                        key: const ValueKey('loading'),
                                        children: List.generate(
                                            4,
                                            (index) =>
                                                const _PlaceSkeleton()),
                                      )
                                    : nearbyPlaces.isEmpty
                                        ? const Padding(
                                            key: ValueKey('empty'),
                                            padding: EdgeInsets.only(top: 40),
                                            child: Center(
                                              child: Text(
                                                  'No nearby places found.',
                                                  style: TextStyle(
                                                      color: Colors.grey)),
                                            ),
                                          )
                                        : Column(
                                            key: const ValueKey('list'),
                                            children: nearbyPlaces.map((place) {
                                              final Color iconColor =
                                                  getPlaceColor(place);
                                              return InkWell(
                                                key: ValueKey(place['name'] ??
                                                    place.hashCode.toString()),
                                                onTap: () {
                                                  // Center map and activate property drawer if it's a property
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
                                                      final prop =
                                                          _allProperties
                                                              .firstWhere((p) =>
                                                                  p.id ==
                                                                  propertyId
                                                                      .toString());
                                                      setState(() {
                                                        _activeProperty = prop;
                                                      });
                                                      _showPropertyDrawer(
                                                          context, prop);
                                                    } catch (_) {}
                                                  }
                                                },
                                                borderRadius: BorderRadius.circular(12),
                                                child: Padding(
                                                  padding: const EdgeInsets.only(bottom: 24),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 44,
                                                        height: 44,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          border: Border.all(
                                                            color: iconColor,
                                                            width: 2.5,
                                                          ),
                                                        ),
                                                        child: ClipOval(
                                                          child:
                                                              _buildPlaceAvatar(
                                                                  place),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 16),
                                                      Expanded(
                                                        child: Text(
                                                          place['name'] ??
                                                              'Unknown',
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Text(
                                                        getDistance(place),
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // BOTTOM BUTTON
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).padding.bottom + 24,
            child: ElevatedButton(
              onPressed: widget.onGetDirections ??
                  () {
                    if (_activeProperty != null) {
                      _openDirections(
                          _activeProperty!.lat, _activeProperty!.lng);
                    } else if (nearbyPlaces.isNotEmpty) {
                      final pLat =
                          nearbyPlaces.first['geometry']['location']['lat'];
                      final pLng =
                          nearbyPlaces.first['geometry']['location']['lng'];
                      _openDirections(pLat, pLng);
                    } else {
                      _showErrorSnackBar('No destination available.');
                    }
                  },
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
                'Get Directions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
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
// AIRBNB STYLE DRAWER
// ─────────────────────────────────────────────

class _PropertyDrawer extends StatefulWidget {
  final Property property;
  final VoidCallback onGetDirections;

  const _PropertyDrawer({
    required this.property,
    required this.onGetDirections,
  });

  @override
  State<_PropertyDrawer> createState() => _PropertyDrawerState();
}

class _PropertyDrawerState extends State<_PropertyDrawer> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final prop = widget.property;
    final images = (prop.images.isNotEmpty)
        ? prop.images
        : [prop.image];

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 1.0, end: 0.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, value * 100),
          child: child,
        );
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, -5),
            )
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Edge-to-edge Image Carousel
              SizedBox(
                height: 280,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28)),
                      child: PageView.builder(
                        itemCount: images.length,
                        onPageChanged: (idx) {
                          setState(() {
                            _currentImageIndex = idx;
                          });
                        },
                        itemBuilder: (context, index) {
                          return buildPropertyImage(
                            images[index],
                            width: double.infinity,
                            height: 280,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                    // Gradient shadow for bottom indicators
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
                    // Pull Handle Overlay
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
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              )
                            ],
                          ),
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
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Color(0xFFFBBF24), size: 22),
                            const SizedBox(width: 4),
                            Text(
                              '${prop.rating ?? 4.8}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      prop.location,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Price & Full-width Actions
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ksh. ${prop.price ~/ 1000}k',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                            const Text(
                              'per month',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: widget.onGetDirections,
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
                              'Directions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20), // Extra spacing for safe area
                  ],
                ),
              ),
            ],
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
            color: isActive ? Colors.black : Colors.white,
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
            children: [
              ClipOval(
                child: buildPropertyImage(
                  property.image,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                ),
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
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isActive ? Colors.white : Colors.black,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'Ksh.${property.price}/m',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isActive
                            ? Colors.white70
                            : const Color(0xFF3F37C9),
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
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
        // Vision cone simulation
        Positioned(
          top: 60,
          left: 60,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3F37C9).withOpacity(0.4),
                    const Color(0xFF3F37C9).withOpacity(0.0),
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
                    const Color(0xFF06B6D4).withOpacity(1.0 - _pulseAnim.value),
              ),
            );
          },
        ),

        // Inner solid dot
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF06B6D4),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF06B6D4).withOpacity(0.5),
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

// ─────────────────────────────────────────────
// SKELETON
// ─────────────────────────────────────────────

class _PlaceSkeleton extends StatelessWidget {
  const _PlaceSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE5E7EB), width: 2.5),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 14,
            width: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}