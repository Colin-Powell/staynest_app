import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
// Note: Keep your specific project imports here
// import 'package:property_app/app_theme.dart'; 

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

class _FilterViewState extends State<FilterView> {
  // Colors
  static const Color _primary = Color(0xFF3F37C9); // Tenant Blue Accent
  static const Color _textDark = Color(0xFF111827); // Dark Grey/Black Accent
  static const Color _textLight = Color(0xFF6B7280);

  String _selectedType = 'Apartment';
  RangeValues _priceRange = const RangeValues(10000, 200000);
  final Set<String> _selectedAmenities = {'WiFi', 'Furnished'};
  int _selectedBeds = 0;
  int _selectedBaths = 0;
  String _landlordAvailability = 'Any';
  bool _mostReviews = false;
  bool _showAllAmenities = false;

  // Dummy distribution data for the histogram (values between 0.0 and 1.0)
  final List<double> _priceDistribution = [
    0.1, 0.2, 0.4, 0.7, 0.9, 1.0, 0.8, 0.6, 0.5, 
    0.4, 0.3, 0.5, 0.4, 0.2, 0.1, 0.05, 0.05, 0.1
  ];

  static const _propertyTypes = [
    {'name': 'Apartment', 'image': 'assets/images/apartments.webp'},
    {'name': 'Bedsitter', 'image': 'assets/images/bedsitter.webp'},
    {'name': 'Single', 'image': 'assets/images/singleroom.webp'},
    {'name': 'One Bedroom', 'image': 'assets/images/onebedroom.webp'},
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

  void _reset() {
    setState(() {
      _selectedType = 'Apartment';
      _priceRange = const RangeValues(10000, 200000);
      _selectedAmenities.clear();
      _selectedBeds = 0;
      _selectedBaths = 0;
      _landlordAvailability = 'Any';
      _mostReviews = false;
      _selectedAmenities.addAll(['WiFi', 'Furnished']);
    });
  }

  void _applyFilters() {
    final filters = {
      'propertyType': _selectedType,
      'minPrice': _priceRange.start,
      'maxPrice': _priceRange.end,
      'amenities': _selectedAmenities.toList(),
      'beds': _selectedBeds,
      'baths': _selectedBaths,
      'landlordAvailability': _landlordAvailability,
      'mostReviews': _mostReviews,
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
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Stack(
          children: [
            // Main Scrolling Content
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                          24, 24, 24, 140), // Increased top clearance
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Property Type Section
                          _buildSectionLabel('Property Type'),
                          const SizedBox(height: 24),
                          _buildPropertyTypes(),

                          const SizedBox(height: 48),

                          // Price Range Section (Card background removed)
                          _buildSectionLabel('Price Range (Monthly)'),
                          const SizedBox(height: 24),
                          _buildPriceRange(),

                          const SizedBox(height: 48),

                          // Amenities Section
                          _buildSectionLabel('Amenities'),
                          const SizedBox(height: 24),
                          _GlassContainer(
                            padding: const EdgeInsets.all(24),
                            child: _buildAmenities(),
                          ),

                          const SizedBox(height: 48),
                          _buildSectionLabel('Rooms'),
                          const SizedBox(height: 24),
                          _buildRooms(),

                          const SizedBox(height: 48),
                          _buildSectionLabel('Host Details'),
                          const SizedBox(height: 24),
                          _buildHostDetails(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Floating Glass Action Bar (Updated with Clear Button)
            Align(
              alignment: Alignment.bottomCenter,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(24, 16, 24,
                        MediaQuery.of(context).padding.bottom + 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      border: Border(
                          top: BorderSide(
                              color: Colors.white.withOpacity(0.8),
                              width: 1.5)),
                    ),
                    child: Row(
                      children: [
                        // Clear Button
                        GestureDetector(
                          onTap: _reset,
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _textDark,
                                width: 2, // Black stroke border
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Clear',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _textDark,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Apply Filters Button
                        Expanded(
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

  Widget _buildHeader() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: _handleClose,
                behavior: HitTestBehavior.opaque,
                child: const Icon(Icons.close_rounded,
                    size: 28, color: _textDark),
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
        ),
      ],
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

  // Property Type Glass Pills (Updated with border highlight)
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
            padding:
                const EdgeInsets.only(left: 6, right: 16, top: 6, bottom: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6), // Always a clear/light background
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isSelected ? _textDark : Colors.white.withOpacity(0.8), // Highlighted border
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
                    border: Border.all(
                      color: isSelected
                          ? _textDark.withOpacity(0.2)
                          : Colors.transparent,
                      width: 2,
                    ),
                    image: DecorationImage(
                      image: AssetImage(type['image'] as String),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  type['name'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textDark, // Text stays dark
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // Price Range (Updated to move texts below slider & reduce stroke)
  Widget _buildPriceRange() {
    return Column(
      children: [
        // Graphical Chart (Histogram)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SizedBox(
            height: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_priceDistribution.length, (index) {
                // Calculate the price point this bar represents
                final double percent = index / (_priceDistribution.length - 1);
                final double priceAtBar = 10000 + (percent * (200000 - 10000));
                
                // Highlight if within selected range
                final bool inRange = priceAtBar >= _priceRange.start && priceAtBar <= _priceRange.end;

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    height: 40 * _priceDistribution[index],
                    decoration: BoxDecoration(
                      color: inRange ? _primary.withOpacity(0.7) : _textLight.withOpacity(0.2),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        
        // Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            rangeThumbShape:
                const RoundRangeSliderThumbShape(enabledThumbRadius: 12),
            activeTrackColor: _primary, 
            inactiveTrackColor: Colors.grey.withOpacity(0.2),
            thumbColor: Colors.white,
            trackHeight: 3, // Reduced from 6 to make stroke size thinner
            overlayColor: _primary.withOpacity(0.2),
          ),
          child: RangeSlider(
            values: _priceRange,
            min: 10000,
            max: 200000,
            onChanged: (values) => setState(() => _priceRange = values),
          ),
        ),
        
        const SizedBox(height: 8),

        // Prices shifted underneath the slider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ksh. ${_priceRange.start.toInt()}',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              Text(
                'Ksh. ${_priceRange.end.toInt()}${_priceRange.end >= 200000 ? '+' : ''}',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textDark, 
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmenities() {
    final displayCount = _showAllAmenities ? _amenities.length : 3;
    final displayedAmenities = _amenities.take(displayCount).toList();

    return Column(
      children: [
        ...displayedAmenities.asMap().entries.map((entry) {
          final int index = entry.key;
          final String amenity = entry.value;
          final isSelected = _selectedAmenities.contains(amenity);

          return GestureDetector(
            onTap: () => _toggleAmenity(amenity),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: index == displayedAmenities.length - 1 ? 0 : 32), // Increased spacing
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_getAmenityIcon(amenity),
                            size: 20, color: _textDark), 
                      ),
                      const SizedBox(width: 16),
                      Text(
                        amenity,
                        style: GoogleFonts.poppins(
                          fontSize: 16, // slightly larger
                          fontWeight: FontWeight.w600,
                          color: _textDark,
                        ),
                      ),
                    ],
                  ),
                  // Modern Circular Checkbox (Grey/Black accent)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isSelected ? _textDark : Colors.transparent, 
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            isSelected ? _textDark : _textLight.withValues(alpha: 0.5), 
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 18)
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),
        if (_amenities.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 32), // plenty of whitespace before button
            child: GestureDetector(
              onTap: () => setState(() => _showAllAmenities = !_showAllAmenities),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _showAllAmenities ? 'Show less' : 'View all amenities',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _showAllAmenities ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: _textDark,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRooms() {
    return Column(
      children: [
        _buildRoomRow('Beds', _selectedBeds, (val) => setState(() => _selectedBeds = val)),
        const SizedBox(height: 24),
        _buildRoomRow('Bathrooms', _selectedBaths, (val) => setState(() => _selectedBaths = val)),
      ],
    );
  }

  Widget _buildRoomRow(String title, int selectedValue, ValueChanged<int> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: _textDark)),
        Row(
          children: List.generate(6, (index) {
            final isSelected = selectedValue == index;
            final label = index == 0 ? 'Any' : (index == 5 ? '5+' : '$index');
            return GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(left: 6),
                width: index == 0 ? 46 : 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? _textDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isSelected ? _textDark : _textLight.withOpacity(0.3)),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : _textDark,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildHostDetails() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Most Reviews', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: _textDark)),
            Switch(
              value: _mostReviews,
              activeColor: _primary,
              onChanged: (val) => setState(() => _mostReviews = val),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Landlord Availability', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: _textDark)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ['Any', 'Superhost', 'New', 'Online'].map((status) {
                final isSelected = _landlordAvailability == status;
                return GestureDetector(
                  onTap: () => setState(() => _landlordAvailability = status),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? _textDark : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? _textDark : _textLight.withOpacity(0.3)),
                    ),
                    child: Text(
                      status,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : _textDark,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ],
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
    this.padding = EdgeInsets.zero,
    this.borderRadius,
    this.blur = 24,
    this.opacity = 0.20,
    this.borderWidth = 1.2,
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