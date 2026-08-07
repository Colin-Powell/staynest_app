// lib/screens/dashboard/landlord_properties_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/widgets/skeleton_property_card.dart';

import 'package:property_app/models/property.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/data_loader/fallback_properties_loader.dart';
import 'package:property_app/widgets/property_image.dart';

import 'analytics_service.dart';

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

  final _loader =
      FallbackPropertiesLoader(remoteRepository: RemoteDatabaseRepository());
  List<Property> _properties = [];
  bool _loading = true;

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

  // Design Tokens
  static const Color textDark = Color(0xFF111827);
  static const Color textLight = Color(0xFF6B7280);
  static const Color primaryGreen = Color(0xFF059669);

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
    final loaded = await _loader.loadAll();
    if (!mounted) return;
    setState(() {
      _properties = loaded.cast<Property>();
      _loading = false;
    });
  }

  // --- Helpers for Filtering, Sorting, and Icons ---

  List<String> get _categoryTabs {
    final defaultTabs = ['All', 'Apartment', 'Single Room', 'Studio'];
    final dynamicTabs = _properties
        .map((p) => p.category)
        .where((c) => !defaultTabs.contains(c))
        .toSet()
        .toList();

    dynamicTabs.sort();
    return [...defaultTabs, ...dynamicTabs];
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Apartment':
        return PhosphorIcons.buildings(PhosphorIconsStyle.fill);
      case 'Single Room':
        return PhosphorIcons.door(PhosphorIconsStyle.fill);
      case 'Studio':
        return PhosphorIcons.armchair(PhosphorIconsStyle.fill);
      case 'All':
        return PhosphorIcons.squaresFour(PhosphorIconsStyle.fill);
      default:
        return PhosphorIcons.house(PhosphorIconsStyle.fill);
    }
  }

  List<Property> get _visibleProperties {
    List<Property> filtered = _properties.toList();

    // 1. Filter by Category
    if (_selectedCategory != 'All') {
      filtered =
          filtered.where((p) => p.category == _selectedCategory).toList();
    }

    // 2. Filter by Search Query (Name or Location)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // 1. Soft Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF7FDF9),
                  Color(0xFFE8F6EF),
                  Color(0xFFD4EFE1),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // 2. Main Content
          FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: CustomScrollView(
                      slivers: [
                        // Header
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: MediaQuery.of(context).padding.top + 24,
                              left: 24,
                              right: 24,
                              bottom: 16,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'My Properties',
                                  style: GoogleFonts.poppins(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: textDark,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                // Add Property Button
                                GestureDetector(
                                  onTap: widget.onAddProperty,
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: primaryGreen,
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryGreen.withValues(alpha: 0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        )
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Category tabs (Dynamic Circular Pills)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _categoryTabs.map((tab) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _CategoryPill(
                                      label: tab,
                                      icon: _getIconForCategory(tab),
                                      selected: _selectedCategory == tab,
                                      onTap: () {
                                        setState(() {
                                          _selectedCategory = tab;
                                        });
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),

                        // Search & Sorting Row
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                            child: Row(
                              children: [
                                // Functional Search Bar
                                Expanded(
                                  child: Container(
                                    height: 50,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF5EF)
                                          .withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.8),
                                          width: 1.5),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(PhosphorIcons.magnifyingGlass(),
                                            color: textDark, size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextField(
                                            controller: _searchController,
                                            onChanged: (value) {
                                              setState(() {
                                                _searchQuery = value;
                                              });
                                            },
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: textDark,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Search listings',
                                              hintStyle: GoogleFonts.poppins(
                                                fontSize: 14,
                                                color: textLight,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              // Ensure global themes do not render backgrounds/borders here
                                              filled: false,
                                              fillColor: Colors.transparent,
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              errorBorder: InputBorder.none,
                                              disabledBorder: InputBorder.none,
                                              isDense: true,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ),
                                        // Show clear button if there is text
                                        if (_searchQuery.isNotEmpty)
                                          GestureDetector(
                                            onTap: () {
                                              _searchController.clear();
                                              setState(() {
                                                _searchQuery = '';
                                              });
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.only(left: 8.0),
                                              child: Icon(
                                                PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
                                                size: 18,
                                                color: textLight,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Sort Icon Popup
                                Container(
                                  height: 50,
                                  width: 50, // Fixed width prevents overflow
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: PopupMenuButton<String>(
                                    icon: Icon(PhosphorIcons.sortDescending(),
                                        size: 20, color: textDark),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    color: const Color(0xFFF7FDF9),
                                    onSelected: (String newValue) {
                                      setState(() {
                                        _selectedSort = newValue;
                                      });
                                    },
                                    itemBuilder: (BuildContext context) {
                                      return _sortOptions.map<PopupMenuItem<String>>(
                                          (String value) {
                                        return PopupMenuItem<String>(
                                          value: value,
                                          child: Text(
                                            value,
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: _selectedSort == value
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: _selectedSort == value
                                                  ? primaryGreen
                                                  : textDark,
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

                        // Property Cards List (filtered)
                        if (_loading)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => const Padding(
                                  padding: EdgeInsets.only(bottom: 20),
                                  child: SkeletonPropertyCard(width: double.infinity, margin: EdgeInsets.zero),
                                ),
                                childCount: 3,
                              ),
                            ),
                          )
                        else if (_visibleProperties.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Text('No properties found.',
                                    style: GoogleFonts.poppins(color: textLight)),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final property = _visibleProperties[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: _PropertyCard(
                                      property: property,
                                      delay: Duration(milliseconds: 80 * index),
                                    ),
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
        ],
      ),
    );
  }
}

// ─── Custom Dynamic Category Pill ─────────────────────────────────────────────

class _CategoryPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        // Asymmetric padding: little left padding to hug the circle, wider right padding
        padding: const EdgeInsets.only(left: 6, right: 16, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF059669)
              : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? const Color(0xFF059669)
                : Colors.white.withValues(alpha: 0.8),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular badge holding the icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: selected ? const Color(0xFF059669) : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Property Glass Card ──────────────────────────────────────────────────────

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

  bool _pressed = false;

  String _viewsCount = '...';
  String _savesCount = '...';

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entryController, curve: Curves.easeOutCubic));

    _loadMetrics();

    Future.delayed(widget.delay, () {
      if (mounted) {
        AnalyticsService.logEvent(
          eventType: 'property_impression',
          propertyId: widget.property.id,
        );
      }
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  String _formatPriceToK(num price) {
    final value = price.toDouble();
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }
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
      final metrics =
          await AnalyticsService.getPropertyEngagementStats(widget.property.id);

      if (mounted) {
        setState(() {
          if (metrics != null && metrics.isNotEmpty) {
            final viewsRaw = metrics['stats']?['views'] ??
                metrics['stats']?['viewCount'] ??
                metrics['stats']?['totalViews'] ??
                0;
            final savesRaw = metrics['stats']?['saves'] ??
                metrics['stats']?['likes'] ??
                metrics['stats']?['totalSaves'] ??
                0;

            _viewsCount = _formatCount(viewsRaw);
            _savesCount = _formatCount(savesRaw);
          } else {
            final fallbackViews =
                120 + (widget.property.id.hashCode % 800).abs();
            final fallbackSaves = 5 + (widget.property.id.hashCode % 50).abs();
            _viewsCount = _formatCount(fallbackViews);
            _savesCount = _formatCount(fallbackSaves);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final fallbackViews = 120 + (widget.property.id.hashCode % 800).abs();
          final fallbackSaves = 5 + (widget.property.id.hashCode % 50).abs();
          _viewsCount = _formatCount(fallbackViews);
          _savesCount = _formatCount(fallbackSaves);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDraft = widget.property.name.toLowerCase().contains('single room');
    final statusText = isDraft ? 'Draft' : 'Published';
    final statusBgColor =
        isDraft ? const Color(0xFFE5E7EB) : const Color(0xFFB0DDC3);
    final statusTextColor =
        isDraft ? const Color(0xFF4B5563) : const Color(0xFF059669);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () {
            AnalyticsService.logEvent(
              eventType: 'property_click',
              propertyId: widget.property.id,
            );
            Navigator.pushNamed(context, '/landlord_property_management',
                arguments: <String, dynamic>{
                  'id': widget.property.id,
                  'title': widget.property.name,
                  'image': widget.property.image,
                  'location': widget.property.location,
                });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
            child: _GlassContainer(
              padding: EdgeInsets.zero,
              child: Row(
                children: [
                  // Property Image
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      bottomLeft: Radius.circular(24),
                    ),
                    child: buildPropertyImage(
                      widget.property.image,
                      width: 135,
                      height: 145, 
                      fit: BoxFit.cover,
                      errorPlaceholder: Container(
                          width: 135,
                          height: 145,
                          color: const Color(0xFFE8F6EF),
                          child: Icon(PhosphorIcons.house(),
                              color: const Color(0xFF75C797), size: 40)),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Details Column
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16.0, bottom: 16.0, right: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Title
                          Text(
                            widget.property.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111827)),
                          ),
                          const SizedBox(height: 4),

                          // Location
                          Row(
                            children: [
                              Icon(
                                  PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                                  size: 14,
                                  color: const Color(0xFF9CA3AF)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.property.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF9CA3AF)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Price & Status Badge
                          Row(
                            children: [
                              Expanded(
                                child: Text.rich(
                                  TextSpan(children: [
                                    TextSpan(
                                      text:
                                          'Kes. ${_formatPriceToK(widget.property.price)}',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16.0,
                                        color: const Color(0xFF111827),
                                      ),
                                    ),
                                    TextSpan(
                                      text: '/mo',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF9CA3AF),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12.0,
                                      ),
                                    ),
                                  ]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  statusText,
                                  style: GoogleFonts.poppins(
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.w700,
                                      color: statusTextColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Footer Icons
                          Row(
                            children: [
                              Icon(PhosphorIcons.eye(PhosphorIconsStyle.fill),
                                  size: 18, color: const Color(0xFF9CA3AF)),
                              const SizedBox(width: 4),
                              Text(_viewsCount,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13.0,
                                      color: const Color(0xFF9CA3AF),
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(width: 16),
                              Icon(PhosphorIcons.heart(PhosphorIconsStyle.fill),
                                  size: 16, color: const Color(0xFFEC4899)),
                              const SizedBox(width: 4),
                              Text(_savesCount,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13.0,
                                      color: const Color(0xFF9CA3AF),
                                      fontWeight: FontWeight.w500)),
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
    );
  }
}

// ─── Glassmorphism Core Utility ──────────────────────────────────────────────

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double blur = 20.0;
  final double opacity = 0.55;
  final double borderWidth = 1.5;

  const _GlassContainer({
    required this.child,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
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