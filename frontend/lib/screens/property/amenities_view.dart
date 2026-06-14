import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

const Color _tenantPrimary = Color(0xFF3F37C9); // Tenant Blue Theme
const Color _textDark = Color(0xFF111827);
const Color _textLight = Color(0xFF6B7280);

class _AmenityDisplay {
  final IconData icon;
  final String title;
  final Color iconColor;
  final Color bgColor;

  const _AmenityDisplay(
    this.icon,
    this.title, {
    this.iconColor = _tenantPrimary,
    this.bgColor = const Color(0xFFEEF2FF),
  });
}

const _essentialKeys = {
  'wifi',
  'internet',
  'water',
  'parking',
  'security',
  'electricity',
  'cctv',
  'heating',
  'air conditioning',
  'hot water',
};

// Mapped to clean Phosphor Icons (Filled)
_AmenityDisplay _amenityDisplayFor(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('wifi') || lower.contains('internet')) {
    return _AmenityDisplay(PhosphorIcons.wifiHigh(PhosphorIconsStyle.fill), name,
        iconColor: const Color(0xFF3B82F6), bgColor: const Color(0xFFEFF6FF));
  }
  if (lower.contains('water')) {
    return _AmenityDisplay(PhosphorIcons.drop(PhosphorIconsStyle.fill), name,
        iconColor: const Color(0xFF3B82F6), bgColor: const Color(0xFFEFF6FF));
  }
  if (lower.contains('parking') || lower.contains('car')) {
    return _AmenityDisplay(PhosphorIcons.carProfile(PhosphorIconsStyle.fill), name,
        iconColor: const Color(0xFF10B981), bgColor: const Color(0xFFECFDF5));
  }
  if (lower.contains('security') || lower.contains('guard')) {
    return _AmenityDisplay(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill), name,
        iconColor: const Color(0xFF3B82F6), bgColor: const Color(0xFFEFF6FF));
  }
  if (lower.contains('electric')) {
    return _AmenityDisplay(PhosphorIcons.lightning(PhosphorIconsStyle.fill), name,
        iconColor: const Color(0xFFF59E0B), bgColor: const Color(0xFFFFFBEB));
  }
  if (lower.contains('cctv') || lower.contains('camera')) {
    return _AmenityDisplay(PhosphorIcons.videoCamera(PhosphorIconsStyle.fill), name,
        iconColor: const Color(0xFFEF4444), bgColor: const Color(0xFFFEF2F2));
  }
  if (lower.contains('gym') || lower.contains('fitness')) {
    return _AmenityDisplay(PhosphorIcons.barbell(PhosphorIconsStyle.fill), name);
  }
  if (lower.contains('pool') || lower.contains('swim')) {
    return _AmenityDisplay(PhosphorIcons.swimmingPool(PhosphorIconsStyle.fill), name);
  }
  if (lower.contains('furnish')) {
    return _AmenityDisplay(PhosphorIcons.armchair(PhosphorIconsStyle.fill), name);
  }
  if (lower.contains('laundry') || lower.contains('washer')) {
    return _AmenityDisplay(PhosphorIcons.washingMachine(PhosphorIconsStyle.fill), name);
  }
  if (lower.contains('balcony') || lower.contains('patio')) {
    return _AmenityDisplay(PhosphorIcons.doorOpen(PhosphorIconsStyle.fill), name);
  }
  if (lower.contains('kitchen')) {
    return _AmenityDisplay(PhosphorIcons.cookingPot(PhosphorIconsStyle.fill), name);
  }
  if (lower.contains('pet')) {
    return _AmenityDisplay(PhosphorIcons.pawPrint(PhosphorIconsStyle.fill), name);
  }
  if (lower.contains('elevator') || lower.contains('lift')) {
    return _AmenityDisplay(PhosphorIcons.elevator(PhosphorIconsStyle.fill), name);
  }
  if (lower.contains('generator') || lower.contains('backup')) {
    return _AmenityDisplay(PhosphorIcons.batteryCharging(PhosphorIconsStyle.fill), name);
  }
  return _AmenityDisplay(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), name,
      iconColor: _textLight, bgColor: Colors.white);
}

bool _isEssential(String name) {
  final lower = name.toLowerCase();
  return _essentialKeys.any((key) => lower.contains(key));
}

class AmenitiesView extends StatefulWidget {
  final VoidCallback onClose;
  final List<String> amenities;

  const AmenitiesView({
    super.key,
    required this.onClose,
    this.amenities = const [],
  });

  @override
  State<AmenitiesView> createState() => _AmenitiesViewState();
}

class _AmenitiesViewState extends State<AmenitiesView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _pageSlideAnim;
  late final Animation<double> _pageFadeAnim;

  List<_AmenityDisplay> get _essentialItems =>
      widget.amenities.where(_isEssential).map(_amenityDisplayFor).toList();

  List<_AmenityDisplay> get _additionalItems =>
      widget.amenities.where((a) => !_isEssential(a)).map(_amenityDisplayFor).toList();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _pageSlideAnim = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
    ));

    _pageFadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildStaggeredChild({
    required Widget child,
    required int index,
    required double startInterval,
  }) {
    final double start = (startInterval + (index * 0.05)).clamp(0.0, 1.0);
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
    final hasAmenities = widget.amenities.isNotEmpty;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Soft Gradient Background (Tenant Theme)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF5F7FF), // Soft icy blue
                  Color(0xFFEBF0FF), // Light indigo
                  Color(0xFFDCE4FF), // Deeper soft blue
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          SlideTransition(
            position: _pageSlideAnim,
            child: FadeTransition(
              opacity: _pageFadeAnim,
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStaggeredChild(
                      index: 0,
                      startInterval: 0.1,
                      child: _buildHeader(context),
                    ),
                    Expanded(
                      child: !hasAmenities
                          ? Center(
                              child: Text(
                                'No amenities listed for this property.',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: _textLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 112),
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_essentialItems.isNotEmpty) ...[
                                    _buildStaggeredChild(
                                      index: 0,
                                      startInterval: 0.15,
                                      child: _buildSectionTitle('Essentials'),
                                    ),
                                    const SizedBox(height: 24),
                                    _buildStaggeredChild(
                                        index: 1,
                                        startInterval: 0.2,
                                        child: _buildEssentialGrid()),
                                    const SizedBox(height: 40),
                                  ],
                                  if (_additionalItems.isNotEmpty) ...[
                                    _buildStaggeredChild(
                                      index: 0,
                                      startInterval: 0.4,
                                      child: _buildSectionTitle('Additional Features'),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildStaggeredChild(
                                        index: 1,
                                        startInterval: 0.45,
                                        child: _buildAdditionalList()),
                                  ],
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Row(
        children: [
          _GlassCircleButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: widget.onClose,
          ),
          const SizedBox(width: 16),
          Text(
            'Amenities',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _textDark,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: _textDark,
      ),
    );
  }

  Widget _buildEssentialGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Fits 4 elements per row accurately, dividing exactly.
        final itemWidth = constraints.maxWidth / 4;

        return Wrap(
          spacing: 0,
          runSpacing: 24,
          children: _essentialItems.map((item) {
            return SizedBox(
              width: itemWidth, 
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: item.bgColor.withOpacity(0.8),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Icon(item.icon, color: item.iconColor, size: 26),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      item.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textDark,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAdditionalList() {
    return Column(
      children: _additionalItems.asMap().entries.map((entry) {
        final int index = entry.key;
        final _AmenityDisplay item = entry.value;

        return Padding(
          padding: EdgeInsets.only(
              bottom: index == _additionalItems.length - 1 ? 8 : 0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.icon, color: _tenantPrimary, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        item.title,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (index != _additionalItems.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withOpacity(0.6),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Floating Utilities ───────────────────────────────────────────────────────

class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.4)),
            ),
            child: Icon(icon, color: _textDark, size: 20),
          ),
        ),
      ),
    );
  }
}