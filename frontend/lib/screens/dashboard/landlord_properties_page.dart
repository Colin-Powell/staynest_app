import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:property_app/models/property.dart';
import 'package:property_app/services/properties_api.dart';
import 'package:property_app/utils/property_mapper.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/services/analytics/analytics_service.dart';
import 'landlord_dashboard_service.dart';

// ─── Landlord Design System Constants ─────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981); // Emerald Green for Landlord Theme

class LandlordPropertiesPage extends StatefulWidget {
  final VoidCallback onAddProperty;

  const LandlordPropertiesPage({super.key, required this.onAddProperty});

  @override
  State<LandlordPropertiesPage> createState() => _LandlordPropertiesPageState();
}

class _LandlordPropertiesPageState extends State<LandlordPropertiesPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  List<Property> _properties = [];
  bool _loading = true;
  bool _hasError = false;

  // Search & Filter State
  String _selectedCategory = 'All';
  String _selectedSort = 'Newest';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _sortOptions = [
    'Newest',
    'Price: Low to High',
    'Price: High to Low'
  ];

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.0).animate(
        CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
    _entryController.forward();
    _loadProperties();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProperties() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final rawList = await PropertiesApi.getLandlordProperties();
      if (!mounted) return;
      setState(() {
        _properties = rawList.map((m) => mapApiProperty(m)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
        });
      }
    }
  }

  // --- Helpers for Filtering, Sorting, and Icons ---

  List<String> get _categoryTabs {
    final defaultTabs = ['All', 'Apartment', 'Single Room', 'One Bedroom', 'Bedsitter'];
    final dynamicTabs = _properties
        .map((p) => p.category)
        .where((c) => !defaultTabs.contains(c) && c.trim().isNotEmpty)
        .toSet()
        .toList();

    dynamicTabs.sort();
    return [...defaultTabs, ...dynamicTabs];
  }

  String _getAssetForCategory(String category) {
    final lower = category.toLowerCase().trim();
    if (lower.contains('apartment')) return 'assets/images/apartments.webp';
    if (lower.contains('bedsitter') || lower.contains('studio')) return 'assets/images/bedsitter.webp';
    if (lower.contains('single room')) return 'assets/images/singleroom.webp';
    if (lower.contains('one bedroom') || lower.contains('1 bedroom')) return 'assets/images/onebedroom.webp';
    return 'assets/images/all.webp'; // Fallback
  }

  List<Property> get _visibleProperties {
    List<Property> filtered = _properties.toList();

    // 1. Filter by Category
    if (_selectedCategory != 'All') {
      filtered = filtered.where((p) => p.category == _selectedCategory).toList();
    }

    // 2. Filter by Search Query
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.location.toLowerCase().contains(query);
      }).toList();
    }

    // 3. Sort Results
    if (_selectedSort == 'Price: Low to High') {
      filtered.sort((a, b) => a.price.compareTo(b.price));
    } else if (_selectedSort == 'Price: High to Low') {
      filtered.sort((a, b) => b.price.compareTo(a.price));
    }

    return filtered;
  }

  // ─── UI BUILDERS ────────────────────────────────────────────────────────────

  Widget _buildShimmerGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 24,
          mainAxisExtent: 268,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
                ),
              ),
              const SizedBox(height: 12),
              Shimmer.fromColors(
                baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
                child: Container(height: 14, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
              ),
              const SizedBox(height: 8),
              Shimmer.fromColors(
                baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
                child: Container(height: 12, width: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
              ),
            ],
          ),
          childCount: 6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg, // Solid clean background
      body: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: RefreshIndicator(
              color: _green,
              backgroundColor: _surface,
              onRefresh: _loadProperties,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  // ─── HEADER ───
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'My Properties',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: _dark,
                              letterSpacing: -0.5,
                            ),
                          ),
                          GestureDetector(
                            onTap: widget.onAddProperty,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _green,
                                boxShadow: [
                                  BoxShadow(
                                    color: _green.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: const Icon(PhosphorIconsRegular.plus, color: Colors.white, size: 24),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ─── CATEGORY PILLS (HomeView Style) ───
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                      child: SizedBox(
                        height: 52,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _categoryTabs.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final tab = _categoryTabs[index];
                            final isSelected = _selectedCategory == tab;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedCategory = tab),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.only(left: 6, right: 16, top: 6, bottom: 6),
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: isSelected ? _green : _grey.withOpacity(0.2),
                                    width: isSelected ? 2.0 : 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        image: DecorationImage(
                                          image: AssetImage(_getAssetForCategory(tab)),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      tab,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? _green : _dark,
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
                  ),

                  // ─── SEARCH & SORT ───
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 52,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(26), // Pill shape
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: Row(
                                children: [
                                  const Icon(PhosphorIconsRegular.magnifyingGlass, color: _dark, size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: (value) => setState(() => _searchQuery = value),
                                      style: GoogleFonts.poppins(fontSize: 14, color: _dark, fontWeight: FontWeight.w500),
                                      decoration: InputDecoration(
                                        hintText: 'Search properties',
                                        hintStyle: GoogleFonts.poppins(fontSize: 14, color: _grey, fontWeight: FontWeight.w400),
                                        filled: false,
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                  if (_searchQuery.isNotEmpty)
                                    GestureDetector(
                                      onTap: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                        FocusScope.of(context).unfocus();
                                      },
                                      child: const Icon(PhosphorIconsFill.xCircle, size: 20, color: _grey),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Sort Button
                          Container(
                            height: 52,
                            width: 52,
                            decoration: BoxDecoration(
                              color: _surface,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: PopupMenuButton<String>(
                              icon: const Icon(PhosphorIconsRegular.sortDescending, size: 22, color: _dark),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              color: _surface,
                              elevation: 4,
                              onSelected: (newValue) => setState(() => _selectedSort = newValue),
                              itemBuilder: (context) {
                                return _sortOptions.map((value) {
                                  final isSelected = _selectedSort == value;
                                  return PopupMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      value,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? _green : _dark,
                                      ),
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ─── GRID LIST ───
                  if (_loading)
                    _buildShimmerGrid()
                  else if (_hasError)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(PhosphorIconsRegular.warningCircle, color: Colors.redAccent, size: 48),
                              const SizedBox(height: 16),
                              Text('Failed to load properties.', style: GoogleFonts.poppins(color: _dark, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 10),
                              TextButton(onPressed: _loadProperties, child: Text('Retry', style: GoogleFonts.poppins(color: _green, fontWeight: FontWeight.w600))),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (_visibleProperties.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(color: _grey.withOpacity(0.1), shape: BoxShape.circle),
                                child: const Icon(PhosphorIconsRegular.houseLine, color: _grey, size: 48),
                              ),
                              const SizedBox(height: 16),
                              Text('No properties found.', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: _dark)),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 120),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 24,
                          mainAxisExtent: 290, // Taller extent to comfortably fit image + details
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return _PropertyGridCard(
                              property: _visibleProperties[index],
                              delay: Duration(milliseconds: 80 * index),
                            );
                          },
                          childCount: _visibleProperties.length,
                        ),
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

// ─── Square Grid Property Card ────────────────────────────────────────────────

class _PropertyGridCard extends StatefulWidget {
  final Property property;
  final Duration delay;

  const _PropertyGridCard({required this.property, required this.delay});

  @override
  State<_PropertyGridCard> createState() => _PropertyGridCardState();
}

class _PropertyGridCardState extends State<_PropertyGridCard> with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  String _viewsCount = '0';
  String _savesCount = '0';

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));

    _loadMetrics();

    Future.delayed(widget.delay, () {
      if (mounted) {
        AnalyticsService.logListingInteraction(AnalyticsEvents.listingImpression, listingId: widget.property.id);
        _entryController.forward();
      }
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  String _formatPriceToK(num price) {
    final value = price.toDouble();
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toStringAsFixed(0);
  }

  String _formatCount(dynamic countRaw) {
    if (countRaw == null) return '0';
    final int value = countRaw is int ? countRaw : int.tryParse(countRaw.toString()) ?? 0;
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1).replaceAll('.0', '')}k';
    return value.toString();
  }

  Future<void> _loadMetrics() async {
    try {
      final metrics = await LandlordDashboardService.getPropertyEngagementStats(widget.property.id);
      if (mounted && metrics != null && metrics.isNotEmpty) {
        setState(() {
          _viewsCount = _formatCount(metrics['stats']?['views'] ?? metrics['stats']?['totalViews'] ?? 0);
          _savesCount = _formatCount(metrics['stats']?['saves'] ?? metrics['stats']?['totalSaves'] ?? 0);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDraft = widget.property.name.toLowerCase().contains('single room'); // Adjust logic as needed
    final statusText = isDraft ? 'Draft' : 'Live';
    final statusBgColor = isDraft ? const Color(0xFFF3F4F6) : const Color(0xFFD1FAE5);
    final statusTextColor = isDraft ? const Color(0xFF4B5563) : const Color(0xFF065F46);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTap: () {
            AnalyticsService.logListingInteraction('property_click', listingId: widget.property.id);
            Navigator.pushNamed(context, '/landlord_property_management', arguments: <String, dynamic>{
              'id': widget.property.id,
              'title': widget.property.name,
              'image': widget.property.image,
              'location': widget.property.location,
            });
          },
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Square Image Box ───
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: buildPropertyImage(
                        widget.property.image,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorPlaceholder: Container(
                          color: _grey.withOpacity(0.1),
                          child: const Icon(PhosphorIconsRegular.house, color: _grey, size: 40),
                        ),
                      ),
                    ),
                  ),
                  // Floating Status Badge inside the image
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBgColor.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        statusText,
                        style: GoogleFonts.poppins(
                          fontSize: 10.0,
                          fontWeight: FontWeight.w800,
                          color: statusTextColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ─── Details Section ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.property.location,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Compact Views/Saves Row
                  Row(
                    children: [
                      const Icon(PhosphorIconsRegular.eye, size: 14, color: _grey),
                      const SizedBox(width: 2),
                      Text(_viewsCount, style: GoogleFonts.poppins(fontSize: 12, color: _grey, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      const Icon(PhosphorIconsFill.heart, size: 14, color: Color(0xFFEC4899)), // Pink Heart
                      const SizedBox(width: 2),
                      Text(_savesCount, style: GoogleFonts.poppins(fontSize: 12, color: _grey, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                widget.property.name,
                style: GoogleFonts.poppins(fontSize: 12, color: _grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'Ksh. ${_formatPriceToK(widget.property.price)}',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    ' /mo',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _grey,
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
}