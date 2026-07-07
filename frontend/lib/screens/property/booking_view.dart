import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/models/property.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/screens/dashboard/analytics_service.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/services/booking_service.dart';
import 'package:property_app/utils/api_result.dart';

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

  bool _isLoading = true;
  List<Map<String, dynamic>> _allBookings = [];

  @override
  void initState() {
    super.initState();
    _loadBookings();
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

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      final data = await BookingService.fetchBookings(isLandlord: false);
      if (!mounted) return;
      setState(() {
        _allBookings = data
            .map((b) => {
                  'id': b['id']?.toString() ?? '',
                  'title': b['title']?.toString() ?? 'Property',
                  'location': b['city']?.toString() ?? '',
                  'date': b['check_in_date']?.toString().split('T')[0] ?? '',
                  'time': '10:00 AM',
                  'status': _mapStatus(b['status']?.toString() ?? ''),
                  'image': b['image_url']?.toString() ?? '',
                  'rating': (double.tryParse(
                              b['average_rating']?.toString() ?? '0') ??
                          0.0)
                      .toDouble(),
                  'reviews':
                      int.tryParse(b['review_count']?.toString() ?? '0') ?? 0,
                })
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapStatus(String apiStatus) {
    final s = apiStatus.toLowerCase();
    if (s == 'confirmed' || s == 'pending') return 'Upcoming';
    if (s == 'completed') return 'Completed';
    if (s == 'cancelled' || s == 'rejected') return 'Cancelled';
    return 'Upcoming';
  }

  List<Map<String, dynamic>> get _filteredBookings {
    return _allBookings.where((b) => b['status'] == _selectedTab).toList();
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
                        left: 24,
                        right: 24,
                        bottom: 24,
                      ),
                      child: Row(
                        children: [
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
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 200),
                    sliver: _isLoading
                        ? const SliverToBoxAdapter(
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: navActiveGreen),
                            ),
                          )
                        : _filteredBookings.isEmpty
                            ? SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 100),
                                  child: Center(
                                    child: Text(
                                      'No $_selectedTab bookings found.',
                                      style:
                                          GoogleFonts.poppins(color: textLight),
                                    ),
                                  ),
                                ),
                              )
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 24),
                                      child: _buildBookingCard(
                                          _filteredBookings[index]),
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
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 140,
        child: Row(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(24)),
              child: buildPropertyImage(
                booking['image'] ?? '',
                width: 130,
                height: 140,
                fit: BoxFit.cover,
                errorPlaceholder: Container(
                    width: 130, height: 140, color: const Color(0xFFE8F6EF)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            color: Color(0xFFEC4899), size: 22),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      booking['location'],
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if ((booking['reviews'] as int? ?? 0) > 0)
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: Color(0xFFFBBF24)),
                          const SizedBox(width: 2),
                          Text(
                            (booking['rating'] as double? ?? 0.0)
                                .toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                    const Spacer(),
                    Text(
                      booking['date'],
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textMedium,
                      ),
                    ),
                    const SizedBox(height: 6),
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
              'Bookings', true),
          _buildNavItem(PhosphorIcons.chatTeardrop(PhosphorIconsStyle.fill),
              'Messages', false),
          _buildNavItem(PhosphorIcons.userCircle(PhosphorIconsStyle.fill),
              'Profile', false,
              isProfile: true),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive,
      {bool isProfile = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isProfile)
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? navActiveGreen : Colors.transparent,
                width: 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: AppSession.buildAvatar(AppSession.currentUserAvatar),
          )
        else
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
/// Completely redesigned to match the "Book a Visit" PDF while keeping original methods intact.
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
  // Existing Data Logic / State Variables Maintained
  final _repo = RemoteDatabaseRepository();
  final _notesController = TextEditingController();
  bool _loading = true;
  String? _error;
  Property? _property;
  DateTimeRange? _selectedRange;
  bool _isSubmitting = false;

  // New Variables matching PDF visual states
  late DateTime _currentMonth;
  String _selectedTime = '10.00 AM';
  final List<String> _times = [
    '09.00 AM',
    '10.00 AM',
    '02.00 PM',
    '04.00 PM',
    '04.00PM' // Matching exact typo/spacing in the PDF
  ];

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    // Initialize _selectedRange implicitly so logic holds true.
    _selectedRange = DateTimeRange(
        start: DateTime.now(),
        end: DateTime.now().add(const Duration(days: 1)));
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // LOGIC INTACT: Existing Data Load Method
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final raw = await _repo.loadPropertyById(widget.propertyId);
      if (!mounted) return;

      // Map API payload -> Property model
      final property = Property(
        id: raw['id']?.toString() ?? widget.propertyId,
        name: raw['title']?.toString() ?? '',
        location: (raw['city']?.toString() ?? ''),
        lat: double.tryParse(raw['lat']?.toString() ?? '') ?? 0.0,
        lng: double.tryParse(raw['lng']?.toString() ?? '') ?? 0.0,
        price: (double.tryParse(raw['price']?.toString() ?? '') ?? 0).toInt(),
        rating:
            (double.tryParse(raw['average_rating']?.toString() ?? '0') ?? 0.0)
                .toDouble(),
        reviews: int.tryParse(raw['review_count']?.toString() ?? '0') ?? 0,
        category: raw['category']?.toString() ?? 'Apartment',
        image: raw['image_url']?.toString() ?? '',
        images: <String>[],
        features: PropertyFeatures(
          beds:
              (double.tryParse(raw['bedrooms']?.toString() ?? '') ?? 0).toInt(),
          rooms: 0,
          baths: (double.tryParse(raw['bathrooms']?.toString() ?? '') ?? 0)
              .toInt(),
          furnished: false,
        ),
        amenities: <String>[],
        agent: Agent(
          userId: raw['landlord_id']?.toString() ?? '',
          name: raw['landlord_name']?.toString() ?? '',
          avatar: raw['landlord_avatar']?.toString() ?? '',
        ),
        description: raw['description']?.toString() ?? '',
      );

      setState(() {
        _property = property;
        _loading = false;
      });

      AnalyticsService.trackPropertyView(widget.propertyId,
          source: 'booking_view');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiResult.mapError(e);
        _loading = false;
      });
    }
  }

  // LOGIC INTACT: Submitting Logic exactly as originally written
  Future<void> _submitBooking() async {
    if (_selectedRange == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    final nights = _selectedRange!.end.difference(_selectedRange!.start).inDays;
    final totalPrice = (nights > 0 ? nights : 1) * _property!.price.toDouble();

    final success = await BookingService.createBooking(
      propertyId: widget.propertyId,
      checkIn: _selectedRange!.start,
      checkOut: _selectedRange!.end,
      totalPrice: totalPrice,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BookingConfirmedPage(
              property: _property!,
              selectedDate: _selectedRange!.start,
              selectedTime: _selectedTime, // Pass the newly added time logic
            ),
          ),
        ).then((_) => widget.onComplete?.call());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Failed to submit booking. Please try different dates.')),
        );
      }
    }
  }

  // --- NEW UI MATCHING PDF ---

  Widget _buildDayCell(int day,
      {bool isCurrentMonth = true,
      bool isSelected = false,
      bool isBlue = false}) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF3B41E1) : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$day',
          style: GoogleFonts.poppins(
            color: isSelected
                ? Colors.white
                : (isCurrentMonth
                    ? const Color(0xFF111827)
                    : (isBlue
                        ? const Color(0xFF3B41E1)
                        : const Color(0xFF111827))),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    int daysInMonth =
        DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    DateTime firstDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month, 1);
    int firstWeekday = firstDayOfMonth.weekday; // 1 (Mon) to 7 (Sun)
    int offset = firstWeekday == 7 ? 0 : firstWeekday;

    DateTime prevMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    int daysInPrevMonth =
        DateUtils.getDaysInMonth(prevMonth.year, prevMonth.month);

    List<Widget> dayWidgets = [];
    const weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    for (var day in weekdays) {
      dayWidgets.add(
        Center(
          child: Text(
            day,
            style: GoogleFonts.poppins(
              color: const Color(0xFF9CA3AF),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    int totalCells = 42;
    for (int i = 0; i < totalCells; i++) {
      if (i < offset) {
        int day = daysInPrevMonth - offset + i + 1;
        dayWidgets.add(_buildDayCell(day, isCurrentMonth: false, isBlue: true));
      } else if (i >= offset + daysInMonth) {
        int day = i - (offset + daysInMonth) + 1;
        dayWidgets
            .add(_buildDayCell(day, isCurrentMonth: false, isBlue: false));
      } else {
        int day = i - offset + 1;
        DateTime thisDate =
            DateTime(_currentMonth.year, _currentMonth.month, day);
        bool isSelected = _selectedRange?.start.year == thisDate.year &&
            _selectedRange?.start.month == thisDate.month &&
            _selectedRange?.start.day == thisDate.day;

        dayWidgets.add(
          GestureDetector(
            onTap: () {
              setState(() {
                // Update _selectedRange to keep logic intact with the submit method
                _selectedRange = DateTimeRange(
                    start: thisDate,
                    end: thisDate.add(const Duration(days: 1)));
              });
            },
            child: _buildDayCell(day,
                isCurrentMonth: true, isSelected: isSelected),
          ),
        );
      }
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: dayWidgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F8FA),
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFF3B41E1))),
      );
    }

    if (_error != null || _property == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: Center(
          child: Text(_error ?? 'Failed to load property',
              style: GoogleFonts.poppins(color: Colors.black)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
          onPressed: widget.onBack ?? () => Navigator.pop(context),
        ),
        title: Text(
          'Book a Visit',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month Selector Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Color(0xFF9CA3AF), size: 20),
                          onPressed: () {
                            setState(() {
                              _currentMonth = DateTime(
                                  _currentMonth.year, _currentMonth.month - 1);
                            });
                          },
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(_currentMonth),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios,
                              color: Colors.black, size: 20),
                          onPressed: () {
                            setState(() {
                              _currentMonth = DateTime(
                                  _currentMonth.year, _currentMonth.month + 1);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Calendar Widget
                    _buildCalendar(),
                    const SizedBox(height: 24),

                    // Selected Date Text matching PDF
                    Text(
                      'Selected Date',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedRange != null
                          ? DateFormat('E, d MMM yyyy')
                              .format(_selectedRange!.start)
                          : 'No date selected',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Selected Time Pills matching PDF
                    Text(
                      'Selected Time',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _times.map((time) {
                        bool isSelected = _selectedTime == time;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedTime = time),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFF0F1FF)
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF3B41E1)
                                    : const Color(0xFFE5E7EB),
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              time,
                              style: GoogleFonts.poppins(
                                color: isSelected
                                    ? const Color(0xFF3B41E1)
                                    : Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Booking Status and Confirm Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedRange != null && !_isSubmitting)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Ready to schedule your visit for ${DateFormat('MMMM d').format(_selectedRange!.start)} at $_selectedTime',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3B41E1),
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: (_selectedRange == null || _isSubmitting)
                        ? null
                        : _submitBooking,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B41E1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                'Confirm Booking',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirmation Screen exactly matching the 'Booking Confirmed!' PDF
class BookingConfirmedPage extends StatelessWidget {
  final Property property;
  final DateTime selectedDate;
  final String selectedTime;

  const BookingConfirmedPage({
    super.key,
    required this.property,
    required this.selectedDate,
    required this.selectedTime,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Circular Green Checkmark
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF34A853),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 32),

              // Main Confirmation Text
              Text(
                'Booking Confirmed!',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your visit has been scheduled\nSuccessfully.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: const Color(0xFF6B7280),
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),

              // Custom Property Details Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: buildPropertyImage(
                        property.image,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            property.name,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${DateFormat('E, d MMM yyyy').format(selectedDate)}  |  $selectedTime',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration:
                                    const BoxDecoration(shape: BoxShape.circle),
                                clipBehavior: Clip.antiAlias,
                                child: AppSession.buildAvatar(
                                    property.agent.avatar),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                property.agent.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: const Color(0xFF6B7280),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Bottom Subtitle Text
              Text(
                'You will receive a reminder\nbefore your visit.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: const Color(0xFF9CA3AF),
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(),

              // View My Booking Blue Button
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(
                        0xFF3B41E1), // Matched precisely to PDF blue
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      'View My Booking',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
}
