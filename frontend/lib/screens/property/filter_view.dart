import 'package:flutter/material.dart';
import 'package:property_app/app_theme.dart';
import 'package:property_app/widgets/shared.dart';

Color get _primary => AppTheme.primary;
Color get _bgColor => AppTheme.background;

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
        vsync: this, duration: const Duration(milliseconds: 300));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _animController, curve: Curves.easeOut));
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

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Scaffold(
          backgroundColor: _bgColor,
          body: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel('Property Type'),
                          const SizedBox(height: 16),
                          _buildPropertyTypes(),
                          const SizedBox(height: 32),
                          _buildSectionLabel('Price Range'),
                          const SizedBox(height: 20),
                          _buildPriceRange(),
                          const SizedBox(height: 32),
                          _buildSectionLabel('Amenities'),
                          const SizedBox(height: 16),
                          _buildAmenities(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                  bottom: 0, left: 0, right: 0, child: _buildApplyButton()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 16,
        left: 24,
        right: 24,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Filters',
            style: TextStyle(
              fontSize: 36, // As requested
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
              letterSpacing: -1.0,
            ),
          ),
          GestureDetector(
            onTap: _reset,
            child: Text(
              'Reset',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: _primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827)),
      );

  // Property Type Pills with Circle Icons
  Widget _buildPropertyTypes() {
    return Wrap(
      spacing: 10,
      runSpacing: 12,
      children: _propertyTypes.map((type) {
        final isSelected = _selectedType == type['name'];
        return PropertyPill(
          label: type['name'] as String,
          icon: type['icon'] as IconData,
          selected: isSelected,
          onTap: () => setState(() => _selectedType = type['name'] as String),
        );
      }).toList(),
    );
  }

  Widget _buildPriceRange() {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            rangeThumbShape:
                const RoundRangeSliderThumbShape(enabledThumbRadius: 11),
            activeTrackColor: _primary,
            inactiveTrackColor: const Color(0xFFE5E7EB),
            trackHeight: 6,
          ),
          child: RangeSlider(
            values: _priceRange,
            min: 10000,
            max: 200000,
            onChanged: (values) => setState(() => _priceRange = values),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Ksh. ${_priceRange.start.toInt()}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
                'Ksh. ${_priceRange.end.toInt()}${_priceRange.end >= 200000 ? '+' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _buildAmenities() {
    return Column(
      children: _amenities.map((amenity) {
        final isSelected = _selectedAmenities.contains(amenity);
        return GestureDetector(
          onTap: () => _toggleAmenity(amenity),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(_getAmenityIcon(amenity),
                        size: 24, color: const Color(0xFF4B5563)),
                    const SizedBox(width: 14),
                    Text(
                      amenity,
                      style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151)),
                    ),
                  ],
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isSelected ? _primary : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isSelected ? _primary : const Color(0xFFD1D5DB),
                        width: 2),
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
      }).toList(),
    );
  }

  IconData _getAmenityIcon(String amenity) {
    switch (amenity) {
      case 'WiFi':
        return Icons.wifi;
      case 'Water included':
        return Icons.water_drop_outlined;
      case 'Electricity included':
        return Icons.electric_bolt;
      case 'Furnished':
        return Icons.chair_alt;
      case 'Parking':
        return Icons.local_parking;
      case 'Security':
        return Icons.security;
      case 'CCTV':
        return Icons.videocam_outlined;
      default:
        return Icons.check_circle_outline;
    }
  }

  Widget _buildApplyButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -10))
        ],
      ),
      child: GestureDetector(
        onTap: _applyFilters,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
              color: _primary, borderRadius: BorderRadius.circular(16)),
          alignment: Alignment.center,
          child: Text(
            'Apply Filters',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
