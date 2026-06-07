import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:property_app/services/booking_service.dart';
import 'dart:ui';

class LandlordCalendarPage extends StatefulWidget {
  final String? propertyId;
  final String? propertyTitle;

  const LandlordCalendarPage(
      {super.key, this.propertyId, this.propertyTitle});

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
  // Logic & State strictly intact
  bool _isLoading = true;
  List<dynamic> _bookings = [];
  List<int> _blockedDays = [];
  DateTime _focusedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        BookingService.fetchBookings(isLandlord: true),
        Future.value(<int>[]), // Placeholder for blocked days fetch
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + delta);
      _loadData();
    });
  }

  // --- NEW UI MATCHING PDF ---

  Widget _buildDayCell(int day, {bool isCurrentMonth = true, bool isBooked = false, bool isBlue = false}) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isBooked ? const Color(0xFF3B41E1) : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$day',
          style: GoogleFonts.poppins(
            color: isBooked
                ? Colors.white
                : (isCurrentMonth
                    ? const Color(0xFF111827)
                    : (isBlue ? const Color(0xFF3B41E1) : const Color(0xFF9CA3AF))),
            fontWeight: isBooked ? FontWeight.bold : FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    int daysInMonth = DateUtils.getDaysInMonth(_focusedDate.year, _focusedDate.month);
    DateTime firstDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
    int firstWeekday = firstDayOfMonth.weekday; // 1 (Mon) to 7 (Sun)
    int offset = firstWeekday == 7 ? 0 : firstWeekday;

    DateTime prevMonth = DateTime(_focusedDate.year, _focusedDate.month - 1);
    int daysInPrevMonth = DateUtils.getDaysInMonth(prevMonth.year, prevMonth.month);

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
        dayWidgets.add(_buildDayCell(day, isCurrentMonth: false, isBlue: false));
      } else {
        int day = i - offset + 1;
        DateTime thisDate = DateTime(_focusedDate.year, _focusedDate.month, day);
        
        // Logic strictly kept intact
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

        dayWidgets.add(_buildDayCell(day, isCurrentMonth: true, isBooked: isBooked));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF9CA3AF), size: 20),
                onPressed: () => _changeMonth(-1),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(_focusedDate),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 20),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 16),
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

  Widget _buildBookingList() {
    if (_bookings.isEmpty) {
      return Center(
        child: Text(
          "No bookings for this period.",
          style: GoogleFonts.poppins(color: const Color(0xFF9CA3AF), fontSize: 15),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: _bookings.length,
      itemBuilder: (context, index) {
        final b = _bookings[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F1FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event_available, color: Color(0xFF3B41E1), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b['tenant_name'] ?? 'Guest',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${b['check_in_date']} to ${b['check_out_date']}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(12),
                ),
                  child: Text(
                    b['status'].toString().toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F6EF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.propertyTitle != null
              ? '${widget.propertyTitle} Calendar'
              : 'Portfolio Calendar',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          // Soft Mint Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF7FDF9),
                  Color(0xFFE8F6EF),
                  Color(0xFFD4EFE1),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF3B41E1)))
              : Column(
                  children: [
                    _buildCalendarGrid(),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.0),
                      child: Divider(color: Color(0xFFE5E7EB), thickness: 1),
                    ),
                    const SizedBox(height: 8),
                    Expanded(child: _buildBookingList()),
                  ],
                ),
        ],
      ),
    );
  }
}

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double blur = 20.0;
  final double opacity = 0.55;
  final double borderWidth = 1.5;

  const _GlassContainer({
    required this.child,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);

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