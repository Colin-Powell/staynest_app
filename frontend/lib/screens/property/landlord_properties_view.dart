import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:property_app/models/property.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/data_loader/fallback_properties_loader.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/services/analytics_service.dart';
import 'package:property_app/widgets/shared.dart';

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

  final _loader =
      FallbackPropertiesLoader(remoteRepository: RemoteDatabaseRepository());
  List<Property> _properties = [];
  bool _loading = true;
  String _selectedCategory = 'All';

  // Design Tokens
  static const Color textDark = Color(0xFF111827);
  static const Color textLight = Color(0xFF6B7280);
  static const Color primaryGreen = Color(0xFF75C797); // Floating button base

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

  List<String> get _categoryTabs {
    final categories = _properties.map((p) => p.category).toSet().toList();
    categories.sort();
    return ['All', ...categories];
  }

  List<Property> get _visibleProperties {
    if (_selectedCategory == 'All') return _properties;
    return _properties.where((p) => p.category == _selectedCategory).toList();
  }

  Future<void> _loadProperties() async {
    final loaded = await _loader.loadAll();
    if (!mounted) return;
    setState(() {
      _properties = loaded;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
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
                  Color(0xFFF7FDF9), // Very light mint
                  Color(0xFFE8F6EF), // Soft mint green
                  Color(0xFFD4EFE1), // Deeper mint base
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
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: primaryGreen))
                  : CustomScrollView(
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
                                // Notification Bell (Glass Circle)
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.05),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Icon(
                                          PhosphorIcons.bell(
                                              PhosphorIconsStyle.fill),
                                          color: textDark,
                                          size: 24),
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEF4444),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: const Color(0xFFE8F6EF),
                                                width: 2),
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Category tabs (PropertyPill)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _categoryTabs.map((tab) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: PropertyPill(
                                      label: tab,
                                      icon: PhosphorIcons.house(
                                          PhosphorIconsStyle.fill),
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

                        // Search & Filters Row
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                            child: Row(
                              children: [
                                // Search Bar
                                Expanded(
                                  child: Container(
                                    height: 50,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF5EF).withValues(
                                          alpha: 0.6), // Translucent mint
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
                                        Text(
                                          'Search listings',
                                          style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: textLight,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Filter Button
                                Row(
                                  children: [
                                    Icon(PhosphorIcons.faders(),
                                        color: textDark, size: 24),
                                    const SizedBox(width: 8),
                                    Text('Filters',
                                        style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: textDark)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Property Cards List (filtered)
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

          // 3. Floating Glass Add Button
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40, left: 32, right: 32),
              child: _GlassFloatingButton(onPressed: widget.onAddProperty),
            ),
          ),
        ],
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
    
    Future.delayed(widget.delay, () {
      if (mounted) {
        // Track Property Impression
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

  // Visual helper to format exactly like "Kes. 12k/month"
  String _formatPriceToK(num price) {
    final value = price.toDouble();
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    // Generate dummy visual data to match PDF if missing from model
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
            // Track Property Click
            AnalyticsService.logEvent(
              eventType: 'property_click',
              propertyId: widget.property.id,
            );
            // Open property details / booking view
            Navigator.pushNamed(context, '/booking',
               arguments: <String, String>{'propertyId': widget.property.id});
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
            child: _GlassContainer(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Property Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: buildPropertyImage(
                      widget.property.image,
                      width: 130,
                      height: 130,
                      fit: BoxFit.cover,
                      errorPlaceholder: Container(
                          width: 130,
                          height: 130,
                          color: const Color(0xFFE8F6EF),
                          child: Icon(PhosphorIcons.house(),
                              color: const Color(0xFF75C797), size: 40)),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Details Column
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
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
                                      text: '/month',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF9CA3AF),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13.0,
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
                          // Footer Icons (Views & Likes)
                          Row(
                            children: [
                              Icon(PhosphorIcons.eye(PhosphorIconsStyle.fill),
                                  size: 18, color: const Color(0xFF9CA3AF)),
                              const SizedBox(width: 4),
                              Text('1,243',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13.0,
                                      color: const Color(0xFF9CA3AF),
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(width: 16),
                              Icon(PhosphorIcons.heart(PhosphorIconsStyle.fill),
                                  size: 16, color: const Color(0xFFEC4899)),
                              const SizedBox(width: 4),
                              Text('24',
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

// ─── Floating Glass Button ────────────────────────────────────────────────────

class _GlassFloatingButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _GlassFloatingButton({required this.onPressed});

  @override
  State<_GlassFloatingButton> createState() => _GlassFloatingButtonState();
}

class _GlassFloatingButtonState extends State<_GlassFloatingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        height: 64,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF75C797).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF75C797)
                    .withValues(alpha: 0.85), // Emerald translucent green
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.plus(), color: Colors.white, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'Add New Property',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
