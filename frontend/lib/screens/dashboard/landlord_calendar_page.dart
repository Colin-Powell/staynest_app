import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:property_app/services/booking_service.dart';

// ─── Landlord Design System Constants ─────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981); // Emerald Green for Landlord Theme

class LandlordCalendarPage extends StatefulWidget {
  final String? propertyId;
  final String? propertyTitle;
  final VoidCallback? onBack;
  final ValueChanged<Map<String, dynamic>>? onOpenBookingDetail;

  const LandlordCalendarPage({
    super.key,
    this.propertyId,
    this.propertyTitle,
    this.onBack,
    this.onOpenBookingDetail,
  });

  static Route route({String? propertyId, String? propertyTitle}) {
    return MaterialPageRoute(
      builder: (_) => LandlordCalendarPage(
        propertyId: propertyId,
        propertyTitle: propertyTitle,
      ),
    );
  }

  @override
  State<LandlordCalendarPage> createState() => _LandlordCalendarPageState();
}

class _LandlordCalendarPageState extends State<LandlordCalendarPage> {
  bool _isLoading = true;
  bool _hasError = false;
  List<dynamic> _bookings = [];
  List<int> _blockedDays = [];
  DateTime _focusedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final results = await Future.wait([
        BookingService.fetchBookings(isLandlord: true),
        Future.value(<int>[]),
      ]);
      if (mounted) {
        setState(() {
          final allBookings = results[0];
          if (widget.propertyId != null) {
            _bookings = allBookings
                .where((b) => b['property_id'] == widget.propertyId)
                .toList();
          } else {
            _bookings = allBookings;
          }
          _blockedDays = results[1] as List<int>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + delta);
      _loadData();
    });
  }

  // Helper to format raw date strings into human readable "Aug 30, 2026"
  String _formatDateString(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  // ─── SHARED UI BUILDERS ─────────────────────────────────────────────────────

  Widget _buildHeader({bool isDesktop = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          isDesktop ? 32 : 24, isDesktop ? 32 : 16, isDesktop ? 32 : 24, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onBack ?? () => Navigator.maybePop(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: isDesktop ? const EdgeInsets.all(8) : EdgeInsets.zero,
              decoration: isDesktop
                  ? BoxDecoration(
                      color: _surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: _grey.withOpacity(0.2)))
                  : null,
              child: Icon(PhosphorIconsRegular.caretLeft,
                  size: isDesktop ? 20 : 24, color: _dark),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.propertyTitle != null
                  ? '${widget.propertyTitle} Calendar'
                  : 'Portfolio Calendar',
              style: GoogleFonts.poppins(
                fontSize: isDesktop ? 32 : 22,
                fontWeight: FontWeight.w700,
                color: _dark,
                letterSpacing: -0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(int day,
      {bool isCurrentMonth = true,
      bool isBooked = false,
      bool isToday = false}) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isBooked ? _green : Colors.transparent,
        shape: BoxShape.circle,
        border: (isToday && !isBooked)
            ? Border.all(color: _green, width: 1.5)
            : null,
      ),
      child: Center(
        child: Text(
          '$day',
          style: GoogleFonts.poppins(
            color: isBooked
                ? Colors.white
                : (isCurrentMonth
                    ? (isToday ? _green : _dark)
                    : _grey.withOpacity(0.4)),
            fontWeight:
                (isBooked || isToday) ? FontWeight.w700 : FontWeight.w500,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid({bool isDesktop = false}) {
    int daysInMonth =
        DateUtils.getDaysInMonth(_focusedDate.year, _focusedDate.month);
    DateTime firstDayOfMonth =
        DateTime(_focusedDate.year, _focusedDate.month, 1);
    int firstWeekday = firstDayOfMonth.weekday; // 1 (Mon) to 7 (Sun)
    int offset = firstWeekday == 7 ? 0 : firstWeekday;

    DateTime prevMonth = DateTime(_focusedDate.year, _focusedDate.month - 1);
    int daysInPrevMonth =
        DateUtils.getDaysInMonth(prevMonth.year, prevMonth.month);
    final now = DateTime.now();

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
        dayWidgets.add(_buildDayCell(day, isCurrentMonth: false));
      } else if (i >= offset + daysInMonth) {
        int day = i - (offset + daysInMonth) + 1;
        dayWidgets.add(_buildDayCell(day, isCurrentMonth: false));
      } else {
        int day = i - offset + 1;
        DateTime thisDate =
            DateTime(_focusedDate.year, _focusedDate.month, day);
        bool isToday = thisDate.year == now.year &&
            thisDate.month == now.month &&
            thisDate.day == now.day;

        bool isBooked = _bookings.any((b) {
          try {
            final start = DateTime.parse(b['check_in_date']);
            final end = DateTime.parse(b['check_out_date']);
            return thisDate.isAfter(start.subtract(const Duration(days: 1))) &&
                thisDate.isBefore(end.add(const Duration(days: 1))) &&
                b['status'] == 'confirmed';
          } catch (_) {
            return false;
          }
        });

        dayWidgets.add(_buildDayCell(day,
            isCurrentMonth: true, isBooked: isBooked, isToday: isToday));
      }
    }

    return Padding(
      padding: isDesktop
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _changeMonth(-1),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: _grey.withOpacity(0.2)),
                  ),
                  child: const Icon(PhosphorIconsRegular.caretLeft,
                      color: _dark, size: 18),
                ),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(_focusedDate),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => _changeMonth(1),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: _grey.withOpacity(0.2)),
                  ),
                  child: const Icon(PhosphorIconsRegular.caretRight,
                      color: _dark, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: dayWidgets,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({bool isDesktop = false}) {
    return Center(
      child: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: 32, vertical: isDesktop ? 64 : 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIconsRegular.calendarBlank,
                size: isDesktop ? 64 : 56, color: _grey),
            const SizedBox(height: 16),
            Text(
              "No bookings for this period",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Navigate to another month to view upcoming reservations.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> b, {bool isDesktop = false}) {
    final isConfirmed = b['status'] == 'confirmed';
    return GestureDetector(
      onTap: widget.onOpenBookingDetail == null
          ? null
          : () {
              final checkIn = b['check_in_date']?.toString() ?? '';
              widget.onOpenBookingDetail!(<String, dynamic>{
                ...b,
                'id': b['id']?.toString() ?? '',
                'title': b['title'] ??
                    b['property_title'] ??
                    widget.propertyTitle ??
                    'Property',
                'location': b['location'] ?? b['city'] ?? '',
                'date': _formatDateString(checkIn),
                'checkOutDate': b['check_out_date']?.toString() ?? '',
                'tenant_name': b['tenant_name'] ?? 'Tenant',
                'image': b['image'] ?? b['image_url'] ?? '',
                'price':
                    (double.tryParse(b['total_price']?.toString() ?? '0') ?? 0)
                        .toInt(),
              });
            },
      child: Container(
        margin: EdgeInsets.only(bottom: isDesktop ? 0 : 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: isDesktop ? Border.all(color: _grey.withOpacity(0.1)) : null,
          boxShadow: isDesktop
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isConfirmed
                    ? _green.withOpacity(0.1)
                    : _grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(PhosphorIconsRegular.calendarCheck,
                  color: isConfirmed ? _green : _dark, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    b['tenant_name'] ?? 'Guest',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDateString(b['check_in_date'])} – ${_formatDateString(b['check_out_date'])}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _grey,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isConfirmed
                    ? _green.withOpacity(0.1)
                    : _grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                b['status'].toString().toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isConfirmed ? _green : _dark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── DESKTOP SPECIFIC LAYOUT ────────────────────────────────────────────────

  Widget _buildDesktopShimmerLoading() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Calendar Panel Shimmer
        Container(
          width: 440,
          margin: const EdgeInsets.only(left: 32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _grey.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Shimmer.fromColors(
                      baseColor: Colors.grey.shade200,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle))),
                  Shimmer.fromColors(
                      baseColor: Colors.grey.shade200,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                          width: 140,
                          height: 24,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12)))),
                  Shimmer.fromColors(
                      baseColor: Colors.grey.shade200,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle))),
                ],
              ),
              const SizedBox(height: 24),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(
                    42,
                    (index) => Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Shimmer.fromColors(
                            baseColor: Colors.grey.shade200,
                            highlightColor: Colors.grey.shade100,
                            child: Container(
                                decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle)),
                          ),
                        )),
              ),
            ],
          ),
        ),
        const SizedBox(width: 32),
        // Right Bookings Grid Shimmer
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(right: 32, bottom: 48),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisExtent: 90,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
            ),
            itemCount: 8,
            itemBuilder: (context, index) => Shimmer.fromColors(
              baseColor: Colors.grey.shade200,
              highlightColor: Colors.grey.shade100,
              child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20))),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(
              children: [
                _buildHeader(isDesktop: true),
                Expanded(
                  child: _hasError
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(PhosphorIconsRegular.warningCircle,
                                  size: 48, color: Colors.redAccent),
                              const SizedBox(height: 16),
                              Text("Failed to load calendar",
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: _dark)),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _loadData,
                                child: Text('Retry',
                                    style: GoogleFonts.poppins(
                                        color: _green,
                                        fontWeight: FontWeight.w600)),
                              )
                            ],
                          ),
                        )
                      : _isLoading
                          ? _buildDesktopShimmerLoading()
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Fixed Calendar Card
                                Container(
                                  width: 440,
                                  margin: const EdgeInsets.only(
                                      left: 32, bottom: 32),
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: _surface,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      )
                                    ],
                                  ),
                                  child: SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    child: _buildCalendarGrid(isDesktop: true),
                                  ),
                                ),
                                const SizedBox(width: 32),
                                // Right Scrollable Bookings Pane
                                Expanded(
                                  child: _bookings.isEmpty
                                      ? _buildEmptyState(isDesktop: true)
                                      : GridView.builder(
                                          padding: const EdgeInsets.only(
                                              right: 32, bottom: 48),
                                          physics:
                                              const BouncingScrollPhysics(),
                                          gridDelegate:
                                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                            maxCrossAxisExtent: 400,
                                            mainAxisExtent:
                                                90, // Match typical card height
                                            crossAxisSpacing: 24,
                                            mainAxisSpacing: 24,
                                          ),
                                          itemCount: _bookings.length,
                                          itemBuilder: (context, index) {
                                            return _buildBookingCard(
                                                _bookings[index],
                                                isDesktop: true);
                                          },
                                        ),
                                ),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── MOBILE SPECIFIC LAYOUT ─────────────────────────────────────────────────

  Widget _buildMobileShimmerLoading() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar Nav Shimmer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Shimmer.fromColors(
                  baseColor: Colors.grey.shade200,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle)),
                ),
                Shimmer.fromColors(
                  baseColor: Colors.grey.shade200,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                      width: 140,
                      height: 24,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12))),
                ),
                Shimmer.fromColors(
                  baseColor: Colors.grey.shade200,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Calendar Grid Shimmer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(
                  42,
                  (index) => Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Shimmer.fromColors(
                          baseColor: Colors.grey.shade200,
                          highlightColor: Colors.grey.shade100,
                          child: Container(
                              decoration: const BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle)),
                        ),
                      )),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: Divider(color: _grey.withOpacity(0.2), thickness: 1),
          ),
          // Booking List Shimmer
          ...List.generate(
              3,
              (index) => Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Shimmer.fromColors(
                      baseColor: Colors.grey.shade200,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                          height: 88,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20))),
                    ),
                  )),
        ],
      ),
    );
  }

  Widget _buildMobileBookingList() {
    if (_bookings.isEmpty) {
      return _buildEmptyState(isDesktop: false);
    }

    return ListView.builder(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(), // Handled by outer scroll view
      itemCount: _bookings.length,
      itemBuilder: (context, index) {
        return _buildBookingCard(_bookings[index], isDesktop: false);
      },
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(isDesktop: false),
            Expanded(
              child: _hasError
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(PhosphorIconsRegular.warningCircle,
                              size: 48, color: Colors.redAccent),
                          const SizedBox(height: 16),
                          Text(
                            "Failed to load calendar",
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, color: _dark),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _loadData,
                            child: Text('Retry',
                                style: GoogleFonts.poppins(
                                    color: _green,
                                    fontWeight: FontWeight.w600)),
                          )
                        ],
                      ),
                    )
                  : _isLoading
                      ? _buildMobileShimmerLoading()
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCalendarGrid(isDesktop: false),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0, vertical: 8.0),
                                child: Divider(
                                    color: _grey.withOpacity(0.2),
                                    thickness: 1),
                              ),
                              _buildMobileBookingList(),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 1100) {
      return _buildDesktopLayout();
    }
    return _buildMobileLayout();
  }
}
