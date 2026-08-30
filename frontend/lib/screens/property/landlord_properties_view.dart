import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';

import 'package:property_app/models/property.dart';
import 'package:property_app/services/property_service.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/services/analytics/analytics_service.dart';

// ─── Landlord Design System Constants ─────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981); // Emerald Green

class LandlordPropertiesView extends StatefulWidget {
  final VoidCallback onAddProperty;

  const LandlordPropertiesView({super.key, required this.onAddProperty});

  @override
  State<LandlordPropertiesView> createState() => _LandlordPropertiesViewState();
}

class _LandlordPropertiesViewState extends State<LandlordPropertiesView>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  final _propertyService = PropertyService.instance;
  List<Property> _properties = [];
  bool _loading = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.0).animate(
        CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    _entryController.forward();
    _loadProperties();
  }

  List<String> get _categoryTabs {
    final categories = _properties.map((p) => p.category).toSet().toList();
    categories.sort();
    return ['All', ...categories];
  }

  List<Property> get _visibleProperties {
    List<Property> filtered = _properties;
    
    if (_selectedCategory != 'All') {
      filtered = filtered.where((p) => p.category == _selectedCategory).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) => 
        p.name.toLowerCase().contains(_searchQuery) || 
        p.location.toLowerCase().contains(_searchQuery)
      ).toList();
    }
    
    return filtered;
  }

  Future<void> _loadProperties() async {
    final loaded = await _propertyService.fetchProperties();
    if (!mounted) return;
    setState(() {
      _properties = loaded.cast<Property>();
      _loading = false;
    });
  }

  String _getCategoryAsset(String category) {
    final c = category.toLowerCase();
    if (c == 'all') return 'assets/images/all.webp';
    if (c.contains('apartment')) return 'assets/images/apartments.webp';
    if (c.contains('bedsitter')) return 'assets/images/bedsitter.webp';
    if (c.contains('single')) return 'assets/images/singleroom.webp';
    if (c.contains('one bedroom') || c.contains('1 bedroom')) return 'assets/images/onebedroom.webp';
    return 'assets/images/all.webp'; // Fallback
  }

  @override
  void dispose() {
    _searchController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  // ─── UI BUILDERS ─────────────────────────────────────────────────────────────

  Widget _buildCategoryPills() {
    final tabs = _categoryTabs;
    
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: tabs.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isSelected = _selectedCategory == tab;
          final imagePath = _getCategoryAsset(tab);
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = tab;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.only(left: 6, right: 16, top: 6, bottom: 6),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelected ? _dark : _grey.withOpacity(0.2),
                  width: isSelected ? 2.0 : 1.5,
                ),
                boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))] : [],
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
                        image: AssetImage(imagePath),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tab,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? _dark : _grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Icon(PhosphorIconsRegular.magnifyingGlass, color: _dark, size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: _dark),
              decoration: InputDecoration(
                hintText: 'Search listings',
                hintStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w400, color: _grey),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                FocusScope.of(context).unfocus();
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(PhosphorIconsFill.xCircle, color: _grey, size: 20),
              ),
            ),
          Container(width: 1, height: 24, color: _grey.withOpacity(0.2)),
          GestureDetector(
            onTap: () {}, // Future filter expansion
            child: const Padding(
              padding: EdgeInsets.only(right: 16, left: 14),
              child: Icon(PhosphorIconsRegular.faders, size: 22, color: _dark),
            ),
          ),
        ],
      ),
    );
  }

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
          (context, index) {
            return Column(
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
            );
          },
          childCount: 6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: SafeArea(
                bottom: false,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ─── Header ───
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
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _surface,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Icon(PhosphorIconsRegular.bell, color: _dark, size: 22),
                                  Positioned(
                                    top: 10,
                                    right: 12,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ─── Category Pills ───
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildCategoryPills(),
                      ),
                    ),

                    // ─── Search Bar ───
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: _buildSearchBar(),
                      ),
                    ),

                    // ─── Grid Content ───
                    if (_loading)
                      _buildShimmerGrid()
                    else if (_visibleProperties.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 64),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(PhosphorIconsRegular.houseLine, size: 64, color: _grey),
                                const SizedBox(height: 16),
                                Text('No properties found', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
                                const SizedBox(height: 8),
                                Text('Try adjusting your search or filters.', style: GoogleFonts.poppins(color: _grey)),
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
                            mainAxisExtent: 268,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final property = _visibleProperties[index];
                              return _PropertyCard(
                                property: property,
                                delay: Duration(milliseconds: 60 * index),
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

          // ─── Floating Action Button ───
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 32, // Safely above bottom nav
            left: 24,
            right: 24,
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onAddProperty,
                icon: const Icon(PhosphorIconsRegular.plus, size: 20, color: Colors.white),
                label: Text(
                  'Add New Property',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _dark, // Premium dark high-contrast FAB
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: Colors.black.withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Square Grid Property Card ────────────────────────────────────────────────

class _PropertyCard extends StatefulWidget {
  final Property property;
  final Duration delay;

  const _PropertyCard({required this.property, required this.delay});

  @override
  State<_PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<_PropertyCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));

    Future.delayed(widget.delay, () {
      if (mounted) {
        AnalyticsService.logListingInteraction('property_impression', listingId: widget.property.id);
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

  @override
  Widget build(BuildContext context) {
    // Generate dummy visual data if missing from model
    final isDraft = widget.property.name.toLowerCase().contains('single room'); // Placeholder logic
    final statusText = isDraft ? 'Draft' : 'Published';
    final statusBgColor = isDraft ? _grey.withOpacity(0.15) : _green.withOpacity(0.15);
    final statusTextColor = isDraft ? _dark : _green;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTap: () {
            AnalyticsService.logListingInteraction('property_click', listingId: widget.property.id);
            Navigator.pushNamed(context, '/booking', arguments: <String, String>{'propertyId': widget.property.id});
          },
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
                        widget.property.image,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorPlaceholder: Container(color: _grey.withOpacity(0.1), child: const Icon(PhosphorIconsRegular.house, color: _grey, size: 32)),
                      ),
                    ),
                  ),
                  // Floating Status Badge inside image
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDraft ? Colors.white.withOpacity(0.9) : _green,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                      ),
                      child: Text(
                        statusText,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDraft ? _dark : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // 2. Details Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  Row(
                    children: [
                      const Icon(PhosphorIconsFill.eye, size: 12, color: _grey),
                      const SizedBox(width: 4),
                      Text(
                        '1.2k', // Mock data from original
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _grey),
                      ),
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
              const SizedBox(height: 2),
              Text(
                '${widget.property.features.beds} Beds • ${widget.property.category}',
                style: GoogleFonts.poppins(fontSize: 12, color: _grey),
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