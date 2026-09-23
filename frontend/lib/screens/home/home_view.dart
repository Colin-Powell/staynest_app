import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/session/onboarding_prefs.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/widgets/onboarding_bottom_sheet.dart';
import 'package:property_app/widgets/property_card.dart';

import 'package:property_app/models/property.dart';
import 'package:property_app/screens/home/home_feed_controller.dart';

const _bg = Color(0xFFFAFAFA);
const _dark = Color(0xFF111827);
const _grey = Color(0xFF9CA3AF);
const _primaryText = Color(0xFF4F70F8);

class HomeView extends StatefulWidget {
  final void Function(Property)? onSelectProperty;
  final VoidCallback? onNotifications;
  final void Function(String category)? onSeeCategory;
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
    var latitude = widget.latitude ?? AppSession.discoveryLatitude;
    var longitude = widget.longitude ?? AppSession.discoveryLongitude;
    final campusId = widget.campusId ?? AppSession.discoveryCampusId;
    final locationId = widget.locationId ?? AppSession.discoveryLocationId;

    // Use device location only when permission was already granted. Home must
    // remain usable without prompting or depending on location services.
    if (latitude == null || longitude == null) {
      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (serviceEnabled) {
            final position = await Geolocator.getCurrentPosition();
            latitude = position.latitude;
            longitude = position.longitude;
          }
        }
      } catch (_) {
        // Feed context is optional; fall back to campus/location/global data.
      }
    }

    await _feedController.loadFeed(
      lat: latitude,
      lng: longitude,
      radiusKm: widget.radiusKm,
      campusId: campusId,
      locationId: locationId,
      category: _selectedCategory,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadFeed,
          color: _primaryText,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildCategoryPills()),
              if (_feedController.isLoading)
                SliverToBoxAdapter(child: _buildShimmerLoading())
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
                            section.title, section.items),
                      ),
                    );

                    // Insert Promo Card after the first section
                    if (i == 0) {
                      sliverWidgets
                          .add(SliverToBoxAdapter(child: _buildPromoCard()));
                    }
                  }

                  return sliverWidgets;
                }(),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

// ─── REHANI PROMOTIONAL CARD ─────────────────────────────────────────

  Widget _buildPromoCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // ─── LEFT CONTENT ───────────────────────────────────────
            Positioned(
              left: 24,
              top: 24,
              bottom: 24,
              right: 125,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // New Feature Badge
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE4F5EB),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              PhosphorIconsRegular.tag,
                              color: Color(0xFF065F46),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'New Feature',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      CustomPaint(
                        size: const Size(16, 16),
                        painter: _SparklePainter(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Rehani Title
                  Text(
                    'Rehani',
                    style: GoogleFonts.poppins(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0A1C30),
                      letterSpacing: -1.0,
                      height: 1.0,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Description
                  Text(
                    'Buy and sell second-hand\nitems near you.',
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF475569),
                      height: 1.45,
                    ),
                  ),

                  const Spacer(),

                  // Coming Soon Button
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4F5EB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Coming Soon',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF065F46),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          PhosphorIconsRegular.arrowRight,
                          color: Color(0xFF065F46),
                          size: 15,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── 3D ILLUSTRATION ────────────────────────────────────
            Positioned(
              right: -8,
              bottom: 0,
              child: Image.asset(
                'assets/images/rehani.png',
                height: 175,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return SizedBox(
                    width: 140,
                    height: 140,
                    child: Center(
                      child: Icon(
                        PhosphorIconsRegular.shoppingBag,
                        color: _grey,
                        size: 48,
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

  // ─── UI BUILDERS ──────────────────────────────────────────────────────────

  Widget _buildCategoryPills() {
    final types = [
      {'name': 'All', 'image': 'assets/images/all.webp'},
      {'name': 'Apartments', 'image': 'assets/images/apartments.webp'},
      {'name': 'Bedsitter', 'image': 'assets/images/bedsitter.webp'},
      {'name': 'Single Room', 'image': 'assets/images/singleroom.webp'},
      {'name': 'One Bedroom', 'image': 'assets/images/onebedroom.webp'},
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: SizedBox(
        height: 52, // Adjusted height for premium pills
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
              onTap: () {
                setState(() {
                  if (_selectedCategory == label) {
                    _selectedCategory = 'All';
                  } else {
                    _selectedCategory = label;
                  }
                });
                _loadFeed();
              },
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

  Widget _buildHorizontalCollection(String title, List<Property> properties) {
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
                  onTap: () => widget.onSeeCategory
                      ?.call(title), // Route to search tab with category
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
              itemCount: properties.length,
              itemBuilder: (context, index) {
                final p = properties[index];
                return PropertyCard(
                  property: p,
                  onTap: () => widget.onSelectProperty?.call(p),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
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
                          width: 300,
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
}

// ─── Custom Painter for the Rehani "Sparkles" ──────────────────────────────
class _SparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF065F46)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Center coordinates
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Draw 3 radiating lines matching the screenshot
    // Top right
    canvas.drawLine(Offset(cx + 2, cy - 2), Offset(cx + 6, cy - 6), paint);
    // Middle right
    canvas.drawLine(Offset(cx + 4, cy + 2), Offset(cx + 10, cy + 2), paint);
    // Bottom right
    canvas.drawLine(Offset(cx + 2, cy + 6), Offset(cx + 6, cy + 10), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
