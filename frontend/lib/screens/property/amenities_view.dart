import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFFF8F9FA);

// ─── Data models ──────────────────────────────────────────────────────────────

class _EssentialAmenity {
  final IconData icon;
  final String title;
  final Color iconColor;
  final Color bgColor;
  const _EssentialAmenity(this.icon, this.title, this.iconColor, this.bgColor);
}

class _AdditionalAmenity {
  final IconData icon;
  final String title;
  const _AdditionalAmenity(this.icon, this.title);
}

// ─── Main Widget ──────────────────────────────────────────────────────────────

class AmenitiesView extends StatefulWidget {
  final VoidCallback onClose;

  const AmenitiesView({super.key, required this.onClose});

  @override
  State<AmenitiesView> createState() => _AmenitiesViewState();
}

class _AmenitiesViewState extends State<AmenitiesView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _pageSlideAnim;
  late final Animation<double> _pageFadeAnim;

  static const _essentialItems = [
    _EssentialAmenity(
        Icons.wifi, 'WIFI', Color(0xFF3B82F6), Color(0xFFEFF6FF)),
    _EssentialAmenity(
        Icons.water_drop_outlined, 'water', Color(0xFF3B82F6), Color(0xFFEFF6FF)),
    _EssentialAmenity(
        Icons.local_parking_outlined, 'Parking', Color(0xFF22C55E), Color(0xFFF0FDF4)),
    _EssentialAmenity(
        Icons.lock_outline, 'Security', Color(0xFF3B82F6), Color(0xFFEFF6FF)),
    _EssentialAmenity(
        Icons.bolt, 'Electricity\nincluded', Color(0xFFF59E0B), Color(0xFFFFFBEB)),
    _EssentialAmenity(
        Icons.videocam_outlined, 'CCTV', Color(0xFFEF4444), Color(0xFFFEF2F2)),
  ];

  static const _additionalItems = [
    _AdditionalAmenity(Icons.balcony, 'Balcony'),
    _AdditionalAmenity(Icons.kitchen, 'Shared Kitchen'),
    _AdditionalAmenity(Icons.bathtub_outlined, 'Ensuit Bathroom'),
    _AdditionalAmenity(Icons.waves, 'Borehole Water'),
    _AdditionalAmenity(Icons.local_laundry_service_outlined, 'Laundry Area'),
    _AdditionalAmenity(Icons.fitness_center, 'Gym Access'),
    _AdditionalAmenity(Icons.shield_outlined, 'Security Guards'),
  ];

  @override
  void initState() {
    super.initState();
    // Extended duration to allow all nested staggered animations to play out beautifully
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // The primary page slide animation
    _pageSlideAnim = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutQuart),
    ));

    // The primary page fade animation
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

  /// Helper to create a smooth staggered fade and upward slide for list items
  Widget _buildStaggeredChild({
    required Widget child,
    required int index,
    required double startInterval,
  }) {
    // Calculates a delayed start time based on the index position
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
          begin: const Offset(0, 0.15), // Slight upward slide
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 112),
                  physics: const BouncingScrollPhysics(), // Smoother scrolling behavior
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      
                      _buildStaggeredChild(
                        index: 0,
                        startInterval: 0.15,
                        child: _buildSectionTitle('Essentials'),
                      ),
                      
                      const SizedBox(height: 24),
                      _buildEssentialGrid(),
                      const SizedBox(height: 48),
                      
                      _buildStaggeredChild(
                        index: 0,
                        startInterval: 0.4,
                        child: _buildSectionTitle('Additional'),
                      ),
                      
                      const SizedBox(height: 32),
                      _buildAdditionalList(),
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

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 24,
        bottom: 24,
        left: 16, // Adjusted slightly for the icon button padding
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

  // ─── Section Title ──────────────────────────────────────────────────────────

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

  // ─── Essential Grid ─────────────────────────────────────────────────────────

  Widget _buildEssentialGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 0,
        runSpacing: 28,
        children: _essentialItems.asMap().entries.map((entry) {
          final int index = entry.key;
          final _EssentialAmenity item = entry.value;
          
          return _buildStaggeredChild(
            index: index,
            startInterval: 0.2, // Essentials cascade start time
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

  // ─── Additional List ────────────────────────────────────────────────────────

  Widget _buildAdditionalList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: _additionalItems.asMap().entries.map((entry) {
          final int index = entry.key;
          final _AdditionalAmenity item = entry.value;
          
          return _buildStaggeredChild(
            index: index,
            startInterval: 0.45, // Additional list cascade start time
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Row(
                children: [
                  Icon(item.icon, color: const Color(0xFF9CA3AF), size: 30),
                  const SizedBox(width: 20),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
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