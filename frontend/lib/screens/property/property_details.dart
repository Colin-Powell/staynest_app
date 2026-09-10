// lib/screens/dashboard/property_details.dart

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/models/property.dart';
import 'package:property_app/models/property_taxonomy.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/services/analytics/analytics_service.dart';
import 'package:property_app/models/review.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:intl/intl.dart';
import 'package:property_app/services/booking_service.dart';
import 'package:property_app/session/app_session.dart';
import 'booking_view.dart';
import '../reviews_view.dart' hide WriteReviewView;

class PropertyDetails extends StatefulWidget {
  final Property property;
  final VoidCallback? onBack;
  final VoidCallback? onViewGallery;
  final VoidCallback? onViewAmenities;
  final VoidCallback? onViewLocation;
  final VoidCallback? onViewLandlord;
  final Function(String userId, String name, String avatar)? onMessage;

  const PropertyDetails({
    super.key,
    required this.property,
    this.onBack,
    this.onViewGallery,
    this.onViewAmenities,
    this.onViewLocation,
    this.onViewLandlord,
    this.onMessage,
  });

  @override
  State<PropertyDetails> createState() => _PropertyDetailsState();
}

class _PropertyDetailsState extends State<PropertyDetails> {
  static const Color tenantPrimary = Color(0xFF3F37C9); // Tenant Blue
  static const Color textDark = Color(0xFF222222); // Airbnb-style dark grey
  static const Color textLight = Color(0xFF717171); // Airbnb-style light grey
  static const Color dividerColor = Color(0xFFEBEBEB);

  List<Review> _reviews = [];
  bool _loadingReviews = true;
  String? _eligibleBookingId;
  bool _hasReviewed = false;
  bool _hasActiveBooking = false;
  bool _checkingBooking = true;

  // ─── Computed getters — single source of truth for rating & count ──────────
  double get _avgRating => _reviews.isEmpty
      ? widget.property.rating
      : _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length;

  int get _reviewCount =>
      _reviews.isEmpty ? widget.property.reviews : _reviews.length;

  // Carousel Controllers
  final PageController _reviewPageController =
      PageController(viewportFraction: 1.0);
  Timer? _carouselTimer;

  DateTime? _viewStartTime;

  @override
  void initState() {
    super.initState();
    _viewStartTime = DateTime.now();
    AnalyticsService.logListingInteraction(AnalyticsEvents.listingView,
        listingId: widget.property.id,
        propertyType: widget.property.category,
        location: widget.property.location);

    _fetchReviews();
    _checkActiveBooking();
  }

  Future<void> _checkActiveBooking() async {
    try {
      final bookings = await BookingService.fetchBookings(isLandlord: false);

      final hasActive = bookings.any((booking) {
        final propertyId = booking['property_id'] ??
            (booking['property'] is Map
                ? (booking['property'] as Map)['id']
                : null);
        if (propertyId?.toString() != widget.property.id) {
          return false;
        }

        final status = (booking['status'] ?? '').toString().toLowerCase();
        return status == 'pending' ||
            status == 'confirmed' ||
            status == 'completed';
      });

      if (mounted) {
        setState(() {
          _hasActiveBooking = hasActive;
          _checkingBooking = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking active booking: $e');
      if (mounted) setState(() => _checkingBooking = false);
    }
  }

  Future<void> _checkReviewEligibility() async {
    try {
      final bookings = await BookingService.fetchBookings(isLandlord: false);
      final completed = bookings.firstWhere(
        (b) =>
            b['property_id'].toString() == widget.property.id &&
            b['status'] == 'completed',
        orElse: () => null,
      );

      if (completed != null && mounted) {
        final bId = completed['id'].toString();
        setState(() {
          _eligibleBookingId = bId;
          _hasReviewed = _reviews.any((r) => r.bookingId == bId);
        });
      }
    } catch (e) {
      debugPrint('Error checking review eligibility: $e');
    }
  }

  Future<void> _fetchReviews() async {
    setState(() {
      _loadingReviews = true;
    });
    try {
      final fetchedReviews = await RemoteDatabaseRepository()
          .fetchPropertyReviews(widget.property.id);
      if (mounted) {
        setState(() {
          _reviews = fetchedReviews;
          _loadingReviews = false;
        });
        _checkReviewEligibility();
        _startCarousel();
      }
    } catch (e) {
      debugPrint('Error fetching reviews: $e');
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  void _startCarousel() {
    _carouselTimer?.cancel();
    if (_reviews.length > 1) {
      _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (_reviewPageController.hasClients) {
          _reviewPageController.nextPage(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
          );
        }
      });
    }
  }

  void _showLoginPrompt(String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Login required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              AppSession.isGuest = false;
              Navigator.pop(dialogContext);
              Navigator.pushReplacementNamed(context, '/login');
            },
            icon: const Icon(Icons.login),
            label: const Text('Log in'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.trackPropertyView(widget.property.id,
          source: 'property_details');
      AnalyticsService.logListingInteraction(AnalyticsEvents.listingView,
          listingId: widget.property.id);
    });
  }

  @override
  void dispose() {
    if (_viewStartTime != null) {
      final duration = DateTime.now().difference(_viewStartTime!).inSeconds;
      if (duration > 2) {
        AnalyticsService.logListingInteraction(
            AnalyticsEvents.listingEngagement,
            listingId: widget.property.id,
            propertyType: widget.property.category,
            durationSeconds: duration);
      }
    }

    _carouselTimer?.cancel();
    _reviewPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.property.images.isNotEmpty
        ? widget.property.images
        : [widget.property.image, widget.property.image, widget.property.image];

    final previewPhotos = List<String>.from(photos);
    while (previewPhotos.length < 3) {
      previewPhotos.add(widget.property.image);
    }

    final double expandedImageHeight = MediaQuery.of(context).size.width * 0.85;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Fixed Background Image at the Top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: expandedImageHeight,
            child: GestureDetector(
              onTap: widget.onViewGallery,
              child: Hero(
                tag: 'property-${widget.property.id}',
                child: buildPropertyImage(
                  widget.property.image,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // 2. Main Scrolling White Card
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Transparent space to reveal the image behind
              SliverToBoxAdapter(
                child: SizedBox(height: expandedImageHeight - 40),
              ),

              // The Solid White Card that slides up
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(
                        bottom: 120), // Bottom padding for fixed buttons
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        // Small handle indicator
                        Center(
                          child: Container(
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- Header Section (Centered) ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                widget.property.name,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.property.location,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  color: textLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: tenantPrimary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Ksh ${widget.property.price.toStringAsFixed(0)}/month',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: tenantPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ReviewsView(
                                        propertyId: widget.property.id,
                                        propertyName: widget.property.name,
                                        averageRating: _avgRating,
                                        reviewCount: _reviewCount,
                                        bookingId: _eligibleBookingId,
                                        canReview: _eligibleBookingId != null,
                                        hasReviewed: _hasReviewed,
                                      ),
                                    ),
                                  ).then((_) => _fetchReviews());
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        color: textDark, size: 18),
                                    const SizedBox(width: 4),
                                    Text(
                                      _reviewCount > 0
                                          ? _avgRating.toStringAsFixed(1)
                                          : 'New',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: textDark,
                                      ),
                                    ),
                                    if (_reviewCount > 0) ...[
                                      const SizedBox(width: 4),
                                      const Text(
                                        '·',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: textDark),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$_reviewCount reviews',
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: textDark,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        _buildDivider(),

                        // --- Property Snapshot (Rooms/Beds) ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildMinimalTag(Icons.apartment_rounded,
                                    widget.property.category),
                                _buildMinimalTag(Icons.door_front_door_rounded,
                                    '${widget.property.features.rooms} Room'),
                                _buildMinimalTag(Icons.bed_rounded,
                                    '${widget.property.features.beds} beds'),
                                if (widget.property.features.furnished)
                                  _buildMinimalTag(
                                      Icons.weekend_rounded, 'Furnished'),
                              ],
                            ),
                          ),
                        ),

                        _buildDivider(),

                        // --- Host Section ---
                        GestureDetector(
                          onTap: widget.onViewLandlord,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              children: [
                                ClipOval(
                                  child: Container(
                                    width: 56,
                                    height: 56,
                                    color: Colors.grey.shade200,
                                    child: widget
                                            .property.agent.avatar.isNotEmpty
                                        ? Image.network(
                                            widget.property.agent.avatar,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Icon(PhosphorIcons.user(),
                                                        color: textLight,
                                                        size: 28),
                                          )
                                        : Icon(PhosphorIcons.user(),
                                            color: textLight, size: 28),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              'Hosted by ${widget.property.agent.name}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: textDark,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (widget
                                              .property.agent.verified) ...[
                                            const SizedBox(width: 4),
                                            const Icon(Icons.verified,
                                                color: Colors.blue, size: 18),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.property.agent.verified
                                            ? 'Verified Landlord'
                                            : 'Landlord',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: textLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        _buildDivider(),

                        // --- About Property Section ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'About this property',
                                style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: textDark),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                widget.property.description.isNotEmpty
                                    ? widget.property.description
                                    : 'No description provided for this property.',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  height: 1.6,
                                  color: textDark.withOpacity(0.85),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),

                        _buildDivider(),

                        // --- Amenities Snapshot ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'What this place offers',
                                style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: textDark),
                              ),
                              const SizedBox(height: 24),
                              ...[
                                ...widget.property.amenities
                                    .take(5)
                                    .map((amenityId) {
                                  final attr =
                                      PropertyTaxonomy.getAttributeById(
                                          amenityId);
                                  final label = attr?.label ?? amenityId;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle,
                                            size: 26,
                                            color: textDark.withOpacity(0.8)),
                                        const SizedBox(width: 16),
                                        Text(
                                          label,
                                          style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              color: textDark,
                                              fontWeight: FontWeight.w400),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                ...widget.property.customFeatures
                                    .take(5 -
                                        (widget.property.amenities.length > 5
                                            ? 5
                                            : widget.property.amenities.length))
                                    .map((cf) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle,
                                            size: 26,
                                            color: textDark.withOpacity(0.8)),
                                        const SizedBox(width: 16),
                                        Text(
                                          cf,
                                          style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              color: textDark,
                                              fontWeight: FontWeight.w400),
                                        ),
                                      ],
                                    ),
                                  );
                                })
                              ],
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: widget.onViewAmenities,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    side: const BorderSide(
                                        color: textDark, width: 1.2),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: Text(
                                    'Show all ${widget.property.amenities.length} amenities',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: textDark,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        _buildDivider(),

                        // --- Location Snapshot ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Where you\'ll be',
                                style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: textDark),
                              ),
                              const SizedBox(height: 24),
                              GestureDetector(
                                onTap: widget.onViewLocation,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: SizedBox(
                                    height: 220,
                                    width: double.infinity,
                                    child: IgnorePointer(
                                      child: FlutterMap(
                                        options: MapOptions(
                                          initialCenter: LatLng(
                                              widget.property.lat,
                                              widget.property.lng),
                                          initialZoom: 14.0,
                                        ),
                                        children: [
                                          TileLayer(
                                            urlTemplate:
                                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                            userAgentPackageName:
                                                'com.rashoti.staynest',
                                          ),
                                          MarkerLayer(
                                            markers: [
                                              Marker(
                                                point: LatLng(
                                                    widget.property.lat,
                                                    widget.property.lng),
                                                width: 60,
                                                height: 60,
                                                child: Center(
                                                  child: Container(
                                                    width: 44,
                                                    height: 44,
                                                    decoration: BoxDecoration(
                                                      color: tenantPrimary,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                          color: Colors.white,
                                                          width: 3),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(0.2),
                                                          blurRadius: 8,
                                                          offset: const Offset(
                                                              0, 4),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Center(
                                                      child: Icon(
                                                          PhosphorIcons.house(
                                                              PhosphorIconsStyle
                                                                  .fill),
                                                          color: Colors.white,
                                                          size: 20),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                widget.property.location,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (_checkingBooking)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: LinearProgressIndicator(minHeight: 2),
                                )
                              else if (_hasActiveBooking)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: widget.onViewLocation,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: tenantPrimary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      icon: Icon(
                                          PhosphorIcons.mapPin(
                                              PhosphorIconsStyle.fill),
                                          size: 18),
                                      label: Text(
                                        'Open location',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  'Exact location provided after booking.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: textLight,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        _buildDivider(),

                        // --- Interior Preview ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Interior Preview',
                                style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: textDark),
                              ),
                              const SizedBox(height: 24),
                              GestureDetector(
                                onTap: widget.onViewGallery,
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: _buildRoomImage(previewPhotos[0],
                                            height: 120)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: _buildRoomImage(previewPhotos[1],
                                            height: 120)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: _buildRoomImage(previewPhotos[2],
                                            height: 120)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        _buildDivider(),

                        // --- Reviews Carousel Section ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildReviewsSection(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 3. Top Navigation Bar (Fixed)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: widget.onBack ?? () => Navigator.pop(context),
                  ),
                  _NavButton(
                    icon: PhosphorIcons.shareNetwork(),
                    onTap: () async {
                      final link =
                          'https://staynest.top/properties/${widget.property.id}';
                      await Share.share(
                          '${widget.property.name} on StayNest: $link');
                      await AnalyticsService.trackPropertyShare(
                          widget.property.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Listing shared.')));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // 4. Fixed Bottom Action Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border:
                    Border(top: BorderSide(color: dividerColor, width: 1.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        if (AppSession.isGuest) {
                          _showLoginPrompt('Log in to message the landlord.');
                          return;
                        }
                        if (widget.onMessage != null) {
                          widget.onMessage!(
                            widget.property.agent.userId,
                            widget.property.agent.name,
                            widget.property.agent.avatar,
                          );
                        } else {
                          Navigator.pushNamed(
                            context,
                            '/chat',
                            arguments: <String, String>{
                              'userId': widget.property.agent.userId,
                              'name': widget.property.agent.name,
                              'avatar': widget.property.agent.avatar,
                            },
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade400, width: 1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Message',
                        style: GoogleFonts.poppins(
                          color: textDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (AppSession.isGuest) {
                          _showLoginPrompt('Log in to book a property visit.');
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingView(
                              propertyId: widget.property.id,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tenantPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Book a Visit',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Internal UI Components ───────────────────────────────────────────────

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Divider(height: 1, color: dividerColor, thickness: 1.2),
    );
  }

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.star_rounded, color: textDark, size: 20),
                const SizedBox(width: 8),
                Text(
                  _reviewCount > 0
                      ? '${_avgRating.toStringAsFixed(1)} · $_reviewCount reviews'
                      : 'No reviews yet',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_loadingReviews)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(color: tenantPrimary),
            ),
          )
        else if (_reviews.isEmpty)
          Text(
            'This property doesn\'t have any reviews yet.',
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: textLight,
            ),
          )
        else
          SizedBox(
            height: 180,
            child: PageView.builder(
              controller: _reviewPageController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final review = _reviews[index % _reviews.length];
                return Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: _buildCarouselCard(review),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReviewsView(
                  propertyId: widget.property.id,
                  propertyName: widget.property.name,
                  averageRating: _avgRating,
                  reviewCount: _reviewCount,
                  canReview: _eligibleBookingId != null,
                  hasReviewed: _hasReviewed,
                  bookingId: _eligibleBookingId,
                ),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: textDark, width: 1.2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Show all $_reviewCount reviews',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCarouselCard(Review review) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dividerColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: AppSession.buildAvatar(
                  review.reviewer?.avatar ?? '',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.reviewer?.name ?? 'Anonymous',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: textDark,
                          fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      DateFormat.yMMMd().format(review.createdAt),
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: textLight,
                          fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Text(
              review.comment ?? 'No comment provided.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: textDark.withOpacity(0.85),
                  height: 1.5,
                  fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getAmenityIcon(String amenity) {
    final lower = amenity.toLowerCase();
    if (lower.contains('wifi') || lower.contains('internet'))
      return PhosphorIcons.wifiHigh();
    if (lower.contains('water')) return PhosphorIcons.drop();
    if (lower.contains('electric') || lower.contains('power'))
      return PhosphorIcons.lightning();
    if (lower.contains('furnish')) return PhosphorIcons.armchair();
    if (lower.contains('park') || lower.contains('garage'))
      return PhosphorIcons.car();
    if (lower.contains('secur') || lower.contains('guard'))
      return PhosphorIcons.shieldCheck();
    if (lower.contains('cctv') || lower.contains('camera'))
      return PhosphorIcons.videoCamera();
    if (lower.contains('heat')) return PhosphorIcons.thermometer();
    if (lower.contains('ac') || lower.contains('air'))
      return PhosphorIcons.wind();
    if (lower.contains('pool')) return PhosphorIcons.swimmingPool();
    if (lower.contains('gym') || lower.contains('fitness'))
      return PhosphorIcons.barbell();
    return Icons.check_circle;
  }

  Widget _buildMinimalTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: dividerColor, width: 1.2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textDark),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomImage(String url, {double height = 120}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: buildPropertyImage(
        url,
        height: height,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
    );
  }
}
