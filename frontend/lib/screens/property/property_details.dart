// lib/screens/dashboard/property_details.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/models/property.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/screens/dashboard/analytics_service.dart';
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
  List<Review> _reviews = [];
  bool _loadingReviews = true;
  String? _eligibleBookingId;
  bool _hasReviewed = false;

  // ─── Computed getters — single source of truth for rating & count ──────────
  double get _avgRating => _reviews.isEmpty
      ? widget.property.rating
      : _reviews.map((r) => r.rating).reduce((a, b) => a + b) /
          _reviews.length;

  int get _reviewCount =>
      _reviews.isEmpty ? widget.property.reviews : _reviews.length;

  // Carousel Controllers
  final PageController _reviewPageController =
      PageController(viewportFraction: 1.0);
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.trackPropertyView(widget.property.id,
          source: 'property_details');
      AnalyticsService.trackPropertyDetailView(widget.property.id);
    });
  }

  @override
  void dispose() {
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

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.35)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 18),
                  onPressed: widget.onBack ?? () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Hero Image
            GestureDetector(
              onTap: widget.onViewGallery,
              child: Hero(
                tag: 'property-${widget.property.id}',
                child: buildPropertyImage(
                  widget.property.image,
                  width: double.infinity,
                  height: 380,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Main Content Container
            Container(
              margin: const EdgeInsets.only(top: 340),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      widget.property.name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Rating and Location
                    Row(
                      children: [
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
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Color(0xFFFBBF24), size: 24),
                              const SizedBox(width: 6),
                              if (_reviewCount > 0) ...[
                                Text(
                                  _avgRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '($_reviewCount Reviews)',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF9CA3AF),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ] else
                                const Text(
                                  'No reviews yet',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF9CA3AF),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          widget.property.location,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Kes. ${widget.property.price ~/ 1000}k',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                        const Text(
                          '/month',
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Property Tags
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildTag(Icons.apartment_rounded,
                            widget.property.category, true),
                        _buildTag(Icons.door_front_door_rounded,
                            '${widget.property.features.rooms} Room', false),
                        _buildTag(Icons.bed_rounded,
                            '${widget.property.features.beds} beds', false),
                        if (widget.property.features.furnished)
                          _buildTag(Icons.weekend_rounded, 'Furnished', false),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Property Photos
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4FD),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildWhiteCircleIcon(
                                  Icons.photo_library_outlined),
                              const SizedBox(width: 16),
                              const Text(
                                'Property Photos',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B72E2),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.property.amenities.isNotEmpty)
                                Column(
                                  children: widget.property.amenities
                                      .take(2)
                                      .map((a) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 12),
                                            child: _buildWhiteCircleIcon(
                                                Icons.check_circle_outline),
                                          ))
                                      .toList(),
                                )
                              else
                                Column(
                                  children: [
                                    _buildWhiteCircleIcon(
                                        Icons.water_drop_outlined),
                                    const SizedBox(height: 12),
                                    _buildWhiteCircleIcon(
                                        Icons.local_parking_rounded),
                                  ],
                                ),
                              if (widget.property.amenities.isNotEmpty)
                                const SizedBox(width: 16),
                              const SizedBox(width: 16),
                              Expanded(
                                child: GestureDetector(
                                  onTap: widget.onViewGallery,
                                  child: Row(
                                    children: [
                                      Expanded(
                                          child: _buildRoomImage(
                                              previewPhotos[0],
                                              height: 120)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: _buildRoomImage(
                                              previewPhotos[1],
                                              height: 120)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: _buildRoomImage(
                                              previewPhotos[2],
                                              height: 120)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // About Property
                    const Text(
                      'About Property',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.property.description.isNotEmpty
                          ? widget.property.description
                          : 'No description provided for this property.',
                      style: const TextStyle(
                        fontSize: 15.5,
                        height: 1.6,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Reviews Carousel
                    _buildReviewsCarousel(),

                    const SizedBox(height: 32),

                    // Navigation Tabs
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildNavTab('Amenities',
                            onTap: widget.onViewAmenities),
                        _buildNavTab('Gallery', onTap: widget.onViewGallery),
                        _buildNavTab('Reviews', onTap: () {
                          Navigator.push(
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
                          ).then((_) => _fetchReviews());
                        }),
                        _buildNavTab('Location', onTap: widget.onViewLocation),
                        _buildNavTab('Landlord', onTap: widget.onViewLandlord),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Bottom Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/chat',
                                arguments: <String, String>{
                                  'userId': widget.property.agent.userId,
                                  'name': widget.property.agent.name,
                                  'avatar': widget.property.agent.avatar,
                                },
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'Message',
                                style: TextStyle(
                                  color: Color(0xFF3F37C9),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookingView(
                                  propertyId: widget.property.id,
                                ),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3F37C9),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text(
                              'Book a Visit',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
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
          ],
        ),
      ),
    );
  }

  // ─── Reviews Carousel ─────────────────────────────────────────────────────
  // Eligibility banners and rating breakdown bars are intentionally removed —
  // the main file handles that summary. This section shows only the header
  // with a "See All" link and the auto-scrolling review cards.

  Widget _buildReviewsCarousel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Reviews',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
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
              child: const Text(
                'See All',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3F37C9),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loadingReviews)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_reviews.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Column(
              children: [
                Icon(Icons.reviews_outlined,
                    color: Color(0xFF9CA3AF), size: 32),
                SizedBox(height: 12),
                Text(
                  'No reviews yet',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 150,
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.1, 0.9, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: PageView.builder(
                controller: _reviewPageController,
                scrollDirection: Axis.vertical,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final review = _reviews[index % _reviews.length];
                  return _buildCarouselCard(review);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCarouselCard(Review review) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              ClipOval(
                child: buildPropertyImage(
                  review.reviewer?.avatar ?? '',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorPlaceholder: Container(
                    width: 40,
                    height: 40,
                    color: const Color(0xFFE5E7EB),
                    child:
                        const Icon(Icons.person, color: Color(0xFF9CA3AF)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.reviewer?.name ?? 'Anonymous',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFFBBF24), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          review.rating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                DateFormat.yMMMd().format(review.createdAt),
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.comment ?? 'No comment provided.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.4,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String label, bool isPrimary) {
    return Container(
      padding: const EdgeInsets.only(left: 6, right: 16, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFF3F37C9) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 16,
              color: isPrimary
                  ? const Color(0xFF3F37C9)
                  : const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: isPrimary ? Colors.white : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhiteCircleIcon(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: const Color(0xFF6B72E2),
        size: 22,
      ),
    );
  }

  Widget _buildRoomImage(String url, {double height = 120}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: buildPropertyImage(
        url,
        height: height,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildNavTab(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF3F37C9),
        ),
      ),
    );
  }
}