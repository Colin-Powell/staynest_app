// lib/screens/search/search_view.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/models/property.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/property_service.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/utils/property_mapper.dart';
import '../../widgets/phosphor_icons.dart';
import 'package:property_app/screens/dashboard/analytics_service.dart';
import 'package:visibility_detector/visibility_detector.dart';

// ─── Theme colors ─────────────────────────────────────────────────────────────
const _primaryText = Color(0xFF4F70F8);
const _bg = Color(0xFFFAFAFA);
const _dark = Color(0xFF111827);
const _grey = Color(0xFF9CA3AF);
const _green = Color(0xFF22C55E);

class SearchView extends StatefulWidget {
  final ValueChanged<String>? onSelectProperty;
  final VoidCallback? onOpenFilters;
  final ValueChanged<bool>? onToggleMap;
  final Map<String, dynamic>? activeFilters;

  const SearchView({
    super.key,
    this.onSelectProperty,
    this.onOpenFilters,
    this.activeFilters,
    this.onToggleMap,
  });

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  String query = '';
  final TextEditingController _searchController = TextEditingController();

  String _sortBy =
      'recommended'; // recommended, price_low, price_high, rating, name
  Map<String, dynamic> _activeFilters = {};

  final _propertyService = PropertyService.instance;
  List<Property> _all = [];
  bool _loading = true;

  // ==================== SVG ICONS ====================
  final String searchSvg =
      '''<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" fill="#000000" viewBox="0 0 256 256"><path d="M232.49,215.51,185,168a92.12,92.12,0,1,0-17,17l47.53,47.54a12,12,0,0,0,17-17ZM44,112a68,68,0,1,1,68,68A68.07,68.07,0,0,1,44,112Z"></path></svg>''';

  final String xCircleSvg =
      '''<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" fill="#000000" viewBox="0 0 256 256"><path d="M168.49,104.49,145,128l23.52,23.51a12,12,0,0,1-17,17L128,145l-23.51,23.52a12,12,0,0,1-17-17L111,128,87.51,104.49a12,12,0,0,1,17-17L128,111l23.51-23.52a12,12,0,0,1,17,17ZM236,128A108,108,0,1,1,128,20,108.12,108.12,0,0,1,236,128Zm-24,0a84,84,0,1,0-84,84A84.09,84.09,0,0,0,212,128Z"></path></svg>''';

  final String filterSvg =
      '''<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" fill="#000000" viewBox="0 0 256 256"><path d="M176,80a12,12,0,0,1,12-12h28a12,12,0,0,1,0,24H188A12,12,0,0,1,176,80ZM40,92h96v12a12,12,0,0,0,24,0V56a12,12,0,0,0-24,0V68H40a12,12,0,0,0,0,24Zm176,72H124a12,12,0,0,0,0,24h92a12,12,0,0,0,0-24ZM84,140a12,12,0,0,0-12,12v12H40a12,12,0,0,0,0,24H72v12a12,12,0,0,0,24,0V152A12,12,0,0,0,84,140Z"></path></svg>''';

  final String sortSvg =
      '''<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" fill="#000000" viewBox="0 0 256 256"><path d="M128,128a12,12,0,0,1-12,12H48a12,12,0,0,1,0-24h68A12,12,0,0,1,128,128ZM48,76H180a12,12,0,0,0,0-24H48a12,12,0,0,0,0,24Zm52,104H48a12,12,0,0,0,0,24h52a12,12,0,0,0,0-24Zm132.49-20.49a12,12,0,0,0-17,0L196,179V112a12,12,0,0,0-24,0v67l-19.51-19.52a12,12,0,0,0-17,17l40,40a12,12,0,0,0,17,0l40-40A12,12,0,0,0,232.49,159.51Z"></path></svg>''';
  // ===================================================

  @override
  void initState() {
    super.initState();
    _activeFilters = widget.activeFilters ?? {};
    _load();
  }

  @override
  void didUpdateWidget(covariant SearchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeFilters != oldWidget.activeFilters) {
      setState(() => _activeFilters = widget.activeFilters ?? {});
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = RemoteDatabaseRepository();

    await repo.loadPropertiesCached(
      onData: (rawData, isFromCache) {
        if (!mounted) return;
        setState(() {
          _all = rawData.map(mapApiProperty).toList();
          _loading = false;
        });
      },
    );
  }

  Future<void> _toggleSave(String propertyId) async {
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
          AnalyticsService.trackPropertySave(propertyId);
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

      if (minPrice != null) {
        final min = (minPrice is num)
            ? minPrice.toInt()
            : int.tryParse(minPrice.toString());
        if (min != null) {
          filtered = filtered.where((p) => p.price >= min).toList();
        }
      }

      if (maxPrice != null) {
        final max = (maxPrice is num)
            ? maxPrice.toInt()
            : int.tryParse(maxPrice.toString());
        if (max != null) {
          filtered = filtered.where((p) => p.price <= max).toList();
        }
      }

      // Property Type
      if (propertyType != null) {
        final selectedType = propertyType.toString();
        if (selectedType.trim().isNotEmpty) {
          filtered = filtered.where((p) {
            // Prefer category match if available.
            final cat = p.category.toLowerCase().trim();
            final normalizedType = selectedType.toLowerCase().trim();

            bool categoryMatches = false;
            if (cat.isNotEmpty) {
              // Accept either exact match or partial match (e.g. 'one bedroom').
              categoryMatches =
                  cat == normalizedType || cat.contains(normalizedType);
            }

            // Fallback to beds-based heuristics.
            bool bedsMatches = false;
            final beds = p.features.beds;
            switch (normalizedType) {
              case 'apartment':
                // No strict mapping available; treat as category match primarily.
                bedsMatches = false;
                break;
              case 'bedsitter':
                bedsMatches = beds <= 1;
                break;
              case 'single':
                bedsMatches = beds <= 1;
                break;
              case 'one bedroom':
              case 'one-bedroom':
              case '1 bedroom':
                bedsMatches = beds == 1;
                break;
              default:
                bedsMatches = false;
            }

            return categoryMatches || bedsMatches;
          }).toList();
        }
      }

      // Amenities (must include all selected amenities)
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
              if (!propAmenities.contains(a.toLowerCase())) {
                return false;
              }
            }
            return true;
          }).toList();
        }
      }
    }

    // Sorting
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

    return filtered;
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _GlassContainer(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          opacity: 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text('Sort By',
                  style: GoogleFonts.poppins(
                      fontSize: 20, fontWeight: FontWeight.w800, color: _dark)),
              const SizedBox(height: 16),
              _buildSortOption('Recommended', 'recommended'),
              _buildSortOption('Price: Low to High', 'price_low'),
              _buildSortOption('Price: High to Low', 'price_high'),
              _buildSortOption('Highest Rated', 'rating'),
              _buildSortOption('Name (A-Z)', 'name'),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

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
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 40, color: _primaryText),
            ),
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
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w500, color: _grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String title, String value) {
    final isSelected = _sortBy == value;
    return ListTile(
      title: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 15,
              color: isSelected ? _primaryText : _dark,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: _primaryText)
          : null,
      onTap: () {
        setState(() => _sortBy = value);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Soft Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _bg,
                  Color(0xFFF3F4F6),
                  Color(0xFFEEF2FF), // Very subtle hint of blue
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// HEADER (Uncluttered)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Text(
                    'Search',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                      letterSpacing: -1.0,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                /// SUBHEADING
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text('Where do you want to live?',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _grey)),
                ),

                const SizedBox(height: 24),

                /// SEARCH BAR (Clean Magic Glass Pill)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _GlassContainer(
                    padding: EdgeInsets.zero,
                    height: 54,
                    borderRadius: BorderRadius.circular(28),
                    opacity: 0.6,
                    child: Row(
                      children: [
                        Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: SvgPicture.string(searchSvg,
                                width: 24,
                                height: 24,
                                colorFilter: const ColorFilter.mode(
                                    _grey, BlendMode.srcIn))),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              AnalyticsService.resetSessionImpressions();
                              setState(() => query = value);
                            },
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _dark),
                            // Disable native lines and fills
                            decoration: InputDecoration(
                              hintText: 'Kilifi, Kenya',
                              hintStyle: GoogleFonts.poppins(
                                  color: _grey, fontSize: 16),
                              filled: false,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 15),
                            ),
                          ),
                        ),
                        // Smart Clear Button
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _searchController,
                          builder: (context, value, child) {
                            if (value.text.isNotEmpty) {
                              return GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() => query = '');
                                  FocusScope.of(context).unfocus();
                                },
                                child: Padding(
                                  padding:
                                      const EdgeInsets.only(right: 16, left: 8),
                                  child: SvgPicture.string(xCircleSvg,
                                      width: 22,
                                      height: 22,
                                      colorFilter: const ColorFilter.mode(
                                          _grey, BlendMode.srcIn)),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                /// FILTERS & SORT (Floating Icons/Text without Glass Boundaries)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.onOpenFilters,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.string(filterSvg,
                                      width: 22,
                                      height: 22,
                                      colorFilter: const ColorFilter.mode(
                                          _dark, BlendMode.srcIn)),
                                  const SizedBox(width: 8),
                                  Text('Filters',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: _dark)),
                                ]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: _showSortOptions,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.string(sortSvg,
                                      width: 22,
                                      height: 22,
                                      colorFilter: const ColorFilter.mode(
                                          _dark, BlendMode.srcIn)),
                                  const SizedBox(width: 8),
                                  Text('Sort',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: _dark)),
                                ]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                /// RESULTS
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: _primaryText))
                      : results.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                  24, 0, 24, 120), // Bottom clearance
                              itemCount: results.length,
                              itemBuilder: (context, index) {
                                final property = results[index];
                                final isSaved = AppSession.isSaved(property.id);
                                return TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: Duration(
                                      milliseconds: 400 + (index * 60)),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, child) {
                                    return Transform.translate(
                                      offset: Offset(0, 30 * (1 - value)),
                                      child: Opacity(
                                        opacity: value,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: VisibilityDetector(
                                      key: Key(
                                          'search_impression_${property.id}'),
                                      onVisibilityChanged: (info) {
                                        if (info.visibleFraction > 0.5) {
                                          AnalyticsService
                                              .trackPropertyImpression(
                                            property.id,
                                            source: 'search',
                                            position: index,
                                            query: query,
                                            filters: _activeFilters,
                                          );
                                        }
                                      },
                                      child: GestureDetector(
                                        onTap: () => widget.onSelectProperty
                                            ?.call(property.id),
                                        child: SizedBox(
                                          height: 140,
                                          child: _GlassContainer(
                                            padding: EdgeInsets
                                                .zero, // Flush edge padding
                                            borderRadius:
                                                BorderRadius.circular(24),
                                            child: Row(
                                              children: [
                                                // Flush Image to the left side
                                                ClipRRect(
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                    topLeft:
                                                        Radius.circular(24),
                                                    bottomLeft:
                                                        Radius.circular(24),
                                                  ),
                                                  child: buildPropertyImage(
                                                    property.image,
                                                    width: 120,
                                                    height: double.infinity,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .fromLTRB(
                                                        16, 14, 16, 14),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                property.name,
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                  fontSize: 16,
                                                                  color: _dark,
                                                                ),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                            GestureDetector(
                                                              onTap: () {
                                                                _toggleSave(
                                                                        property
                                                                            .id)
                                                                    .then((_) =>
                                                                        setState(
                                                                            () {}));
                                                              },
                                                              child: Icon(
                                                                isSaved
                                                                    ? AppIcons
                                                                        .heart
                                                                    : AppIcons
                                                                        .heartOutline,
                                                                size: 24,
                                                                color: isSaved
                                                                    ? const Color(
                                                                        0xFFEC4899)
                                                                    : const Color(
                                                                        0xFFD1D5DB),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        Row(
                                                          children: [
                                                            const Icon(
                                                                AppIcons
                                                                    .location,
                                                                size: 14,
                                                                color: _grey),
                                                            const SizedBox(
                                                                width: 4),
                                                            Expanded(
                                                              child: Text(
                                                                property
                                                                    .location,
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  fontSize: 13,
                                                                  color: _grey,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                            height: 6),
                                                        Text(
                                                          'Kes. ${property.price ~/ 1000}k/mo',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: _dark,
                                                          ),
                                                        ),
                                                        const Spacer(),
                                                        Row(
                                                          children: [
                                                            if (property
                                                                    .reviews >
                                                                0)
                                                              Container(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical:
                                                                        4),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .white
                                                                      .withOpacity(
                                                                          0.8),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              10),
                                                                  border: Border.all(
                                                                      color: Colors
                                                                          .white),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    const Icon(
                                                                        Icons
                                                                            .star_rounded,
                                                                        size:
                                                                            15,
                                                                        color: Color(
                                                                            0xFFF59E42)),
                                                                    const SizedBox(
                                                                        width:
                                                                            4),
                                                                    Text(
                                                                      property
                                                                          .rating
                                                                          .toStringAsFixed(
                                                                              1),
                                                                      style: GoogleFonts
                                                                          .poppins(
                                                                        fontSize:
                                                                            12,
                                                                        fontWeight:
                                                                            FontWeight.w700,
                                                                        color:
                                                                            _dark,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            const SizedBox(
                                                                width: 10),
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          4),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: const Color(
                                                                    0xFFE0F2FE),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                              ),
                                                              child: const Text(
                                                                'Crowd Sourced',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: Color(
                                                                      0xFF0369A1),
                                                                ),
                                                              ),
                                                            ),
                                                            const Spacer(),
                                                            Text(
                                                              '${property.features.beds} Beds',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                fontSize: 13,
                                                                color: _grey,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Glassmorphism Core Utility ──────────────────────────────────────────────
class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final double blur;
  final double opacity;
  final double borderWidth;
  final double? height;

  const _GlassContainer({required this.child, this.padding = EdgeInsets.zero, this.borderRadius, this.blur = 16.0, this.opacity = 0.1, this.borderWidth = 1.0});





  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(24);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
