import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:property_app/data/mock_data.dart';
import 'package:property_app/repository/mock_repository.dart';

// --- Data Model ---
class BookingEvent {
  final String id;
  final DateTime date;
  final String title;
  final String time;
  final BookingStatus status;
  final String tenantName;
  final String location;
  final String image;
  final bool confirmed;

  BookingEvent({
    required this.id,
    required this.date,
    required this.title,
    required this.time,
    required this.status,
    required this.tenantName,
    required this.location,
    required this.image,
    this.confirmed = false,
  });

  BookingEvent copyWith({BookingStatus? status, bool? confirmed}) {
    return BookingEvent(
      id: id,
      date: date,
      title: title,
      time: time,
      status: status ?? this.status,
      tenantName: tenantName,
      location: location,
      image: image,
      confirmed: confirmed ?? this.confirmed,
    );
  }

  String get statusLabel {
    if (status == BookingStatus.upcoming) {
      return confirmed ? 'Confirmed' : 'Upcoming';
    }
    if (status == BookingStatus.completed) {
      return 'Completed';
    }
    return 'Cancelled';
  }

  Color get statusColor {
    if (status == BookingStatus.completed) {
      return const Color(0xFF065F46);
    }
    if (status == BookingStatus.cancelled) {
      return Colors.redAccent;
    }
    return confirmed ? const Color(0xFF059669) : const Color(0xFF3F37C9);
  }
}

class LandlordCalendarPage extends StatefulWidget {
  const LandlordCalendarPage({super.key});

  static Route route() {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
          opacity: animation, child: const LandlordCalendarPage()),
    );
  }

  @override
  State<LandlordCalendarPage> createState() => _LandlordCalendarPageState();
}

class _LandlordCalendarPageState extends State<LandlordCalendarPage> {
  // Design Tokens
  static const Color primaryGreen = Color(0xFF059669);
  static const Color textDark = Color(0xFF111827);
  static const Color textLight = Color(0xFF9CA3AF);

  late List<BookingEvent> _bookings;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _bookings = mockRepositoryProvider.bookings.map((booking) {
      final property =
          mockRepositoryProvider.findPropertyById(booking.propertyId);
      return BookingEvent(
        id: booking.id,
        date: booking.date,
        title: booking.title,
        time: booking.time,
        status: booking.status,
        tenantName: booking.tenantName,
        location: property?.location ?? 'Unknown location',
        image: booking.image,
      );
    }).toList();
  }

  List<BookingEvent> _getEventsForDay(DateTime day) {
    return _bookings.where((event) => isSameDay(event.date, day)).toList();
  }

  List<BookingEvent> get _nextSevenBookings {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final endOfWindow = startOfToday.add(const Duration(days: 7));
    final upcoming = _bookings
        .where((event) =>
            !event.date.isBefore(startOfToday) &&
            !event.date.isAfter(endOfWindow))
        .toList();
    upcoming.sort((a, b) => a.date.compareTo(b.date));
    return upcoming;
  }

  void _updateBooking(String bookingId,
      {BookingStatus? status, bool? confirmed}) {
    setState(() {
      _bookings = _bookings.map((event) {
        if (event.id != bookingId) return event;
        return event.copyWith(
          status: status,
          confirmed: confirmed,
        );
      }).toList();
    });
  }

  void _showBookingDetails(BookingEvent event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _BookingDetailsModal(
        event: event,
        onAccept: () {
          Navigator.pop(context);
          _updateBooking(event.id, confirmed: true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${event.title} has been accepted.')),
          );
        },
        onComplete: () {
          Navigator.pop(context);
          _updateBooking(event.id, status: BookingStatus.completed);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${event.title} marked as completed.')),
          );
        },
        onCancel: () {
          Navigator.pop(context);
          _updateBooking(event.id, status: BookingStatus.cancelled);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${event.title} has been cancelled.')),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFE8F6EF).withOpacity(0.6),
                    Colors.white
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _buildCalendarCard(),
                        const SizedBox(height: 32),
                        _buildUpcomingSection(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: _GlassButton(
                child: const Icon(Icons.arrow_back, color: textDark)),
          ),
          const SizedBox(width: 20),
          Text(
            'Calendar',
            style: (Theme.of(context).textTheme.displaySmall ??
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))
                .copyWith(color: textDark),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    return _GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(32),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        eventLoader: _getEventsForDay,
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          final events = _getEventsForDay(selectedDay);
          if (events.isNotEmpty) {
            _showBookingDetails(events.first);
          }
        },
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: (Theme.of(context).textTheme.headlineSmall ??
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))
              .copyWith(color: textDark),
          leftChevronIcon: Icon(PhosphorIcons.caretLeft(), color: textDark),
          rightChevronIcon: Icon(PhosphorIcons.caretRight(), color: textDark),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w700, color: textLight),
          weekendStyle: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.redAccent),
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) =>
              _buildDayCell(day, isSelected: false),
          selectedBuilder: (context, day, focusedDay) =>
              _buildDayCell(day, isSelected: true),
          todayBuilder: (context, day, focusedDay) =>
              _buildDayCell(day, isToday: true),
          markerBuilder: (context, day, events) {
            if (events.isNotEmpty) {
              return Positioned(
                bottom: 6,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: primaryGreen, shape: BoxShape.circle),
                ),
              );
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildDayCell(DateTime day,
      {bool isSelected = false, bool isToday = false}) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isSelected
            ? primaryGreen
            : (isToday ? primaryGreen.withOpacity(0.1) : Colors.transparent),
        borderRadius: BorderRadius.circular(12),
        border: isToday ? Border.all(color: primaryGreen, width: 1) : null,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight:
                (isSelected || isToday) ? FontWeight.w700 : FontWeight.w500,
            color:
                isSelected ? Colors.white : (isToday ? primaryGreen : textDark),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingSection() {
    final upcoming = _nextSevenBookings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Next 7 Days',
          style: (Theme.of(context).textTheme.displayMedium ??
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))
              .copyWith(color: textDark),
        ),
        const SizedBox(height: 16),
        if (upcoming.isEmpty)
          Text(
            'No bookings in the next week.',
            style: GoogleFonts.poppins(fontSize: 14, color: textLight),
          )
        else
          ...upcoming.map((event) => _EventTile(event: event)),
      ],
    );
  }
}

class _BookingDetailsModal extends StatelessWidget {
  final BookingEvent event;
  final VoidCallback? onAccept;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;

  const _BookingDetailsModal({
    required this.event,
    this.onAccept,
    this.onComplete,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final bool isUpcoming = event.status == BookingStatus.upcoming;
    final String primaryLabel = isUpcoming
        ? (event.confirmed ? 'Mark Completed' : 'Accept Booking')
        : event.statusLabel;
    final VoidCallback primaryAction = () {
      if (!isUpcoming) {
        Navigator.pop(context);
        return;
      }
      if (event.confirmed) {
        onComplete?.call();
      } else {
        onAccept?.call();
      }
    };

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Booking Details',
                    style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                      color: event.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(event.statusLabel,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: event.statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow(
                PhosphorIcons.calendarBlank(), 'Property', event.title),
            _buildDetailRow(PhosphorIcons.user(), 'Tenant', event.tenantName),
            _buildDetailRow(PhosphorIcons.clock(), 'Time Slot', event.time),
            _buildDetailRow(PhosphorIcons.mapPin(), 'Location', event.location),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: primaryAction,
                    child: Text(primaryLabel,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
                _GlassButton(
                  size: 56,
                  child: Icon(PhosphorIcons.chatCircle(),
                      color: const Color(0xFF059669)),
                ),
              ],
            ),
            if (event.status == BookingStatus.upcoming)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextButton(
                  onPressed: onCancel,
                  child: Text(
                    'Cancel Booking',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFEF4444)),
                  ),
                ),
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: const Color(0xFF6B7280)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500)),
              Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827))),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Reusable UI Elements ---
class _EventTile extends StatelessWidget {
  final BookingEvent event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        children: [
          Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                  color: event.statusColor, shape: BoxShape.circle)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827))),
                Text(event.time,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: const Color(0xFF9CA3AF))),
              ],
            ),
          ),
          Icon(PhosphorIcons.caretRight(),
              color: const Color(0xFF9CA3AF), size: 18),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final Widget child;
  final double size;
  const _GlassButton({required this.child, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  const _GlassContainer(
      {required this.child, required this.padding, required this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            borderRadius: borderRadius,
            border: Border.all(color: Colors.white.withOpacity(0.7)),
          ),
          child: child,
        ),
      ),
    );
  }
}
