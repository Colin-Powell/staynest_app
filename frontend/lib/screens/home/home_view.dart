// START OF FILE
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/screens/communication/notifications_view.dart';
import 'package:property_app/widgets/shared.dart';
import 'package:property_app/models/property.dart';
import 'package:property_app/services/properties_api.dart';
import 'package:property_app/services/property_service.dart';
import 'package:property_app/utils/category_utils.dart';
import 'package:property_app/utils/property_mapper.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/screens/dashboard/analytics_service.dart';
import 'package:visibility_detector/visibility_detector.dart';

// ─── Theme colors ─────────────────────────────────────────────────────────────
const _primaryText = Color(0xFF4F70F8);
const _bg = Color(0xFFFAFAFA);
const _dark = Color(0xFF111827);
const _grey = Color(0xFF9CA3AF);
const _green = Color(0xFF22C55E);

// ─── HomeView ─────────────────────────────────────────────────────────────────

class HomeView extends StatefulWidget {
  final void Function(String id)? onSelectProperty;
  final VoidCallback? onNotifications;

  const HomeView({
    super.key,
    this.onSelectProperty,
    this.onNotifications,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _activeFilter = 0;
  final _searchController = TextEditingController();
  final PageController _carouselController =
      PageController(viewportFraction: 0.88);
  List<Property> _nearby = [];
  List<Property> _recommended = [];
  bool _loadingNearby = true;
  bool _loadingRecommended = true;

  List<Property> get _filteredNearby {
    final filter = homeCategoryFilters[_activeFilter];
    return _nearby
        .where((p) => categoryMatchesUiFilter(p.category, filter))
        .toList();
  }

  List<Property> get _filteredRecommended {
    final filter = homeCategoryFilters[_activeFilter];
    return _recommended
        .where((p) => categoryMatchesUiFilter(p.category, filter))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loadingNearby = true;
      _loadingRecommended = true;
    });

    try {
      final allProperties = await PropertiesApi.getAllProperties();

      if (allProperties.isNotEmpty) {
        final properties = allProperties.map(mapApiProperty).toList();

        final rec = await PropertiesApi.getRecommendations();
        final recMapped = rec.isNotEmpty
            ? rec.map(mapApiProperty).toList()
            : properties.take(3).toList();

        setState(() {
          _nearby = properties;
          _recommended = recMapped;
          _loadingNearby = false;
          _loadingRecommended = false;
        });
      } else {
        setState(() {
          _nearby = [];
          _recommended = [];
          _loadingNearby = false;
          _loadingRecommended = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading properties: $e');
      setState(() {
        _nearby = [];
        _recommended = [];
        _loadingNearby = false;
        _loadingRecommended = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Theme(
        data: ThemeData(
          textTheme: GoogleFonts.poppinsTextTheme(),
        ),
        child: Scaffold(
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              // Soft Background Gradient tailored to blend cleanly with _bg
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
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(context)),
                  SliverToBoxAdapter(child: _buildNearbySection()),
                  SliverToBoxAdapter(child: _buildRecommendedSection()),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 120), // Clearance for bottom nav
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final displayName = AppSession.displayName;
    final displayAvatar = AppSession.displayAvatar;

    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 24,
        right: 24,
        bottom: 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Hello, $displayName 👋',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
              ),
              // Notification Bell (Glassmorphism style)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsView(),
                    ),
                  );
                },
                child: _GlassContainer(
                  padding: const EdgeInsets.all(10),
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_rounded,
                        size: 24,
                        color: _dark,
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Avatar (Cloudinary fix applied)
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/profile'),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: AppSession.buildAvatar(
                      displayAvatar,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Hero Text
          Text(
            'Find your\nperfect place',
            style: GoogleFonts.poppins(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: _dark,
              height: 1.2,
              letterSpacing: -1.0,
            ),
          ),

          const SizedBox(height: 24),

          // Clean Magic Search Bar
          _GlassContainer(
            padding: EdgeInsets.zero,
            height: 54,
            borderRadius: BorderRadius.circular(28),
            opacity: 0.6,
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Icon(Icons.search_rounded, color: _dark, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _dark,
                    ),
                    onSubmitted: (v) async {
                      AnalyticsService.resetSessionImpressions();
                      await PropertyService.instance.saveSearchTerm(v);
                      await _loadData();
                    },
                    // Stripping all native fills and borders
                    decoration: InputDecoration(
                      hintText: 'Search locations, area...',
                      hintStyle: GoogleFonts.poppins(
                        color: _grey,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                // ValueListenableBuilder dynamically shows/hides X without full rebuilds
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, child) {
                    if (value.text.isNotEmpty) {
                      return GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          FocusScope.of(context).unfocus();
                        },
                        child: const Padding(
                          padding: EdgeInsets.only(right: 16, left: 8),
                          child: Icon(Icons.cancel, color: _grey, size: 22),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Filter Chips (Upgraded to Glass Pills)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            child: Row(
              children: homeCategoryFilters.asMap().entries.map((e) {
                final isActive = e.key == _activeFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () {
                      AnalyticsService.resetSessionImpressions();
                      setState(() => _activeFilter = e.key);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isActive ? _dark : Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isActive ? _dark : Colors.white.withOpacity(0.8),
                          width: 1.5,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: _dark.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        e.value,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                          color: isActive ? Colors.white : _dark,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ─── Nearby Section ────────────────────────────────────────────────────────

  Widget _buildNearbySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Nearby You',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                'See all',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _primaryText,
                ),
              ),
            ],
          ),
        ),
        if (_filteredNearby.isEmpty)
          _loadingNearby
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(color: _primaryText)),
                )
              : Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Center(
                    child: Text(
                      'No ${homeCategoryFilters[_activeFilter]} nearby.',
                      style: GoogleFonts.poppins(color: _grey),
                    ),
                  ),
                )
        else
          SizedBox(
            height: 380,
            child: PageView.builder(
              controller: _carouselController,
              clipBehavior: Clip.none,
              physics: const BouncingScrollPhysics(),
              itemCount: _filteredNearby.length,
              itemBuilder: (context, i) {
                final property = _filteredNearby[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: VisibilityDetector(
                    key: Key('nearby_impression_${property.id}'),
                    onVisibilityChanged: (info) {
                      if (info.visibleFraction > 0.5) {
                        AnalyticsService.trackFeaturedPropertyImpression(
                          property.id,
                          position: i,
                        );
                      }
                    },
                    child: _NearbyCard(
                      property: property,
                      onTap: () => widget.onSelectProperty?.call(property.id),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ─── Recommended Section ──────────────────────────────────────────────────

  Widget _buildRecommendedSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommended For You',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _dark,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 16),
          if (_loadingRecommended)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(color: _primaryText)),
            )
          else if (_filteredRecommended.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No recommendations found.',
                style: GoogleFonts.poppins(color: _grey),
              ),
            )
          else
            ..._filteredRecommended.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: VisibilityDetector(
                  key: Key('recommended_impression_${p.id}'),
                  onVisibilityChanged: (info) {
                    if (info.visibleFraction > 0.5) {
                      AnalyticsService.trackPropertyImpression(
                        p.id,
                        source: 'home_recommended',
                        position: i,
                      );
                    }
                  },
                  child: _RecommendedCard(
                    property: p,
                    onTap: () => widget.onSelectProperty?.call(p.id),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ─── Nearby Card ────────────────────────────────────────────────────────────

class _NearbyCard extends StatelessWidget {
  final Property property;
  final VoidCallback onTap;

  const _NearbyCard({required this.property, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            fit: StackFit.expand,
            children: [
              buildPropertyImage(
                property.image,
                fit: BoxFit.cover,
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.4, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.85),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 18,
                left: 18,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFBBC05), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${property.rating.toStringAsFixed(1)} (${property.reviews})',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned(
                top: 18,
                right: 18,
                child: VerifiedBadge(size: 36),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill), size: 16, color: Colors.white70),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            property.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formatPropertyPrice(property.price),
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _green,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          '/month',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
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

// ─── Recommended Card ──────────────────────────────────────────────────────

class _RecommendedCard extends StatelessWidget {
  final Property property;
  final VoidCallback onTap;

  const _RecommendedCard({required this.property, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _GlassContainer(
        padding: EdgeInsets.zero, // Flush image to the edge
        borderRadius: BorderRadius.circular(24),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
              child: buildPropertyImage(
                property.image,
                width: 110,
                height: 110,
                fit: BoxFit.cover,
                errorPlaceholder: Container(width: 110, height: 110, color: const Color(0xFFE5E7EB)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill), size: 14, color: _grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            property.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: _grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              formatPropertyPrice(property.price),
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _dark,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              '/mo',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: _grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (property.reviews > 0)
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFFBBC05), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${property.rating.toStringAsFixed(1)} (${property.reviews})',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _dark,
                                ),
                              ),
                            ],
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

  const _GlassContainer({
    required this.child,
    required this.padding,
    this.borderRadius,
    this.blur = 20.0,
    this.opacity = 0.55,
    this.borderWidth = 1.5,
    this.height,
  });

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