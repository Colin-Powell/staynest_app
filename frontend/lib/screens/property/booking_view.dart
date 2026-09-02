import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uuid/uuid.dart';

import 'package:property_app/models/property.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/services/analytics/analytics_service.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/services/booking_service.dart';
import 'package:property_app/utils/api_result.dart';

// ─── Tenant Design System Constants ───────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _tenantPrimary = Color(0xFF3F37C9); // Tenant Blue Theme

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

  // Status Pill Colors mapped to the minimal Theme
  static const Map<String, Map<String, Color>> statusColors = {
    'Upcoming': {
      'bg': Color(0xFFEEF2FF), // Soft Blue BG
      'text': Color(0xFF3B82F6), // Deep Blue Text
    },
    'Completed': {
      'bg': Color(0xFFD1FAE5), // Soft Green BG
      'text': Color(0xFF059669), // Deep Green Text
    },
    'Cancelled': {
      'bg': Color(0xFFFEF2F2), // Soft Red BG
      'text': Color(0xFFEF4444), // Deep Red Text
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
                  'date':
                      _formatDateString(b['check_in_date']?.toString() ?? ''),
                  'time':
                      '10:00 AM', // API expansion needed to map actual times
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

  String _formatDateString(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr.split('T')[0]);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (_) {
      return dateStr.split('T')[0];
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

  // ─── UI BUILDERS ────────────────────────────────────────────────────────────

  Widget _buildTab(String label) {
    final bool isActive = _selectedTab == label;

    return GestureDetector(
      onTap: () {
        if (_selectedTab == label) return;
        setState(() => _selectedTab = label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _tenantPrimary : _surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isActive ? _tenantPrimary : _grey.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? _surface : _dark,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
          24, 0, 24, MediaQuery.of(context).padding.bottom + 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _grey.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Shimmer.fromColors(
                      baseColor: Colors.grey.shade200,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                        width: 120,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.horizontal(
                              left: Radius.circular(20)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Shimmer.fromColors(
                              baseColor: Colors.grey.shade200,
                              highlightColor: Colors.grey.shade100,
                              child: Container(
                                  width: double.infinity,
                                  height: 16,
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4))),
                            ),
                            const SizedBox(height: 8),
                            Shimmer.fromColors(
                              baseColor: Colors.grey.shade200,
                              highlightColor: Colors.grey.shade100,
                              child: Container(
                                  width: 100,
                                  height: 12,
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4))),
                            ),
                            const Spacer(),
                            Shimmer.fromColors(
                              baseColor: Colors.grey.shade200,
                              highlightColor: Colors.grey.shade100,
                              child: Container(
                                  width: 140,
                                  height: 14,
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4))),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: 4,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: _grey.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(PhosphorIconsRegular.calendarSlash,
                  size: 48, color: _grey),
            ),
            const SizedBox(height: 24),
            Text(
              'No $_selectedTab bookings',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your reservations will appear here once confirmed by the host.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: _grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] as String? ?? 'Upcoming';
    final statusColor =
        statusColors[status]?['text'] ?? const Color(0xFF3B82F6);
    final statusBg = statusColors[status]?['bg'] ?? const Color(0xFFEEF2FF);

    return Container(
      height: 120, // Tighter height for cleaner aesthetic
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Flush Image on the left
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
            child: buildPropertyImage(
              booking['image'] ?? '',
              width: 120,
              height: double.infinity,
              fit: BoxFit.cover,
              errorPlaceholder: Container(
                width: 120,
                height: double.infinity,
                color: _grey.withOpacity(0.1),
                child: const Icon(PhosphorIconsRegular.house,
                    color: _grey, size: 32),
              ),
            ),
          ),

          // Details on the right
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          booking['title'] ?? 'Property',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Small Heart Icon placeholder
                      const Icon(PhosphorIconsFill.heart,
                          color: Color(0xFFEC4899), size: 18),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(PhosphorIconsRegular.mapPin,
                          size: 12, color: _grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          booking['location'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking['date'],
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _dark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            booking['time'],
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _grey,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _slideAnim.drive(Tween<double>(begin: 0.98, end: 1.0)),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ─── Header ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Text(
                      'My Bookings',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),

                // ─── Filter Tabs ───
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _tabs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _buildTab(_tabs[index]),
                        );
                      },
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ─── Body ───
                if (_isLoading)
                  _buildShimmerLoading()
                else if (_filteredBookings.isEmpty)
                  _buildEmptyState()
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                        24, 0, 24, MediaQuery.of(context).padding.bottom + 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
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
      ),
    );
  }
}

/// ─── Booking View (Create Booking Flow) ──────────────────────────────────────
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
  final _notesController = TextEditingController();

  bool _loading = true;
  String? _error;
  Property? _property;
  DateTimeRange? _selectedRange;
  bool _isSubmitting = false;

  late DateTime _currentMonth;
  String _selectedTime = '10.00 AM';
  final List<String> _times = [
    '09.00 AM',
    '10.00 AM',
    '02.00 PM',
    '04.00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final raw = await _repo.loadPropertyById(widget.propertyId);
      if (!mounted) return;

      final property = Property.fromJson(raw);

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

  final String _idempotencyKey = const Uuid().v4();

  Future<void> _submitBooking() async {
    if (_selectedRange == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    bool success = false;
    String? errorMessage;
    try {
      final nights =
          _selectedRange!.end.difference(_selectedRange!.start).inDays;
      final totalPrice =
          (nights > 0 ? nights : 1) * _property!.price.toDouble();

      success = await BookingService.createBooking(
        propertyId: widget.propertyId,
        checkIn: _selectedRange!.start,
        checkOut: _selectedRange!.end,
        totalPrice: totalPrice,
        idempotencyKey: _idempotencyKey,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
    } catch (error) {
      errorMessage = _bookingErrorMessage(error);
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BookingConfirmedPage(
              property: _property!,
              selectedDate: _selectedRange!.start,
              selectedTime: _selectedTime,
            ),
          ),
        ).then((_) => widget.onComplete?.call());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                errorMessage ??
                    'We could not submit your booking. Please try again.',
                style: GoogleFonts.poppins()),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  String _bookingErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('already booked') ||
        message.contains('not available') ||
        message.contains('overlap')) {
      return 'These dates are no longer available. Please choose different dates.';
    }
    if (message.contains('already have an active booking') ||
        message.contains('already registered') ||
        message.contains('duplicate')) {
      return 'You already have an active booking request for this property.';
    }
    if (message.contains('property not found')) {
      return 'This property is no longer available.';
    }
    if (message.contains('no landlord')) {
      return 'This property cannot accept bookings right now.';
    }
    return 'We could not submit your booking. Please try again.';
  }

  Widget _buildDayCell(int day,
      {bool isCurrentMonth = true,
      bool isSelected = false,
      bool isBlue = false}) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isSelected ? _tenantPrimary : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$day',
          style: GoogleFonts.poppins(
            color: isSelected
                ? Colors.white
                : (isCurrentMonth ? _dark : _grey.withOpacity(0.4)),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 15,
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
              color: _grey,
              fontWeight: FontWeight.w600,
              fontSize: 14,
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
                _selectedRange = DateTimeRange(
                    start: thisDate,
                    end: thisDate.add(const Duration(days: 1)));
              });
            },
            behavior: HitTestBehavior.opaque,
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
      return Scaffold(
        backgroundColor: _bg,
        body: const Center(
            child: CircularProgressIndicator(color: _tenantPrimary)),
      );
    }

    if (_error != null || _property == null) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(PhosphorIconsRegular.warningCircle,
                  color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(_error ?? 'Failed to load property',
                  style: GoogleFonts.poppins(color: _dark)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: widget.onBack ?? () => Navigator.pop(context),
          behavior: HitTestBehavior.opaque,
          child: const Icon(PhosphorIconsRegular.caretLeft,
              color: _dark, size: 28),
        ),
        title: Text(
          'Book a Visit',
          style: GoogleFonts.poppins(
            color: _dark,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Month Selector ───
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _currentMonth = DateTime(
                              _currentMonth.year, _currentMonth.month - 1)),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: _surface,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: _grey.withOpacity(0.2))),
                            child: const Icon(PhosphorIconsRegular.caretLeft,
                                color: _dark, size: 18),
                          ),
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(_currentMonth),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _currentMonth = DateTime(
                              _currentMonth.year, _currentMonth.month + 1)),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: _surface,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: _grey.withOpacity(0.2))),
                            child: const Icon(PhosphorIconsRegular.caretRight,
                                color: _dark, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ─── Calendar Widget ───
                    _buildCalendar(),
                    const SizedBox(height: 32),

                    // ─── Selected Date ───
                    Text(
                      'Selected Date',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedRange != null
                          ? DateFormat('E, d MMM yyyy')
                              .format(_selectedRange!.start)
                          : 'No date selected',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _grey,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ─── Selected Time ───
                    Text(
                      'Select Time',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _times.map((time) {
                        bool isSelected = _selectedTime == time;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedTime = time),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? _tenantPrimary : _surface,
                              border: Border.all(
                                color: isSelected
                                    ? _tenantPrimary
                                    : _grey.withOpacity(0.2),
                              ),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              time,
                              style: GoogleFonts.poppins(
                                color: isSelected ? Colors.white : _dark,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Bottom Action Bar ───
            Container(
              padding: EdgeInsets.fromLTRB(
                  24, 20, 24, MediaQuery.of(context).padding.bottom + 20),
              decoration: BoxDecoration(
                color: _surface,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, -4)),
                ],
                border: Border(top: BorderSide(color: _grey.withOpacity(0.1))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedRange != null && !_isSubmitting)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Ready to schedule your visit for ${DateFormat('MMM d').format(_selectedRange!.start)} at $_selectedTime',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _grey,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_selectedRange == null || _isSubmitting)
                          ? null
                          : _submitBooking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _tenantPrimary,
                        disabledBackgroundColor: _grey.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32)),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              'Confirm Booking',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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

/// ─── Confirmation Screen ───────────────────────────────────────────────────────
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
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Circular Green Checkmark
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsFill.checkCircle,
                  color: Color(0xFF10B981),
                  size: 80,
                ),
              ),
              const SizedBox(height: 32),

              // Main Confirmation Text
              Text(
                'Booking Confirmed!',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your visit has been scheduled successfully.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: _grey,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 48),

              // Custom Property Details Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _grey.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 4)),
                  ],
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
                              fontWeight: FontWeight.w700,
                              color: _dark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${DateFormat('E, d MMM yyyy').format(selectedDate)}  |  $selectedTime',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: _dark,
                              fontWeight: FontWeight.w500,
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
                                  color: _grey,
                                  fontWeight: FontWeight.w500,
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
                  fontSize: 14,
                  color: _grey,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const Spacer(),

              // View My Booking Blue Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _tenantPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32)),
                    elevation: 0,
                  ),
                  child: Text(
                    'View My Bookings',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
