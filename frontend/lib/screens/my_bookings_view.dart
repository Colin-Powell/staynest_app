// lib/screens/my_bookings_view.dart
import 'package:flutter/material.dart';

import 'package:property_app/models/property.dart';

import 'package:property_app/services/booking_service.dart';
import 'package:property_app/widgets/property_image.dart';

/// A wrapper to attach booking-specific mock data (Date & Status) to standard properties
class BookingWrapper {
  final Property property;
  final String dateTime;
  final String status;
  final String bookingId;
  final Map<String, dynamic> rawData;

  BookingWrapper({
    required this.property,
    required this.dateTime,
    required this.status,
    required this.bookingId,
    required this.rawData,
  });
}

class MyBookingsViewScreen extends StatefulWidget {
  final VoidCallback onBack;

  const MyBookingsViewScreen({super.key, required this.onBack});

  @override
  State<MyBookingsViewScreen> createState() => _MyBookingsViewScreenState();
}

class _MyBookingsViewScreenState extends State<MyBookingsViewScreen> {
  static const tabs = ['Upcoming', 'Completed', 'Cancelled'];
  String activeTab = 'Upcoming';
  List<BookingWrapper> bookings = [];
  bool loading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      loading = true;
      hasError = false;
    });
    try {
      final rows = await BookingService.fetchBookings();
      final loaded = rows.whereType<Map>().map((raw) {
        final booking = Map<String, dynamic>.from(raw);
        final status = booking['status']?.toString().toLowerCase() ?? '';
        final uiStatus = status == 'completed'
            ? 'Completed'
            : (status == 'cancelled' || status == 'rejected')
                ? 'Cancelled'
                : 'Upcoming';
        final date =
            DateTime.tryParse(booking['check_in_date']?.toString() ?? '');
        return BookingWrapper(
          property: Property(
            id: booking['property_id']?.toString() ?? '',
            name: booking['property_name']?.toString() ?? 'Unknown Property',
            location: booking['property_city']?.toString() ?? 'See details',
            image: booking['property_image']?.toString() ?? '',
            images: const [],
            price: int.tryParse(booking['total_price']?.toString() ?? '') ?? 0,
            lat: 0,
            lng: 0,
            rating: 0,
            reviews: 0,
            category: '',
            features: const PropertyFeatures(
                beds: 0, rooms: 0, baths: 0, furnished: false),
            amenities: const [],
            agent: const Agent(userId: '', name: '', avatar: ''),
            description: '',
          ),
          dateTime: date == null
              ? 'Date unavailable'
              : '${date.day}/${date.month}/${date.year}',
          status: uiStatus,
          bookingId: booking['id']?.toString() ?? '',
          rawData: booking,
        );
      }).toList();
      if (mounted)
        setState(() {
          bookings = loaded;
          loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          loading = false;
          hasError = true;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        bookings.where((booking) => booking.status == activeTab).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
        title: const Text('My Bookings'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: Row(
                children: tabs
                    .map((tab) => Expanded(
                          child: TextButton(
                            onPressed: () => setState(() => activeTab = tab),
                            child: Text(tab,
                                style: TextStyle(
                                    fontWeight: activeTab == tab
                                        ? FontWeight.w700
                                        : FontWeight.w400)),
                          ),
                        ))
                    .toList()),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : hasError
                    ? Center(
                        child: ElevatedButton(
                            onPressed: _loadBookings,
                            child: const Text('Retry')))
                    : visible.isEmpty
                        ? Center(child: Text('No $activeTab bookings'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: visible.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, index) =>
                                _bookingCard(visible[index]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _bookingCard(BookingWrapper booking) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: SizedBox(
            width: 72,
            height: 72,
            child:
                buildPropertyImage(booking.property.image, fit: BoxFit.cover)),
        title: Text(booking.property.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle:
            Text('${booking.property.location}\nCheck-in: ${booking.dateTime}'),
        isThreeLine: true,
        trailing: Text(booking.status),
      ),
    );
  }
}
