import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFFF8F9FA);

class _AmenityDisplay {
  final IconData icon;
  final String title;
  final Color iconColor;
  final Color bgColor;

  const _AmenityDisplay(
    this.icon,
    this.title, {
    this.iconColor = const Color(0xFF3B82F6),
    this.bgColor = const Color(0xFFEFF6FF),
  });
}

const _essentialKeys = {
  'wifi',
  'water',
  'parking',
  'security',
  'electricity',
  'cctv',
  'heating',
  'air conditioning',
  'hot water',
};

_AmenityDisplay _amenityDisplayFor(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('wifi')) {
    return _AmenityDisplay(Icons.wifi, name,
        iconColor: const Color(0xFF3B82F6), bgColor: const Color(0xFFEFF6FF));
  }
  if (lower.contains('water')) {
    return _AmenityDisplay(Icons.water_drop_outlined, name,
        iconColor: const Color(0xFF3B82F6), bgColor: const Color(0xFFEFF6FF));
  }
  if (lower.contains('parking') || lower.contains('car')) {
    return _AmenityDisplay(Icons.local_parking_outlined, name,
        iconColor: const Color(0xFF22C55E), bgColor: const Color(0xFFF0FDF4));
  }
  if (lower.contains('security') || lower.contains('guard')) {
    return _AmenityDisplay(Icons.lock_outline, name,
        iconColor: const Color(0xFF3B82F6), bgColor: const Color(0xFFEFF6FF));
  }
  if (lower.contains('electric')) {
    return _AmenityDisplay(Icons.bolt, name,
        iconColor: const Color(0xFFF59E0B), bgColor: const Color(0xFFFFFBEB));
  }
  if (lower.contains('cctv') || lower.contains('camera')) {
    return _AmenityDisplay(Icons.videocam_outlined, name,
        iconColor: const Color(0xFFEF4444), bgColor: const Color(0xFFFEF2F2));
  }
  if (lower.contains('gym') || lower.contains('fitness')) {
    return _AmenityDisplay(Icons.fitness_center, name);
  }
  if (lower.contains('pool') || lower.contains('swim')) {
    return _AmenityDisplay(Icons.pool, name);
  }
  if (lower.contains('furnish')) {
    return _AmenityDisplay(Icons.weekend_outlined, name);
  }
  if (lower.contains('laundry') || lower.contains('washer')) {
    return _AmenityDisplay(Icons.local_laundry_service_outlined, name);
  }
  if (lower.contains('balcony') || lower.contains('patio')) {
    return _AmenityDisplay(Icons.balcony, name);
  }
  if (lower.contains('kitchen')) {
    return _AmenityDisplay(Icons.kitchen, name);
  }
  if (lower.contains('pet')) {
    return _AmenityDisplay(Icons.pets, name);
  }
  if (lower.contains('elevator')) {
    return _AmenityDisplay(Icons.elevator, name);
  }
  if (lower.contains('generator') || lower.contains('backup')) {
    return _AmenityDisplay(Icons.battery_charging_full, name);
  }
  return _AmenityDisplay(Icons.check_circle_outline, name);
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

  List<_AmenityDisplay> get _essentialItems => widget.amenities
      .where(_isEssential)
      .map(_amenityDisplayFor)
      .toList();

  List<_AmenityDisplay> get _additionalItems => widget.amenities
      .where((a) => !_isEssential(a))
      .map(_amenityDisplayFor)
      .toList();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pageSlideAnim = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutQuart),
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
      curve: Interval(start, end, curve: Curves.easeOutQuart),
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

    return SlideTransition(
      position: _pageSlideAnim,
      child: FadeTransition(
        opacity: _pageFadeAnim,
        child: Scaffold(
          backgroundColor: _bgColor,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStaggeredChild(
                index: 0,
                startInterval: 0.1,
                child: _buildHeader(context),
              ),
              Expanded(
                child: !hasAmenities
                    ? const Center(
                        child: Text(
                          'No amenities listed for this property.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 112),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            if (_essentialItems.isNotEmpty) ...[
                              _buildStaggeredChild(
                                index: 0,
                                startInterval: 0.15,
                                child: _buildSectionTitle('Essentials'),
                              ),
                              const SizedBox(height: 24),
                              _buildEssentialGrid(),
                              const SizedBox(height: 48),
                            ],
                            if (_additionalItems.isNotEmpty) ...[
                              _buildStaggeredChild(
                                index: 0,
                                startInterval: 0.4,
                                child: _buildSectionTitle('Additional'),
                              ),
                              const SizedBox(height: 32),
                              _buildAdditionalList(),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 24,
        bottom: 24,
        left: 16,
        right: 24,
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: widget.onClose,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.arrow_back, size: 28, color: Colors.black),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Amenities',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: Colors.black,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildEssentialGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 0,
        runSpacing: 28,
        children: _essentialItems.asMap().entries.map((entry) {
          final int index = entry.key;
          final _AmenityDisplay item = entry.value;

          return _buildStaggeredChild(
            index: index,
            startInterval: 0.2,
            child: SizedBox(
              width: (MediaQuery.of(context).size.width - 32) / 4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: item.bgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.icon, color: item.iconColor, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAdditionalList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: _additionalItems.asMap().entries.map((entry) {
          final int index = entry.key;
          final _AmenityDisplay item = entry.value;

          return _buildStaggeredChild(
            index: index,
            startInterval: 0.45,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Row(
                children: [
                  Icon(item.icon, color: const Color(0xFF9CA3AF), size: 30),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
