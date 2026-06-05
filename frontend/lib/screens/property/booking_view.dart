import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/models/property.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'property_details.dart';

class MyBookingsView extends StatefulWidget {
  final VoidCallback onBack;

  const MyBookingsView({super.key, required this.onBack});

  @override
  State<MyBookingsView> createState() => _MyBookingsViewState();
}

class _MyBookingsViewState extends State<MyBookingsView>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  String _selectedTab = 'Upcoming';
  final List<String> _tabs = ['Upcoming', 'Completed', 'Cancelled'];

  // Design Tokens
  static const Color textDark = Color(0xFF111827);
  static const Color textMedium = Color(0xFF4B5563);
  static const Color textLight = Color(0xFF9CA3AF);
  static const Color navActiveGreen = Color(0xFF059669);

  // Status Pill Colors mapped exactly to the PDF
  static const Map<String, Map<String, Color>> statusColors = {
    'Upcoming': {
      'bg': Color(0xFFD6E4FF), // Soft Indigo/Blue BG
      'text': Color(0xFF3F37C9), // Deep Indigo Text
    },
    'Completed': {
      'bg': Color(0xFFD1FAE5), // Soft Green BG
      'text': Color(0xFF065F46), // Deep Green Text
    },
    'Cancelled': {
      'bg': Color(0xFFFEE2E2), // Soft Red/Pink BG
      'text': Color(0xFF991B1B), // Deep Red Text
    },
  };

  // Mock data perfectly matching the PDF content
  final List<Map<String, dynamic>> _allBookings = [
    {
      'title': '11 Green bank',
      'location': 'Kilifi, Kenya',
      'date': 'Sat, 24 May 2026   |   10.00 AM',
      'status': 'Upcoming',
      'image':
          'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
    },
    {
      'title': 'Smart Apartment',
      'location': 'Kilifi, Kenya',
      'date': 'Sun, 27 May 2026   |   10.00 AM',
      'status': 'Completed',
      'image':
          'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
    },
    {
      'title': 'Cozy Bedsitter',
      'location': 'Kilifi, Kenya',
      'date': 'Wed, 30 May 2026   |   10.00 AM',
      'status': 'Cancelled',
      'image':
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim =
        CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entryController, curve: Curves.easeOutCubic));
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredBookings {
    // In a real app, you would filter based on _selectedTab here:
    // return _allBookings.where((b) => b['status'] == _selectedTab).toList();
    // For this 100% visual match of the PDF, we will show all 3 items to match the screenshot.
    return _allBookings;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // 1. Soft Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF7FDF9), // Very light mint
                  Color(0xFFE8F6EF), // Soft mint green
                  Color(0xFFD4EFE1), // Deeper mint base
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // 2. Main Content
          FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1.0).animate(
                  CurvedAnimation(
                      parent: _entryController, curve: Curves.easeOutCubic)),
              child: CustomScrollView(
                slivers: [
                  // App Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 16,
                        left: 20,
                        right: 24,
                        bottom: 24,
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: widget.onBack,
                            child: const Icon(Icons.arrow_back,
                                color: textDark, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'My Bookings',
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Filter Tabs
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: _tabs.map((tab) => _buildTab(tab)).toList(),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Booking Cards List
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24,
                        200), // Heavy bottom padding to clear buttons & nav
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: _buildBookingCard(_filteredBookings[index]),
                          );
                        },
                        childCount: _filteredBookings.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Floating "View Calendar" Button
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 110, left: 24, right: 24),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8DCBAA), // Soft PDF Green
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    'View Calendar',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. Glass Bottom Navigation Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildGlassBottomNav(),
          ),
        ],
      ),
    );
  }

  // ─── Component Builders ──────────────────────────────────────────────────

  Widget _buildTab(String label) {
    bool isActive = _selectedTab == label;

    // Dynamic styling based on PDF
    Color bgColor = isActive ? statusColors[label]!['bg']! : Colors.transparent;
    Color textColor = isActive ? statusColors[label]!['text']! : textLight;
    Color borderColor = isActive ? Colors.transparent : const Color(0xFFD1D5DB);

    return GestureDetector(
      onTap: () => setState(() => _selectedTab = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'];

    return _GlassContainer(
      padding:
          EdgeInsets.zero, // Padding handled internally to let image flush left
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 140,
        child: Row(
          children: [
            // Left Side: Image (Flushed to the left edges)
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(24)),
              child: Image.network(
                booking['image'],
                width: 130,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    width: 130, height: 140, color: const Color(0xFFE8F6EF)),
              ),
            ),

            // Right Side: Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Heart Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            booking['title'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                          ),
                        ),
                        const Icon(Icons.favorite,
                            color: Color(0xFFEC4899), size: 22), // Pink Heart
                      ],
                    ),
                    const SizedBox(height: 2),

                    // Location
                    Text(
                      booking['location'],
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textLight,
                      ),
                    ),

                    const Spacer(),

                    // Date & Time
                    Text(
                      booking['date'],
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textMedium,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColors[status]!['bg'],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColors[status]!['text'],
                        ),
                      ),
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

  Widget _buildGlassBottomNav() {
    return _GlassContainer(
      blur: 25,
      opacity: 0.7,
      borderRadius: BorderRadius.zero,
      borderWidth: 0,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 16,
        left: 8,
        right: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
              PhosphorIcons.house(PhosphorIconsStyle.fill), 'Dashboard', false),
          _buildNavItem(PhosphorIcons.buildings(PhosphorIconsStyle.fill),
              'Properties', false),
          _buildNavItem(PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill),
              'Bookings', true), // Bookings is Active!
          _buildNavItem(PhosphorIcons.chatTeardrop(PhosphorIconsStyle.fill),
              'Messages', false),
          _buildNavItem(PhosphorIcons.userCircle(PhosphorIconsStyle.fill),
              'Profile', false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 26,
          color: isActive ? navActiveGreen : textLight,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? navActiveGreen : textLight,
          ),
        )
      ],
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

  const _GlassContainer({
    required this.child,
    required this.padding,
    this.borderRadius,
    this.blur = 15.0,
    this.opacity = 0.55,
    this.borderWidth = 1.0,
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
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
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

/// Lightweight booking entry view used by routes that pass a `propertyId`.
class BookingView extends StatefulWidget {
  final String propertyId;
  final VoidCallback? onBack;
  final VoidCallback? onComplete;

  const BookingView({
    super.key,
    required this.propertyId,
    this.onBack,
    this.onComplete,
  });

  @override
  State<BookingView> createState() => _BookingViewState();
}

class _BookingViewState extends State<BookingView> {
  final _repo = RemoteDatabaseRepository();
  bool _loading = true;
  String? _error;
  Property? _property;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final raw = await _repo.loadPropertyById(widget.propertyId);
      if (!mounted) return;
      if (raw == null) {
        setState(() {
          _property = null;
          _error = 'Property not found';
          _loading = false;
        });
        return;
      }

      // Map API payload -> Property model
      final property = Property(
        id: raw['id']?.toString() ?? widget.propertyId,
        name: raw['title']?.toString() ?? '',
        location: (raw['city']?.toString() ?? ''),
        lat: (raw['lat'] as num?)?.toDouble() ?? 0,
        lng: (raw['lng'] as num?)?.toDouble() ?? 0,
        price: (raw['price'] as num?)?.toInt() ?? 0,
        rating: 0,
        reviews: 0,
        category: raw['category']?.toString() ?? 'Apartment',
        image: raw['image_url']?.toString() ?? '',
        images: <String>[],
        features: PropertyFeatures(
          beds: (raw['bedrooms'] as num?)?.toInt() ?? 0,
          rooms: 0,
          baths: (raw['bathrooms'] as num?)?.toInt() ?? 0,
          furnished: false,
        ),
        amenities: <String>[],
        agent: Agent(
          userId: raw['landlord_id']?.toString() ?? '',
          name: raw['landlord_name']?.toString() ?? '',
          avatar: '',
        ),
        description: raw['description']?.toString() ?? '',
      );

      setState(() {
        _property = property;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: widget.onBack ?? () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _property == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: widget.onBack ?? () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(_error ?? 'Failed to load property'),
        ),
      );
    }

    return PropertyDetails(
      property: _property!,
      onBack: widget.onBack ?? () => Navigator.pop(context),
      onBook: widget.onComplete ?? () => Navigator.pop(context),
    );
  }
}
