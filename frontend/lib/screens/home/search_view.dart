import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:property_app/models/property.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/property_service.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/utils/property_mapper.dart';
import 'package:property_app/services/analytics/analytics_service.dart';
import 'map_view.dart';
import 'package:property_app/utils/geocoding.dart';

// ─── Design System Constants ──────────────────────────────────────────────────
const _bg = Color(0xFFFAFAFA);
const _dark = Color(0xFF111827);
const _grey = Color(0xFF9CA3AF);
const _primaryText = Color(0xFF4F70F8);

class SearchView extends StatefulWidget {
  final void Function(Property)? onSelectProperty;
  final VoidCallback? onOpenFilters;
  final ValueChanged<bool>? onToggleMap;
  final Map<String, dynamic>? activeFilters;
  final ValueChanged<Map<String, dynamic>>? onFiltersChanged;

  const SearchView({
    super.key,
    this.onSelectProperty,
    this.onOpenFilters,
    this.activeFilters,
    this.onFiltersChanged,
    this.onToggleMap,
  });

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  String query = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _locationSearchTimer;
  int _locationSearchRequest = 0;
  List<GeocodingSuggestion> _locationSuggestions = [];
  GeocodingSuggestion? _selectedLocation;

  final String _sortBy = 'recommended';
  Map<String, dynamic> _activeFilters = {};

  final _propertyService = PropertyService.instance;
  List<Property> _all = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _activeFilters = Map.from(widget.activeFilters ?? {});
    if (_activeFilters['propertyType'] != null &&
        _activeFilters['propertyType'].toString().isNotEmpty) {
      query = _activeFilters['propertyType'].toString();
      _searchController.text = query;
      _activeFilters.remove('propertyType');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onFiltersChanged?.call(_activeFilters);
      });
    }
    _load();
  }

  @override
  void didUpdateWidget(covariant SearchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeFilters != oldWidget.activeFilters) {
      setState(() {
        _activeFilters = Map.from(widget.activeFilters ?? {});
        if (_activeFilters['propertyType'] != null &&
            _activeFilters['propertyType'].toString().isNotEmpty) {
          query = _activeFilters['propertyType'].toString();
          _searchController.text = query;
          _activeFilters.remove('propertyType');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onFiltersChanged?.call(_activeFilters);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _locationSearchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _searchLocations(String value) {
    _locationSearchTimer?.cancel();
    final request = ++_locationSearchRequest;
    if (value.trim().length < 3) {
      setState(() => _locationSuggestions = []);
      return;
    }
    _locationSearchTimer = Timer(const Duration(milliseconds: 450), () async {
      final suggestions = await searchAddressSuggestions(value);
      if (!mounted || request != _locationSearchRequest) return;
      setState(() => _locationSuggestions = suggestions);
    });
  }

  Future<void> _selectSearchLocation(GeocodingSuggestion suggestion) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedLocation = suggestion;
      query = suggestion.displayName;
      _searchController.text = suggestion.displayName;
      _locationSuggestions = [];
    });
    AppSession.discoveryLatitude = suggestion.lat;
    AppSession.discoveryLongitude = suggestion.lng;
    AppSession.discoveryLocationId = suggestion.locationId;
    AppSession.discoveryCampusId =
        suggestion.type == 'campus' ? suggestion.locationId : null;
    if (suggestion.lat == null || suggestion.lng == null) return;

    setState(() => _loading = true);
    try {
      final nearby = await _propertyService.fetchNearby(
        latitude: suggestion.lat!,
        longitude: suggestion.lng!,
        radiusKm: 2,
      );
      if (!mounted) return;
      setState(() {
        _all = nearby;
        _loading = false;
        _hasError = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _hasError = false;
      _loading = true;
    });
    final repo = RemoteDatabaseRepository();

    try {
      await repo.loadPropertiesCached(
        onData: (rawData, isFromCache) {
          if (!mounted) return;
          setState(() {
            _all = rawData.map(mapApiProperty).toList();
            _loading = false;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleSave(String propertyId) async {
    if (AppSession.isGuest) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Login required'),
          content: const Text('Log in to save properties to your account.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                AppSession.isGuest = false;
                Navigator.pop(dialogContext);
                Navigator.pushReplacementNamed(context, '/login');
              },
              icon: const Icon(Icons.login),
              label: const Text('Log in'),
            ),
          ],
        ),
      );
      return;
    }
    final isCurrentlySaved = AppSession.isSaved(propertyId);
    if (AppSession.currentUserId != null && AppSession.apiToken != null) {
      final repository = RemoteDatabaseRepository();
      try {
        if (isCurrentlySaved) {
          await repository.removeFavoriteForUser(
            userId: AppSession.currentUserId!,
            propertyId: propertyId,
          );
          AppSession.savedPropertyIds.remove(propertyId);
        } else {
          await repository.savePropertyForUser(
            userId: AppSession.currentUserId!,
            propertyId: propertyId,
          );
          AppSession.savedPropertyIds.add(propertyId);
          AnalyticsService.logListingInteraction(AnalyticsEvents.listingSave,
              listingId: propertyId);
        }
        return;
      } catch (_) {
        // Fall back to local save state if the request fails.
      }
    }
    AppSession.toggleSaved(propertyId);
  }

  List<Property> get results {
    List<Property> filtered = _all;

    // Search Filtering
    if (query.isNotEmpty) {
      final normalized = query.toLowerCase();
      filtered = filtered.where((property) {
        return property.name.toLowerCase().contains(normalized) ||
            property.location.toLowerCase().contains(normalized);
      }).toList();
    }

    // Additional Filters
    if (_activeFilters.isNotEmpty) {
      final minPrice = _activeFilters['minPrice'];
      final maxPrice = _activeFilters['maxPrice'];
      final propertyType = _activeFilters['propertyType'];
      final amenities = _activeFilters['amenities'];
      final filterBeds = _activeFilters['beds'];
      final filterBaths = _activeFilters['baths'];
      final landlordAvailability = _activeFilters['landlordAvailability'];
      final mostReviews = _activeFilters['mostReviews'] == true;

      if (minPrice != null) {
        final min = (minPrice is num)
            ? minPrice.toInt()
            : int.tryParse(minPrice.toString());
        if (min != null)
          filtered = filtered.where((p) => p.price >= min).toList();
      }

      if (maxPrice != null) {
        final max = (maxPrice is num)
            ? maxPrice.toInt()
            : int.tryParse(maxPrice.toString());
        if (max != null)
          filtered = filtered.where((p) => p.price <= max).toList();
      }

      if (propertyType != null) {
        final selectedType = propertyType.toString();
        if (selectedType.trim().isNotEmpty) {
          filtered = filtered.where((p) {
            final cat = p.category.toLowerCase().trim();
            final normalizedType = selectedType.toLowerCase().trim();
            bool categoryMatches = cat.isNotEmpty &&
                (cat == normalizedType || cat.contains(normalizedType));

            bool bedsMatches = false;
            final beds = p.features.beds;
            switch (normalizedType) {
              case 'bedsitter':
              case 'single':
                bedsMatches = beds <= 1;
                break;
              case 'one bedroom':
              case 'one-bedroom':
              case '1 bedroom':
                bedsMatches = beds == 1;
                break;
            }
            return categoryMatches || bedsMatches;
          }).toList();
        }
      }

      if (amenities is List && amenities.isNotEmpty) {
        final selectedAmenities = amenities
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (selectedAmenities.isNotEmpty) {
          filtered = filtered.where((p) {
            final propAmenities =
                p.amenities.map((a) => a.toLowerCase().trim()).toSet();
            for (final a in selectedAmenities) {
              if (!propAmenities.contains(a.toLowerCase())) return false;
            }
            return true;
          }).toList();
        }
      }

      if (filterBeds != null && filterBeds is int && filterBeds > 0) {
        filtered = filtered
            .where((p) => filterBeds >= 5
                ? p.features.beds >= 5
                : p.features.beds == filterBeds)
            .toList();
      }

      if (filterBaths != null && filterBaths is int && filterBaths > 0) {
        filtered = filtered
            .where((p) => filterBaths >= 5
                ? p.features.baths >= 5
                : p.features.baths == filterBaths)
            .toList();
      }

      if (landlordAvailability == 'Superhost') {
        filtered = filtered.where((p) => p.agent.verified).toList();
      }

      if (mostReviews) {
        filtered.sort((a, b) => b.reviews.compareTo(a.reviews));
      } else {
        switch (_sortBy) {
          case 'price_low':
            filtered.sort((a, b) => a.price.compareTo(b.price));
            break;
          case 'price_high':
            filtered.sort((a, b) => b.price.compareTo(a.price));
            break;
          case 'rating':
            filtered.sort((a, b) => b.rating.compareTo(a.rating));
            break;
          case 'name':
            filtered.sort((a, b) => a.name.compareTo(b.name));
            break;
          case 'recommended':
          default:
            break;
        }
      }
    }

    return filtered;
  }

  // ─── UI Builders ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final hasFilter = _activeFilters.isNotEmpty;
    final hasQuery = query.trim().isNotEmpty;
    final title = hasFilter && hasQuery
        ? 'No homes match your search'
        : hasFilter
            ? 'No homes match the selected filters'
            : 'No homes found';
    final subtitle = hasFilter && hasQuery
        ? 'Try a different location, adjust the price range, or clear some filters.'
        : hasFilter
            ? 'Try clearing a few filters or widening the price range.'
            : 'Try searching for another location or browse nearby homes.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(PhosphorIconsRegular.magnifyingGlassMinus,
                size: 64, color: _grey),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w700, color: _dark),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: _grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 24,
        mainAxisExtent: 260, // Fixed height to fit image + text nicely
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Shimmer.fromColors(
              baseColor: Colors.grey.shade200,
              highlightColor: Colors.grey.shade100,
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Shimmer.fromColors(
              baseColor: Colors.grey.shade200,
              highlightColor: Colors.grey.shade100,
              child: Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4))),
            ),
            const SizedBox(height: 8),
            Shimmer.fromColors(
              baseColor: Colors.grey.shade200,
              highlightColor: Colors.grey.shade100,
              child: Container(
                  height: 12,
                  width: 80,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4))),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGridCard(Property property, int index) {
    final isSaved = AppSession.isSaved(property.id);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: VisibilityDetector(
        key: Key('search_impression_${property.id}'),
        onVisibilityChanged: (info) {
          if (info.visibleFraction > 0.5) {
            AnalyticsService.logListingInteraction(
                AnalyticsEvents.listingImpression,
                listingId: property.id);
          }
        },
        child: GestureDetector(
          onTap: () => widget.onSelectProperty?.call(property),
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Square Image Box
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: buildPropertyImage(
                        property.image,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () {
                        _toggleSave(property.id).then((_) => setState(() {}));
                      },
                      child: Icon(
                        isSaved
                            ? PhosphorIconsFill.heart
                            : PhosphorIconsRegular.heart,
                        size: 24,
                        color: isSaved ? const Color(0xFFEC4899) : Colors.white,
                        shadows: [
                          if (!isSaved)
                            const Shadow(
                              color: Colors.black45,
                              blurRadius: 8,
                              offset: Offset(0, 1),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2. Tighter Details Section (Scaled for 2 columns)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      property.location,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (property.reviews > 0)
                    Row(
                      children: [
                        const Icon(PhosphorIconsFill.star,
                            size: 12, color: _dark),
                        const SizedBox(width: 4),
                        Text(
                          property.rating.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _dark,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                property.name,
                style: GoogleFonts.poppins(fontSize: 12, color: _grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${property.features.beds} Beds',
                style: GoogleFonts.poppins(fontSize: 12, color: _grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'Ksh. ${property.price ~/ 1000}k',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                  Text(
                    ' /mo',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: _dark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg, // Solid background
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// HEADER
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Text(
                    'Search',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Where do you want to live?',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: _grey,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                /// SEARCH BAR
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32), // Pill shape
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04), // Soft shadow
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 16),
                          child: Icon(PhosphorIconsRegular.magnifyingGlass,
                              size: 22, color: _dark),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() {
                                query = value;
                                _selectedLocation = null;
                              });
                              _searchLocations(value);
                            },
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _dark,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search destinations',
                              hintStyle: GoogleFonts.poppins(
                                color: _grey,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 15),
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => query = '');
                              FocusScope.of(context).unfocus();
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(PhosphorIconsFill.xCircle,
                                  color: _grey, size: 20),
                            ),
                          ),
                        Container(
                            width: 1,
                            height: 24,
                            color: _grey.withOpacity(0.2)),
                        GestureDetector(
                          onTap: widget.onOpenFilters,
                          child: const Padding(
                            padding: EdgeInsets.only(right: 16, left: 14),
                            child: Icon(PhosphorIconsRegular.faders,
                                size: 22, color: _dark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_locationSuggestions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 3,
                      child: Column(
                        children: _locationSuggestions.map((suggestion) {
                          return ListTile(
                            leading: Icon(
                              suggestion.type == 'hospital'
                                  ? Icons.local_hospital_outlined
                                  : suggestion.type == 'campus'
                                      ? Icons.school_outlined
                                      : Icons.location_on_outlined,
                              color: _primaryText,
                            ),
                            title: Text(suggestion.displayName),
                            subtitle: Text([
                              if (suggestion.secondaryName != null)
                                suggestion.secondaryName!,
                              if (suggestion.type != null) suggestion.type!,
                            ].join(' · ')),
                            onTap: () => _selectSearchLocation(suggestion),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                /// RESULTS (2-Column Grid View)
                Expanded(
                  child: _loading
                      ? _buildShimmerLoading()
                      : _hasError
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(PhosphorIconsRegular.warningCircle,
                                      size: 48, color: Color(0xFFEF4444)),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Failed to load properties',
                                    style: GoogleFonts.poppins(
                                        color: _dark,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: _load,
                                    child: Text('Retry',
                                        style: GoogleFonts.poppins(
                                            color: _primaryText)),
                                  )
                                ],
                              ),
                            )
                          : results.isEmpty
                              ? _buildEmptyState()
                              : GridView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  padding:
                                      const EdgeInsets.fromLTRB(24, 0, 24, 120),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 24,
                                    mainAxisExtent:
                                        260, // Exact height prevents grid overflows
                                  ),
                                  itemCount: results.length,
                                  itemBuilder: (context, index) {
                                    return _buildGridCard(
                                        results[index], index);
                                  },
                                ),
                ),
              ],
            ),

            // REVERTED ORIGINAL MAP FLOATING BUTTON
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 92,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MapViewScreen(
                              onBack: () => Navigator.pop(context),
                              onFilter: () {
                                if (widget.onOpenFilters != null)
                                  widget.onOpenFilters!();
                              },
                              onSelectProperty: widget.onSelectProperty,
                              properties: results,
                              searchQuery: query,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map_rounded, size: 20),
                      label: const Text('Map',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: Colors.black45,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
