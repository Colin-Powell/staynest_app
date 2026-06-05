import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/screens/theme.dart';

class LandlordInfoView extends StatefulWidget {
  final VoidCallback onClose;

  const LandlordInfoView({
    super.key,
    required this.onClose,
  });

  @override
  State<LandlordInfoView> createState() => _LandlordInfoViewState();
}

class _LandlordInfoViewState extends State<LandlordInfoView>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  bool _showProperties = false;

  final List<String> _documents = [
    'ID / Passport',
    'Business Registration',
    'Property Ownership',
    'KRA PIN Certificate',
  ];

  // Mock property data matching the screenshot
  final List<Map<String, dynamic>> _properties = [
    {
      'image': 'assets/images/hero.jpg',
      'title': '11 Green bank',
      'location': 'Kilifi, Kenya',
      'price': '12k',
      'rating': '4.8',
      'beds': '2 Beds',
      'isFavorite': true,
    },
    {
      'image': 'assets/images/hero1.jpg',
      'title': '11 Green bank',
      'location': 'Kilifi, Kenya',
      'price': '12k',
      'rating': '4.8',
      'beds': '2 Beds',
      'isFavorite': false,
    },
    {
      'image': 'assets/images/hero2.jpg',
      'title': '11 Green bank',
      'location': 'Kilifi, Kenya',
      'price': '12k',
      'rating': '4.8',
      'beds': '2 Beds',
      'isFavorite': true,
    },
    {
      'image': 'assets/images/hero3.jpg',
      'title': '11 Green bank',
      'location': 'Kilifi, Kenya',
      'price': '12k',
      'rating': '4.8',
      'beds': '2 Beds',
      'isFavorite': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleProperties() {
    setState(() {
      _showProperties = !_showProperties;
    });
    // Reset and replay animation for the new list elements
    _controller.reset();
    _controller.forward();
  }

  /// Helper to create a smooth staggered fade and upward slide for list items
  Widget _buildStaggered({required Widget child, required int index}) {
    final double start = (index * 0.08).clamp(0.0, 1.0);
    final double end = (start + 0.4).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StayNestColors.surfaceVariantLight,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: _showProperties ? _buildPropertiesView() : _buildInfoView(),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // INFO VIEW (ORIGINAL SCREEN)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildInfoView() {
    return Stack(
      key: const ValueKey('InfoView'),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStaggered(
              index: 0,
              child: _buildHeader('Landlord Info', onBack: widget.onClose),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildStaggered(index: 1, child: _buildLandlordProfile()),
                    const SizedBox(height: 24),
                    _buildStaggered(index: 2, child: _buildDivider()),
                    const SizedBox(height: 20),
                    _buildStaggered(index: 3, child: _buildStatsRow()),
                    const SizedBox(height: 20),
                    _buildStaggered(index: 4, child: _buildDivider()),
                    const SizedBox(height: 32),
                    _buildStaggered(index: 5, child: _buildAboutSection()),
                    const SizedBox(height: 32),
                    _buildStaggered(index: 6, child: _buildDocumentsSection()),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildStaggered(index: 7, child: _buildBottomCta()),
        ),
      ],
    );
  }

  Widget _buildLandlordProfile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Landlord Profile Image / Logo
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE5E7EB),
              image: const DecorationImage(
                image: AssetImage(
                    'assets/images/apertment1.jpg'), // Mock profile picture
                fit: BoxFit.cover,
              ),
              border: Border.all(color: const Color(0xFF22C55E), width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Name, badge, rating
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GreenHomes Ltd.',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: StayNestColors.textPrimaryLight,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Verified Landlord',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: StayNestColors.success,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/reviews'),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.star(PhosphorIconsStyle.fill),
                          color: StayNestColors.accent, size: 22),
                      const SizedBox(width: 6),
                      Text(
                        '4.8',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: StayNestColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(200 Reviews)',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: StayNestColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCta() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            StayNestColors.surfaceVariantLight.withValues(alpha: 0.0),
            StayNestColors.surfaceVariantLight.withValues(alpha: 0.9),
            StayNestColors.surfaceVariantLight,
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
      ),
      child: ElevatedButton(
        onPressed: _toggleProperties,
        style: ElevatedButton.styleFrom(
          backgroundColor: StayNestColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          'View all Properties',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PROPERTIES VIEW (NEW SCREEN MATCHING SCREENSHOT)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildPropertiesView() {
    return Column(
      key: const ValueKey('PropertiesView'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStaggered(
          index: 0,
          child: _buildHeader('Properties', onBack: _toggleProperties),
        ),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              top: 16,
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).padding.bottom + 24,
            ),
            itemCount: _properties.length,
            itemBuilder: (context, index) {
              final prop = _properties[index];
              return _buildStaggered(
                index: index + 1,
                child: _buildPropertyCard(prop),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> prop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          // Left Image
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              prop['image'],
              width: 140,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          // Right Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Heart
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          prop['title'],
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: StayNestColors.textPrimaryLight,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        PhosphorIcons.heart(
                          prop['isFavorite']
                              ? PhosphorIconsStyle.fill
                              : PhosphorIconsStyle.regular,
                        ),
                        color: prop['isFavorite']
                            ? const Color(0xFFEC4899)
                            : const Color(0xFF9CA3AF),
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Location
                  Row(
                    children: [
                      Icon(
                        PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                        size: 14,
                        color: StayNestColors.textMutedLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        prop['location'],
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: StayNestColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'Kes. ${prop['price']}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: StayNestColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        '/month',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: StayNestColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Rating & Beds
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Rating Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              PhosphorIcons.star(PhosphorIconsStyle.fill),
                              size: 14,
                              color: StayNestColors.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              prop['rating'],
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: StayNestColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Beds
                      Text(
                        prop['beds'],
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: StayNestColors.textSecondaryLight,
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

  // ──────────────────────────────────────────────────────────────────────────
  // SHARED WIDGETS
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(String title, {required VoidCallback onBack}) {
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 24,
        right: 24,
        bottom: 16,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: const Icon(Icons.arrow_back, size: 28, color: Colors.black),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Divider(
        color: Color(0xFFE5E7EB),
        thickness: 1.5,
        height: 1,
      ),
    );
  }

  Widget _buildStatsRow() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StatItem(label: 'Response Rate', value: '98%'),
          _StatItem(label: 'Properties', value: '32'),
          _StatItem(label: 'Member Since', value: 'May 2002'),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'We are a trusted property management\ncompany specializing in quality rentals across\nNairobi.',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4B5563),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verified Documents',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(_documents.length, (i) {
            return _buildStaggered(
              index: 7 + i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      color: Color(0xFF22C55E),
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      _documents[i],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
