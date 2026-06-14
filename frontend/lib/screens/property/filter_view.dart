import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/app_theme.dart';

class FilterView extends StatefulWidget {
  final VoidCallback onClose;
  final Function(Map<String, dynamic> filters)? onApplyFilters;

  const FilterView({
    super.key,
    required this.onClose,
    this.onApplyFilters,
  });

  @override
  State<FilterView> createState() => _FilterViewState();
}

class _FilterViewState extends State<FilterView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  // Tenant Blue Accent
  static const Color _primary = Color(0xFF3F37C9);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textLight = Color(0xFF6B7280);

  String _selectedType = 'Apartment';
  RangeValues _priceRange = const RangeValues(10000, 200000);
  final Set<String> _selectedAmenities = {'WiFi', 'Furnished'};

  static const _propertyTypes = [
    {'name': 'Apartment', 'icon': Icons.apartment_rounded},
    {'name': 'Bedsitter', 'icon': Icons.hotel_rounded},
    {'name': 'Single', 'icon': Icons.single_bed_rounded},
    {'name': 'One Bedroom', 'icon': Icons.bedroom_parent_rounded},
  ];

  static const _amenities = [
    'WiFi',
    'Water included',
    'Electricity included',
    'Furnished',
    'Parking',
    'Security',
    'CCTV',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _selectedType = 'Apartment';
      _priceRange = const RangeValues(10000, 200000);
      _selectedAmenities.clear();
      _selectedAmenities.addAll(['WiFi', 'Furnished']);
    });
  }

  void _applyFilters() {
    final filters = {
      'propertyType': _selectedType,
      'minPrice': _priceRange.start,
      'maxPrice': _priceRange.end,
      'amenities': _selectedAmenities.toList(),
    };
    widget.onApplyFilters?.call(filters);
    widget.onClose();
  }

  void _toggleAmenity(String amenity) {
    setState(() {
      _selectedAmenities.contains(amenity)
          ? _selectedAmenities.remove(amenity)
          : _selectedAmenities.add(amenity);
    });
  }

  void _handleClose() {
    _animController.reverse().then((_) => widget.onClose());
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              // 1. Soft Gradient Background (Tenant Theme)
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

              // 2. Main Scrolling Content
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 140), // Clearance for bottom bar
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Property Type Section
                            _buildSectionLabel('Property Type'),
                            const SizedBox(height: 16),
                            _buildPropertyTypes(),
                            
                            const SizedBox(height: 32),
                            
                            // Price Range Section
                            _buildSectionLabel('Price Range (Monthly)'),
                            const SizedBox(height: 16),
                            _GlassContainer(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                              child: _buildPriceRange(),
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Amenities Section
                            _buildSectionLabel('Amenities'),
                            const SizedBox(height: 16),
                            _GlassContainer(
                              padding: const EdgeInsets.all(20),
                              child: _buildAmenities(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Floating Glass Action Bar
              Align(
                alignment: Alignment.bottomCenter,
                child: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.5)),
                      ),
                      child: GestureDetector(
                        onTap: _applyFilters,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: _primary, 
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: _primary.withOpacity(0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Apply Filters',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _handleClose,
                behavior: HitTestBehavior.opaque,
                child: const Icon(Icons.close_rounded, size: 28, color: _textDark),
              ),
              const SizedBox(width: 16),
              Text(
                'Filters',
                style: GoogleFonts.poppins(
                  fontSize: 28, 
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: _reset,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Reset',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: _textDark,
        ),
      );

  // Property Type Glass Pills
  Widget _buildPropertyTypes() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _propertyTypes.map((type) {
        final isSelected = _selectedType == type['name'];
        return GestureDetector(
          onTap: () => setState(() => _selectedType = type['name'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.only(left: 6, right: 16, top: 6, bottom: 6),
            decoration: BoxDecoration(
              color: isSelected ? _primary : Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isSelected ? _primary : Colors.white.withOpacity(0.8), 
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withOpacity(0.2) : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    type['icon'] as IconData,
                    size: 18,
                    color: isSelected ? Colors.white : _textLight,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  type['name'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : _textDark,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPriceRange() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ksh. ${_priceRange.start.toInt()}',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _primary,
              ),
            ),
            Text(
              'Ksh. ${_priceRange.end.toInt()}${_priceRange.end >= 200000 ? '+' : ''}',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 12),
            activeTrackColor: _primary,
            inactiveTrackColor: Colors.white.withOpacity(0.8),
            thumbColor: Colors.white,
            trackHeight: 6,
            overlayColor: _primary.withOpacity(0.2),
          ),
          child: RangeSlider(
            values: _priceRange,
            min: 10000,
            max: 200000,
            onChanged: (values) => setState(() => _priceRange = values),
          ),
        ),
      ],
    );
  }

  Widget _buildAmenities() {
    return Column(
      children: _amenities.asMap().entries.map((entry) {
        final int index = entry.key;
        final String amenity = entry.value;
        final isSelected = _selectedAmenities.contains(amenity);
        
        return GestureDetector(
          onTap: () => _toggleAmenity(amenity),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.only(bottom: index == _amenities.length - 1 ? 0 : 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_getAmenityIcon(amenity), size: 18, color: _primary),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      amenity,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _textDark,
                      ),
                    ),
                  ],
                ),
                // Modern Circular Checkbox
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? _primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? _primary : _textLight.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                      : null,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getAmenityIcon(String amenity) {
    switch (amenity) {
      case 'WiFi':
        return PhosphorIcons.wifiHigh();
      case 'Water included':
        return PhosphorIcons.drop();
      case 'Electricity included':
        return PhosphorIcons.lightning();
      case 'Furnished':
        return PhosphorIcons.armchair();
      case 'Parking':
        return PhosphorIcons.car();
      case 'Security':
        return PhosphorIcons.shieldCheck();
      case 'CCTV':
        return PhosphorIcons.videoCamera();
      default:
        return PhosphorIcons.checkCircle();
    }
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

  const _GlassContainer({
    required this.child,
    required this.padding,
    this.borderRadius,
    this.blur = 20.0,
    this.opacity = 0.55,
    this.borderWidth = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(24);

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