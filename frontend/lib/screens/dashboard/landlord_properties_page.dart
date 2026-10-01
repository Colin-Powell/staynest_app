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
  final void Function(Map<String, dynamic>)? onOpenProperty;

  const LandlordPropertiesPage({
    super.key,
    required this.onAddProperty,
    this.onOpenProperty,
  });

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

  int get _propertyGridColumns {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1680) return 4;
    if (width >= 1100) return 3;
    return 2;
  }

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim =
        CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
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
    final defaultTabs = [
      'All',
      'Apartment',
      'Single Room',
      'One Bedroom',
      'Bedsitter'
    ];
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
    if (lower.contains('apartment')) {
      return 'assets/images/apartments.webp';
    }
    if (lower.contains('bedsitter') || lower.contains('studio')) {
      return 'assets/images/bedsitter.webp';
    }
    if (lower.contains('single room')) {
      return 'assets/images/singleroom.webp';
    }
    if (lower.contains('one bedroom') || lower.contains('1 bedroom')) {
      return 'assets/images/onebedroom.webp';
    }
    return 'assets/images/all.webp'; // Fallback
  }

  List<Property> get _visibleProperties {
    List<Property> filtered = _properties.toList();

    // 1. Filter by Category
    if (_selectedCategory != 'All') {
      filtered =
          filtered.where((p) => p.category == _selectedCategory).toList();
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
    final isDesktop = MediaQuery.sizeOf(context).width >= 1100;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 32 : 24,
        0,
        isDesktop ? 32 : 24,
        MediaQuery.of(context).padding.bottom + (isDesktop ? 32 : 120),
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _propertyGridColumns,
          crossAxisSpacing: isDesktop ? 24 : 16,
          mainAxisSpacing: isDesktop ? 32 : 24,
          childAspectRatio:
              isDesktop ? 0.85 : 0.75, // Prevents overflow fluidly
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Shimmer.fromColors(
                  baseColor: Colors.grey.shade200,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16))),
                ),
              ),
              const SizedBox(height: 16),
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
          ),
          childCount: 6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1100;

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
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  // ─── HEADER ───
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(isDesktop ? 32 : 24,
                          isDesktop ? 32 : 16, isDesktop ? 32 : 24, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'My Properties',
                            style: GoogleFonts.poppins(
                              fontSize: isDesktop ? 32 : 28,
                              fontWeight: FontWeight.w700,
                              color: _dark,
                              letterSpacing: -0.5,
                            ),
                          ),
                          isDesktop
                              ? FilledButton.icon(
                                  onPressed: widget.onAddProperty,
                                  icon: const Icon(PhosphorIconsRegular.plus,
                                      size: 18),
                                  label: Text('Add Property',
                                      style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _green,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 18),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(30)),
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                  ),
                                )
                              : GestureDetector(
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
                                    child: const Icon(PhosphorIconsRegular.plus,
                                        color: Colors.white, size: 24),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),

                  // ─── CATEGORY PILLS (Soft Design System) ───
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                      child: SizedBox(
                        height: 52,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 32 : 24),
                          itemCount: _categoryTabs.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final tab = _categoryTabs[index];
                            final isSelected = _selectedCategory == tab;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedCategory = tab),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.only(
                                    left: 6, right: 16, top: 6, bottom: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _green.withOpacity(0.12)
                                      : _surface,
                                  borderRadius:
                                      BorderRadius.circular(30), // Pill Shape
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.transparent
                                        : _grey.withOpacity(0.2),
                                    width: 1.5,
                                  ),
                                  boxShadow: isSelected || !isDesktop
                                      ? []
                                      : [
                                          BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.02),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4))
                                        ],
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
                                          image: AssetImage(
                                              _getAssetForCategory(tab)),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      tab,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
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
                      padding: EdgeInsets.fromLTRB(
                          isDesktop ? 32 : 24, 24, isDesktop ? 32 : 24, 32),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 52,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(
                                    30), // Soft pill shape
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: isDesktop ? 24 : 10,
                                    offset: Offset(0, isDesktop ? 8 : 4),
                                  )
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                      PhosphorIconsRegular.magnifyingGlass,
                                      color: _grey,
                                      size: 22),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: (value) =>
                                          setState(() => _searchQuery = value),
                                      style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: _dark,
                                          fontWeight: FontWeight.w500),
                                      decoration: InputDecoration(
                                        hintText: 'Search properties',
                                        hintStyle: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: _grey,
                                            fontWeight: FontWeight.w400),
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
                                      child: const Icon(
                                          PhosphorIconsFill.xCircle,
                                          size: 20,
                                          color: _grey),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Sort Button
                          Container(
                            height: 52,
                            width: 52,
                            decoration: BoxDecoration(
                              color: _surface,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: isDesktop ? 24 : 10,
                                    offset: Offset(0, isDesktop ? 8 : 4))
                              ],
                            ),
                            child: PopupMenuButton<String>(
                              icon: const Icon(
                                  PhosphorIconsRegular.sortDescending,
                                  size: 22,
                                  color: _dark),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              color: _surface,
                              elevation: 4,
                              onSelected: (newValue) =>
                                  setState(() => _selectedSort = newValue),
                              itemBuilder: (context) {
                                return _sortOptions.map((value) {
                                  final isSelected = _selectedSort == value;
                                  return PopupMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      value,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
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
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFEF2F2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                    PhosphorIconsRegular.warningCircle,
                                    color: Color(0xFFB42318),
                                    size: 32),
                              ),
                              const SizedBox(height: 16),
                              Text('Failed to load properties.',
                                  style: GoogleFonts.poppins(
                                      color: _dark,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 10),
                              TextButton(
                                  onPressed: _loadProperties,
                                  style: TextButton.styleFrom(
                                    foregroundColor: _green,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(30)),
                                  ),
                                  child: Text('Retry',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600))),
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
                                decoration: BoxDecoration(
                                    color: _grey.withOpacity(0.1),
                                    shape: BoxShape.circle),
                                child: const Icon(
                                    PhosphorIconsRegular.houseLine,
                                    color: _grey,
                                    size: 48),
                              ),
                              const SizedBox(height: 16),
                              Text('No properties found.',
                                  style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _dark)),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 32 : 24,
                        0,
                        isDesktop ? 32 : 24,
                        MediaQuery.of(context).padding.bottom +
                            (isDesktop ? 32 : 120),
                      ),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _propertyGridColumns,
                          crossAxisSpacing: isDesktop ? 24 : 16,
                          mainAxisSpacing: isDesktop ? 32 : 24,
                          childAspectRatio: isDesktop
                              ? 0.85
                              : 0.75, // Fully fluid height constraint
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return _PropertyGridCard(
                              property: _visibleProperties[index],
                              delay: Duration(milliseconds: 80 * index),
                              onOpenProperty: widget.onOpenProperty,
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

// ─── Dynamic Responsive Property Card ─────────────────────────────────────────

class _PropertyGridCard extends StatefulWidget {
  final Property property;
  final Duration delay;
  final void Function(Map<String, dynamic>)? onOpenProperty;

  const _PropertyGridCard({
    required this.property,
    required this.delay,
    this.onOpenProperty,
  });

  @override
  State<_PropertyGridCard> createState() => _PropertyGridCardState();
}

class _PropertyGridCardState extends State<_PropertyGridCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  String _viewsCount = '0';
  String _savesCount = '0';

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim =
        CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entryController, curve: Curves.easeOutCubic));

    _loadMetrics();

    Future.delayed(widget.delay, () {
      if (mounted) {
        AnalyticsService.logListingInteraction(
            AnalyticsEvents.listingImpression,
            listingId: widget.property.id);
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
    final int value =
        countRaw is int ? countRaw : int.tryParse(countRaw.toString()) ?? 0;
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1).replaceAll('.0', '')}k';
    }
    return value.toString();
  }

  Future<void> _loadMetrics() async {
    try {
      final metrics = await LandlordDashboardService.getPropertyEngagementStats(
          widget.property.id);
      if (mounted && metrics != null && metrics.isNotEmpty) {
        setState(() {
          _viewsCount = _formatCount(metrics['stats']?['views'] ??
              metrics['stats']?['totalViews'] ??
              0);
          _savesCount = _formatCount(metrics['stats']?['saves'] ??
              metrics['stats']?['totalSaves'] ??
              0);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDraft = widget.property.name
        .toLowerCase()
        .contains('single room'); // Adjust logic as needed
    final statusText = isDraft ? 'Draft' : 'Live';
    final statusBgColor =
        isDraft ? const Color(0xFFF3F4F6) : const Color(0xFFD1FAE5);
    final statusTextColor =
        isDraft ? const Color(0xFF4B5563) : const Color(0xFF065F46);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTap: () {
            AnalyticsService.logListingInteraction('property_click',
                listingId: widget.property.id);
            final propertyPayload = <String, dynamic>{
              'id': widget.property.id,
              'title': widget.property.name,
              'image': widget.property.image,
              'location': widget.property.location,
            };
            if (widget.onOpenProperty != null) {
              widget.onOpenProperty!(propertyPayload);
              return;
            }

            Navigator.pushNamed(context, '/landlord_property_management',
                arguments: propertyPayload);
          },
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Flexible Image Box to Prevent Pixel Overflow ───
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: buildPropertyImage(
                        widget.property.image,
                        fit: BoxFit.cover,
                        errorPlaceholder: Container(
                          color: _grey.withOpacity(0.1),
                          child: const Icon(PhosphorIconsRegular.house,
                              color: _grey, size: 40),
                        ),
                      ),
                    ),
                    // Floating Status Badge inside the image
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: statusBgColor.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]),
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
              ),
              const SizedBox(height: 16),

              // ─── Details Section ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.property.location,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
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
                      const Icon(PhosphorIconsRegular.eye,
                          size: 16, color: _grey),
                      const SizedBox(width: 4),
                      Text(_viewsCount,
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: _grey,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      const Icon(PhosphorIconsFill.heart,
                          size: 16, color: Color(0xFFEC4899)), // Pink Heart
                      const SizedBox(width: 4),
                      Text(_savesCount,
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: _grey,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.property.name,
                style: GoogleFonts.poppins(fontSize: 13, color: _grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'Ksh. ${_formatPriceToK(widget.property.price)}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
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
