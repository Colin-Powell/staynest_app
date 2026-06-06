import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:property_app/models/property.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/property_service.dart';
import 'package:property_app/widgets/property_image.dart';
import '../../widgets/phosphor_icons.dart';

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

  Future<void> _load() async {
    final loaded = await _propertyService.fetchProperties();
    if (!mounted) return;
    setState(() {
      _all = loaded;
      _loading = false;
    });
  }

  Future<void> _toggleSave(String propertyId) async {
    final isCurrentlySaved = AppSession.isSaved(propertyId);
    if (AppSession.currentUserId != null && AppSession.apiToken != null) {
      final repository = RemoteDatabaseRepository();
      try {
        if (isCurrentlySaved) {
          await repository.removeFavoriteForUser(
              AppSession.currentUserId!, propertyId);
          AppSession.savedPropertyIds.remove(propertyId);
        } else {
          await repository.savePropertyForUser(
              AppSession.currentUserId!, propertyId);
          AppSession.savedPropertyIds.add(propertyId);
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

    if (query.isNotEmpty) {
      final normalized = query.toLowerCase();
      filtered = filtered.where((property) {
        return property.name.toLowerCase().contains(normalized) ||
            property.location.toLowerCase().contains(normalized);
      }).toList();
    }

    if (_activeFilters.isNotEmpty) {
      if (_activeFilters['minPrice'] != null) {
        filtered = filtered
            .where((p) => p.price >= _activeFilters['minPrice'])
            .toList();
      }
      if (_activeFilters['maxPrice'] != null) {
        filtered = filtered
            .where((p) => p.price <= _activeFilters['maxPrice'])
            .toList();
      }
      // Add more filter logic as needed
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Sort By', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              _buildSortOption('Recommended', 'recommended'),
              _buildSortOption('Price: Low to High', 'price_low'),
              _buildSortOption('Price: High to Low', 'price_high'),
              _buildSortOption('Highest Rated', 'rating'),
              _buildSortOption('Name (A-Z)', 'name'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String title, String value) {
    final isSelected = _sortBy == value;
    return ListTile(
      title: Text(title,
          style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
      trailing:
          isSelected ? const Icon(Icons.check, color: Color(0xFF111827)) : null,
      onTap: () {
        setState(() => _sortBy = value);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Search',
                      style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                          letterSpacing: -1.0)),
                  Stack(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFF3F4F6))),
                        child: const Icon(AppIcons.bell,
                            color: Color(0xFF111827), size: 22),
                      ),
                      Positioned(
                          top: 7,
                          right: 7,
                          child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 1.5)))),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            /// SUBHEADING
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text('Where do you want to live?',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280))),
            ),

            const SizedBox(height: 20),

            /// SEARCH BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF3F4F6))),
                child: Row(
                  children: [
                    Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: SvgPicture.string(searchSvg,
                            width: 24,
                            height: 24,
                            color: const Color(0xFF9CA3AF))),
                    Expanded(
                      child: TextField(
                        onChanged: (value) => setState(() => query = value),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827)),
                        decoration: const InputDecoration(
                          hintText: 'Kilifi, Kenya',
                          hintStyle:
                              TextStyle(color: Color(0xFF9CA3AF), fontSize: 16),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 17),
                        ),
                      ),
                    ),
                    if (query.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Material(
                          color: const Color(0xFFF3F4F6),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => setState(() => query = ''),
                            child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: SvgPicture.string(xCircleSvg,
                                    width: 22,
                                    height: 22,
                                    color: const Color(0xFF9CA3AF))),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            /// FILTERS & SORT
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.onOpenFilters,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.string(filterSvg,
                                width: 22,
                                height: 22,
                                color: const Color(0xFF111827)),
                            const SizedBox(width: 8),
                            const Text('Filters',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Color(0xFF111827))),
                          ]),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _showSortOptions,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.string(sortSvg,
                                width: 22,
                                height: 22,
                                color: const Color(0xFF111827)),
                            const SizedBox(width: 8),
                            const Text('Sort',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Color(0xFF111827))),
                          ]),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// RESULTS
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 20),
                      itemBuilder: (context, index) {
                        final property = results[index];
                        final isSaved = AppSession.isSaved(property.id);
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 400 + (index * 60)),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Transform.translate(
                                offset: Offset(0, 30 * (1 - value)),
                                child: Opacity(opacity: value, child: child));
                          },
                          child: GestureDetector(
                            onTap: () =>
                                widget.onSelectProperty?.call(property.id),
                            child: Container(
                              height: 138,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6))
                                ],
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: buildPropertyImage(property.image,
                                        width: 118,
                                        height: 138,
                                        fit: BoxFit.cover),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 14, 16, 14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                  child: Text(property.name,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 16.5,
                                                          color: Color(
                                                              0xFF111827)),
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis)),
                                              GestureDetector(
                                                onTap: () {
                                                  _toggleSave(property.id).then(
                                                      (_) => setState(() {}));
                                                },
                                                child: Icon(
                                                  isSaved
                                                      ? AppIcons.heart
                                                      : AppIcons.heartOutline,
                                                  size: 24,
                                                  color: isSaved
                                                      ? const Color(0xFFEC4899)
                                                      : const Color(0xFFD1D5DB),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(AppIcons.location,
                                                  size: 14,
                                                  color: Color(0xFF9CA3AF)),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                  child: Text(property.location,
                                                      style: const TextStyle(
                                                          fontSize: 13,
                                                          color:
                                                              Color(0xFF9CA3AF),
                                                          fontWeight:
                                                              FontWeight.w500),
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                              'Kes. ${property.price ~/ 1000}k/month',
                                              style: const TextStyle(
                                                  fontSize: 16.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF111827))),
                                          const Spacer(),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFFFF7ED),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                        Icons.star_rounded,
                                                        size: 15,
                                                        color:
                                                            Color(0xFFF59E42)),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                        property.rating
                                                            .toStringAsFixed(1),
                                                        style: const TextStyle(
                                                            fontSize: 13.5,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Color(
                                                                0xFFFB923C))),
                                                  ],
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                  '${property.features.beds} Beds',
                                                  style: const TextStyle(
                                                      fontSize: 13.5,
                                                      color: Color(0xFF9CA3AF),
                                                      fontWeight:
                                                          FontWeight.w500)),
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
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
