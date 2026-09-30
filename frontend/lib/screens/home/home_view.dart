import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/session/onboarding_prefs.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/widgets/onboarding_bottom_sheet.dart';
import 'package:property_app/widgets/property_card.dart';
import 'package:property_app/widgets/property_image.dart';

import 'package:property_app/models/property.dart';
import 'package:property_app/screens/home/home_feed_controller.dart';
import 'package:property_app/services/device_location_service.dart';

const _bg = Color(0xFFFAFAFA);
const _dark = Color(0xFF111827);
const _grey = Color(0xFF9CA3AF);
const _primaryText = Color(0xFF4F70F8);
const _border = Color(0xFFE5E7EB);

/// At or above this width the Airbnb-style desktop layout is used.
/// Below it, the original mobile layout is rendered unchanged.
const double _desktopBreakpoint = 768;
const double _desktopMaxWidth = 1760;
const double _cardHeight = 380;
const double _cardGap = 24;

const _categoryTypes = <Map<String, String>>[
  {'name': 'All', 'image': 'assets/images/all.webp'},
  {'name': 'Apartments', 'image': 'assets/images/apartments.webp'},
  {'name': 'Bedsitter', 'image': 'assets/images/bedsitter.webp'},
  {'name': 'Single Room', 'image': 'assets/images/singleroom.webp'},
  {'name': 'One Bedroom', 'image': 'assets/images/onebedroom.webp'},
];

class HomeView extends StatefulWidget {
  final void Function(Property)? onSelectProperty;
  final VoidCallback? onNotifications;
  final void Function(String category)? onSeeCategory;
  final void Function(String title, List<Property> properties)? onSeeCollection;
  final Future<void> Function({VoidCallback? onAuthenticated})?
      onRequireAuthentication;
  final double? latitude;
  final double? longitude;
  final String? campusId;
  final String? locationId;
  final double radiusKm;

  const HomeView({
    super.key,
    this.onSelectProperty,
    this.onNotifications,
    this.onSeeCategory,
    this.onSeeCollection,
    this.onRequireAuthentication,
    this.latitude,
    this.longitude,
    this.campusId,
    this.locationId,
    this.radiusKm = 5,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _searchController = TextEditingController();
  final HomeFeedController _feedController = HomeFeedController();
  int _feedRequestId = 0;

  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _feedController.addListener(_onFeedUpdated);
    _loadFeed();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!OnboardingPrefs.hasSeen('homeSeen')) {
        OnboardingBottomSheet.show(
          context: context,
          imagePath: 'assets/images/home_onboarding.png',
          title: 'Discover your next stay',
          subtitle:
              'Browse curated property collections, discover trending stays, and find highly rated properties near you.',
          ctaText: 'Explore stays',
        ).then((_) => OnboardingPrefs.markAsSeen('homeSeen'));
      }
    });
  }

  @override
  void dispose() {
    _feedController.removeListener(_onFeedUpdated);
    _feedController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onFeedUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _loadFeed() async {
    final requestId = ++_feedRequestId;
    final latitude = widget.latitude ??
        AppSession.discoveryLatitude ??
        AppSession.deviceLatitude;
    final longitude = widget.longitude ??
        AppSession.discoveryLongitude ??
        AppSession.deviceLongitude;
    final campusId = widget.campusId ?? AppSession.discoveryCampusId;
    final locationId = widget.locationId ?? AppSession.discoveryLocationId;
    final locationFuture = latitude == null || longitude == null
        ? DeviceLocationService.instance.initialize()
        : null;

    await _feedController.loadFeed(
      lat: latitude,
      lng: longitude,
      radiusKm: widget.radiusKm,
      campusId: campusId,
      locationId: locationId,
      category: _selectedCategory,
    );

    if (locationFuture == null ||
        !mounted ||
        requestId != _feedRequestId ||
        campusId != null ||
        locationId != null ||
        widget.latitude != null ||
        widget.longitude != null ||
        AppSession.discoveryLatitude != null ||
        AppSession.discoveryLongitude != null) {
      return;
    }

    final position = await locationFuture;
    if (!mounted || requestId != _feedRequestId || position == null) return;
    await _feedController.loadFeed(
      lat: position.latitude,
      lng: position.longitude,
      radiusKm: widget.radiusKm,
      category: _selectedCategory,
    );
  }

  void _onCategoryTap(String label) {
    setState(() {
      if (_selectedCategory == label) {
        _selectedCategory = 'All';
      } else {
        _selectedCategory = label;
      }
    });
    final selectedCategory =
        _selectedCategory == 'All' ? '' : _selectedCategory;
    if (widget.onSeeCategory != null) {
      widget.onSeeCategory!(selectedCategory);
    } else {
      _loadFeed();
    }
  }

  String? _badgeLabelForSection(String sectionId) {
    switch (sectionId) {
      case 'recently_viewed':
        return 'Recently Viewed';
      case 'new_listings':
        return 'New';
      case 'trending_now':
        return 'Trending';
      default:
        return null;
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _desktopBreakpoint) {
          return _buildDesktop(constraints.maxWidth);
        }
        return _buildMobile();
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MOBILE (original layout, unchanged)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMobile() {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: RefreshIndicator(
              onRefresh: _loadFeed,
              color: _primaryText,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverToBoxAdapter(child: _buildCategoryPills()),
                  if (_feedController.isLoading)
                    SliverToBoxAdapter(child: _buildShimmerLoading(context))
                  else if (_feedController.hasError)
                    SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Text('Failed to load properties',
                              style: GoogleFonts.poppins(color: _grey)),
                        ),
                      ),
                    )
                  else if (_feedController.feedResponse == null ||
                      _feedController.feedResponse!.sections.isEmpty)
                    SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Text('No properties available',
                              style: GoogleFonts.poppins(color: _grey)),
                        ),
                      ),
                    )
                  else
                    ...() {
                      final sliverWidgets = <Widget>[];

                      final sections = _feedController.feedResponse!.sections;
                      for (int i = 0; i < sections.length; i++) {
                        final section = sections[i];

                        sliverWidgets.add(
                          SliverToBoxAdapter(
                            child: _buildHorizontalCollection(
                              context,
                              section.title,
                              section.items,
                              hasMore: section.hasMore,
                              badgeLabel: _badgeLabelForSection(section.id),
                            ),
                          ),
                        );

                        // Insert Promo Card after the first section
                        if (i == 0) {
                          sliverWidgets.add(SliverToBoxAdapter(
                              child: _buildPromoCard(context)));
                        }
                      }

                      return sliverWidgets;
                    }(),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPills() {
    const types = _categoryTypes;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: types.length,
          separatorBuilder: (context, index) => const SizedBox(width: 16),
          itemBuilder: (context, index) {
            final type = types[index];
            final label = type['name']!;
            final imagePath = type['image']!;
            final isSelected = _selectedCategory == label;

            return GestureDetector(
              onTap: () => _onCategoryTap(label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.only(
                    left: 6, right: 16, top: 6, bottom: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected
                        ? Colors.black
                        : Colors.grey.withOpacity(0.2),
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
                          image: AssetImage(imagePath),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _dark,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Where to next?',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              GestureDetector(
                onTap: widget.onNotifications,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: const Icon(PhosphorIconsRegular.bell,
                      color: _dark, size: 24),
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => widget.onSeeCategory?.call(''), // Route to search tab
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.magnifyingGlass,
                      color: _grey, size: 22),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Search destinations',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _dark,
                        ),
                      ),
                      Text(
                        'Anywhere • Any week • Add guests',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _grey,
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
    );
  }

  Widget _buildHorizontalCollection(
      BuildContext context, String title, List<Property> properties,
      {required bool hasMore, String? badgeLabel}) {
    final visiblePropertyCount = math.min(properties.length, 7);
    final showViewMore = properties.isNotEmpty &&
        (hasMore || properties.length > visiblePropertyCount);
    final itemCount = visiblePropertyCount + (showViewMore ? 1 : 0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => widget.onSeeCollection?.call(title, properties),
                  child: Text(
                    'See All',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 380,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 24),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (index >= visiblePropertyCount) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: _ViewMorePropertyCard(
                      width: MediaQuery.of(context).size.width * 0.75 > 300
                          ? 300
                          : MediaQuery.of(context).size.width * 0.75,
                      height: 380,
                      properties: properties,
                      onTap: () =>
                          widget.onSeeCollection?.call(title, properties),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.75 > 300
                        ? 300
                        : MediaQuery.of(context).size.width * 0.75,
                    child: PropertyCard(
                      property: properties[index],
                      badgeLabel: badgeLabel,
                      onTap: () =>
                          widget.onSelectProperty?.call(properties[index]),
                      onRequireAuthentication: widget.onRequireAuthentication,
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(2, (sectionIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Shimmer.fromColors(
                  baseColor: Colors.grey.shade200,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                    width: 150,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 380,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 24),
                  itemCount: 3,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: Shimmer.fromColors(
                        baseColor: Colors.grey.shade200,
                        highlightColor: Colors.grey.shade100,
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.75 > 300
                              ? 300
                              : MediaQuery.of(context).size.width * 0.75,
                          height: 380,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DESKTOP (Airbnb-style)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktop(double width) {
    final hPad = width >= 1100 ? 80.0 : 40.0;
    final inner = math.min(width, _desktopMaxWidth) - hPad * 2;

    // Pick a column count that keeps cards between ~240 and ~320px wide,
    // which is the range PropertyCard is already laid out for.
    var cols = math.max(2, ((inner + _cardGap) / (320 + _cardGap)).ceil());
    var cardWidth = (inner - _cardGap * (cols - 1)) / cols;
    if (cardWidth < 240 && cols > 2) {
      cols -= 1;
      cardWidth = (inner - _cardGap * (cols - 1)) / cols;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildDesktopHeader(hPad),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _desktopMaxWidth),
                  child: RefreshIndicator(
                    onRefresh: _loadFeed,
                    color: _primaryText,
                    child: CustomScrollView(
                      physics: const ClampingScrollPhysics(),
                      slivers: [
                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
                        ..._buildDesktopSlivers(
                          hPad: hPad,
                          inner: inner,
                          cols: cols,
                          cardWidth: cardWidth,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDesktopSlivers({
    required double hPad,
    required double inner,
    required int cols,
    required double cardWidth,
  }) {
    if (_feedController.isLoading) {
      return [
        SliverToBoxAdapter(
          child: _buildDesktopShimmer(hPad, cols, cardWidth),
        ),
      ];
    }
    if (_feedController.hasError) {
      return [
        SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(PhosphorIconsRegular.warningCircle,
                      size: 48, color: Color(0xFFEF4444)),
                  const SizedBox(height: 16),
                  Text('Failed to load properties',
                      style: GoogleFonts.poppins(
                          color: _dark,
                          fontWeight: FontWeight.w600,
                          fontSize: 16)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadFeed,
                    child: Text('Retry',
                        style: GoogleFonts.poppins(color: _primaryText)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }
    final response = _feedController.feedResponse;
    if (response == null || response.sections.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Text('No properties available',
                  style: GoogleFonts.poppins(color: _grey)),
            ),
          ),
        ),
      ];
    }

    final slivers = <Widget>[];
    final sections = response.sections;
    for (int i = 0; i < sections.length; i++) {
      final section = sections[i];
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 48),
            child: _DesktopCollection(
              key: ValueKey('collection_${section.id}_${section.title}'),
              title: section.title,
              properties: section.items,
              hasMore: section.hasMore,
              badgeLabel: _badgeLabelForSection(section.id),
              cardWidth: cardWidth,
              gap: _cardGap,
              viewportWidth: inner,
              onTitleTap: () =>
                  widget.onSeeCollection?.call(section.title, section.items),
              onViewMore: () =>
                  widget.onSeeCollection?.call(section.title, section.items),
              onSelectProperty: widget.onSelectProperty,
              onRequireAuthentication: widget.onRequireAuthentication,
            ),
          ),
        ),
      );

      // Promo card after the first section
      if (i == 0) {
        slivers.add(
          SliverToBoxAdapter(child: _buildPromoCard(context, hPad: hPad)),
        );
      }
    }
    return slivers;
  }

  Widget _buildDesktopHeader(double hPad) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _desktopMaxWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Column(
              children: [
                const SizedBox(height: 18),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _buildDesktopSearchPill(),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in _categoryTypes)
                      _CategoryTab(
                        label: type['name']!,
                        imagePath: type['image']!,
                        selected: _selectedCategory == type['name'],
                        onTap: () => _onCategoryTap(type['name']!),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSearchPill() {
    Widget segment(String label, String value) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _dark,
                  height: 1.3,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: _grey,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final divider = Container(width: 1, height: 32, color: _border);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onSeeCategory?.call(''),
        child: Container(
          height: 64,
          padding: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              segment('Find properties', 'By area or property name'),
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: _primaryText,
                  shape: BoxShape.circle,
                ),
                child: const Icon(PhosphorIconsBold.magnifyingGlass,
                    size: 20, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopShimmer(double hPad, int cols, double cardWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(2, (_) {
        return Padding(
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey.shade200,
                highlightColor: Colors.grey.shade100,
                child: Container(
                  width: 200,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  for (int i = 0; i < cols; i++) ...[
                    if (i > 0) const SizedBox(width: _cardGap),
                    Shimmer.fromColors(
                      baseColor: Colors.grey.shade200,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                        width: cardWidth,
                        height: _cardHeight,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildPromoCard(BuildContext context, {double hPad = 24}) {
    const cardWidth = 320.0;
    const gap = 16.0;
    final services = <_ServicePromoData>[
      const _ServicePromoData(
        title: 'Rehani',
        description: 'Buy and sell second-hand items near you.',
        accent: Color(0xFF065F46),
        icon: PhosphorIconsRegular.shoppingBag,
        imagePath: 'assets/images/rehani.png',
        badge: 'New feature',
      ),
      const _ServicePromoData(
        title: 'Bike rental',
        description: 'Find a bike for your next trip.',
        accent: Color(0xFF3156A6),
        icon: Icons.two_wheeler_rounded,
        imagePath: 'assets/images/bike.png',
        badge: 'Coming soon',
      ),
      const _ServicePromoData(
        title: 'Laundry',
        description: 'Book a wash and fold near your stay.',
        accent: Color(0xFF9A531F),
        icon: Icons.local_laundry_service_rounded,
        imagePath: 'assets/images/Laundary.webp',
        badge: 'Coming soon',
      ),
      const _ServicePromoData(
        title: 'Gas refill',
        description: 'Order a cooking gas refill to your door.',
        accent: Color(0xFF9D3443),
        icon: Icons.local_fire_department_rounded,
        imagePath: 'assets/images/gas.png',
        badge: 'Coming soon',
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 32),
      child: SizedBox(
        height: 200,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: services.length,
          separatorBuilder: (_, __) => const SizedBox(width: gap),
          itemBuilder: (context, index) => _ServicePromoCard(
            width: cardWidth,
            data: services[index],
          ),
        ),
      ),
    );
  }
}

class _ServicePromoData {
  final String title;
  final String description;
  final Color accent;
  final IconData icon;
  final String? imagePath;
  final String badge;

  const _ServicePromoData({
    required this.title,
    required this.description,
    required this.accent,
    required this.icon,
    this.imagePath,
    required this.badge,
  });
}

class _ServicePromoCard extends StatelessWidget {
  final double width;
  final _ServicePromoData data;

  const _ServicePromoCard({required this.width, required this.data});

  @override
  Widget build(BuildContext context) {
    final isLandscape = width >= 320;
    final cardHeight = isLandscape ? math.min(width / 1.6, 260.0) : width;

    return SizedBox(
      width: width,
      height: cardHeight,
      child: Container(
        constraints: BoxConstraints.tightFor(width: width, height: cardHeight),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: isLandscape
            ? Row(
                children: [
                  Expanded(flex: 4, child: _buildArtwork()),
                  Expanded(flex: 6, child: _buildCopy()),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: _buildArtwork()),
                  Expanded(flex: 4, child: _buildCopy()),
                ],
              ),
      ),
    );
  }

  Widget _buildArtwork() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: Stack(
        children: [
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                data.badge,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: data.accent,
                ),
              ),
            ),
          ),
          Center(
            child: data.imagePath == null
                ? Icon(
                    data.icon,
                    size: width >= 360 ? 48 : 56,
                    color: data.accent,
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 34, 12, 8),
                    child: Image.asset(
                      data.imagePath!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        data.icon,
                        size: 48,
                        color: data.accent,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopy() {
    return Padding(
      padding: EdgeInsets.all(width >= 360 ? 16 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            data.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: width >= 360 ? 16 : 14,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            data.description,
            maxLines: width >= 360 ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: _grey,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Desktop property-type filter chip
// ═════════════════════════════════════════════════════════════════════════════

class _CategoryTab extends StatefulWidget {
  final String label;
  final String imagePath;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTab({
    required this.label,
    required this.imagePath,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<_CategoryTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(0xFFEAF0FF)
                : _hover
                    ? const Color(0xFFF8FAFC)
                    : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: widget.selected ? const Color(0xFFB8C9FF) : _border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  widget.imagePath,
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(PhosphorIconsRegular.house,
                        size: 18, color: _dark),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight:
                      widget.selected ? FontWeight.w700 : FontWeight.w500,
                  color: _dark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Desktop collection: title + arrows above a paged horizontal carousel
// ═════════════════════════════════════════════════════════════════════════════

class _DesktopCollection extends StatefulWidget {
  final String title;
  final List<Property> properties;
  final bool hasMore;
  final String? badgeLabel;
  final double cardWidth;
  final double gap;
  final double viewportWidth;
  final VoidCallback onTitleTap;
  final VoidCallback onViewMore;
  final void Function(Property)? onSelectProperty;
  final Future<void> Function({VoidCallback? onAuthenticated})?
      onRequireAuthentication;

  const _DesktopCollection({
    super.key,
    required this.title,
    required this.properties,
    required this.hasMore,
    required this.badgeLabel,
    required this.cardWidth,
    required this.gap,
    required this.viewportWidth,
    required this.onTitleTap,
    required this.onViewMore,
    required this.onSelectProperty,
    required this.onRequireAuthentication,
  });

  @override
  State<_DesktopCollection> createState() => _DesktopCollectionState();
}

class _DesktopCollectionState extends State<_DesktopCollection> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  int get _visibleCount {
    final step = widget.cardWidth + widget.gap;
    return math.max(1, ((widget.viewportWidth + widget.gap) / step).floor());
  }

  int get _visiblePropertyCount => math.min(widget.properties.length, 7);

  bool get _showViewMore =>
      widget.properties.isNotEmpty &&
      (widget.hasMore || widget.properties.length > _visiblePropertyCount);

  int get _itemCount => _visiblePropertyCount + (_showViewMore ? 1 : 0);

  void _page(int direction) {
    if (!_controller.hasClients) return;
    final step = (widget.cardWidth + widget.gap) * _visibleCount;
    final target = (_controller.offset + direction * step)
        .clamp(0.0, _controller.position.maxScrollExtent)
        .toDouble();
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c.hasClients && c.position.hasContentDimensions;
    final canLeft = ready && c.offset > 1;
    final canRight = ready
        ? c.offset < c.position.maxScrollExtent - 1
        : _itemCount > _visibleCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: widget.onTitleTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: _dark,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(PhosphorIconsBold.caretRight,
                            size: 16, color: _dark),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CarouselArrow(
                  icon: PhosphorIconsBold.caretLeft,
                  enabled: canLeft,
                  onTap: () => _page(-1),
                ),
                const SizedBox(width: 8),
                _CarouselArrow(
                  icon: PhosphorIconsBold.caretRight,
                  enabled: canRight,
                  onTap: () => _page(1),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: _cardHeight,
          child: ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            itemCount: _itemCount,
            separatorBuilder: (_, __) => SizedBox(width: widget.gap),
            itemBuilder: (context, index) {
              if (index >= _visiblePropertyCount) {
                return _ViewMorePropertyCard(
                  width: widget.cardWidth,
                  height: _cardHeight,
                  properties: widget.properties,
                  onTap: widget.onViewMore,
                );
              }
              final property = widget.properties[index];
              return SizedBox(
                width: widget.cardWidth,
                child: PropertyCard(
                  property: property,
                  badgeLabel: widget.badgeLabel,
                  onTap: () => widget.onSelectProperty?.call(property),
                  onRequireAuthentication: widget.onRequireAuthentication,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ViewMorePropertyCard extends StatelessWidget {
  final double width;
  final double height;
  final List<Property> properties;
  final VoidCallback onTap;

  const _ViewMorePropertyCard({
    required this.width,
    required this.height,
    required this.properties,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final collage = properties.take(4).toList(growable: false);

    Widget imageAt(int index) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: buildPropertyImage(
          collage[index % collage.length].image,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: imageAt(0)),
                            const SizedBox(width: 4),
                            Expanded(child: imageAt(1)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: imageAt(2)),
                            const SizedBox(width: 4),
                            Expanded(child: imageAt(3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'View more',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'See all ${properties.length} stays',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(PhosphorIconsBold.arrowRight,
                      size: 18, color: _dark),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _CarouselArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1 : 0.3,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD1D5DB)),
            ),
            child: Icon(icon, size: 14, color: _dark),
          ),
        ),
      ),
    );
  }
}
