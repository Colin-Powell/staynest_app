// lib/screens/dashboard/property_details.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
  static const Color tenantPrimary = Color(0xFF3F37C9); // Tenant Blue
  static const Color textDark = Color(0xFF111827);
  static const Color textLight = Color(0xFF6B7280);

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
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Soft Gradient Background (Tenant Blue Theme)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF5F7FF), // Soft icy blue
                  Color(0xFFEBF0FF), // Light indigo
                  Color(0xFFDCE4FF), // Deeper soft blue
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // 2. Fading Hero Image
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 440,
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.black, Colors.transparent],
                stops: [0.0, 0.6, 1.0],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
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
          ),

          // 3. Main Scrolling Content
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Top Navigation Row
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _GlassCircleButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: widget.onBack ?? () => Navigator.pop(context),
                        ),
                        _GlassCircleButton(
                          icon: PhosphorIcons.shareNetwork(),
                          onTap: () {
                            AnalyticsService.trackPropertyShare(widget.property.id);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Listing link copied to clipboard.')));
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Spacer to push content down into the faded area of the image
                const SliverToBoxAdapter(child: SizedBox(height: 200)),

                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 140), // Bottom padding for fixed buttons
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Header & Snapshot Section ---
                        _GlassContainer(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.property.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  height: 1.2,
                                  color: textDark,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    'Kes. ${widget.property.price ~/ 1000}k',
                                    style: GoogleFonts.poppins(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: tenantPrimary,
                                    ),
                                  ),
                                  Text(
                                    '/mo',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: textLight,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Divider(color: Colors.white.withOpacity(0.6), height: 1, thickness: 1.5),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill), size: 18, color: textLight),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      widget.property.location,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: textLight,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
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
                                    const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 20),
                                    const SizedBox(width: 6),
                                    if (_reviewCount > 0) ...[
                                      Text(
                                        _avgRating.toStringAsFixed(1),
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: textDark,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '($_reviewCount Reviews)',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: textLight,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ] else
                                      Text(
                                        'No reviews yet',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: textLight,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // --- Property Tags (Your Signature Pills) ---
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildTag(Icons.apartment_rounded, widget.property.category, true),
                            _buildTag(Icons.door_front_door_rounded, '${widget.property.features.rooms} Room', false),
                            _buildTag(Icons.bed_rounded, '${widget.property.features.beds} beds', false),
                            if (widget.property.features.furnished)
                              _buildTag(Icons.weekend_rounded, 'Furnished', false),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // --- Quick Navigation Action Pills ---
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _ShortcutPill(icon: PhosphorIcons.image(), label: 'Gallery', onTap: widget.onViewGallery ?? () {}),
                              _ShortcutPill(icon: PhosphorIcons.listChecks(), label: 'Amenities', onTap: widget.onViewAmenities ?? () {}),
                              _ShortcutPill(icon: PhosphorIcons.mapTrifold(), label: 'Location', onTap: widget.onViewLocation ?? () {}),
                              _ShortcutPill(icon: PhosphorIcons.userCircle(), label: 'Landlord', onTap: widget.onViewLandlord ?? () {}),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // --- About Property Section ---
                        Text(
                          'About Property',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: textDark),
                        ),
                        const SizedBox(height: 16),
                        _GlassContainer(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            widget.property.description.isNotEmpty
                                ? widget.property.description
                                : 'No description provided for this property.',
                            style: GoogleFonts.poppins(
                              fontSize: 14.5,
                              height: 1.6,
                              color: textDark.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // --- Spacious Rooms Area ---
                        Text(
                          'Interior Preview',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: textDark),
                        ),
                        const SizedBox(height: 16),
                        _GlassContainer(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.property.amenities.isNotEmpty)
                                Column(
                                  children: widget.property.amenities
                                      .take(2)
                                      .map((a) => Padding(
                                            padding: const EdgeInsets.only(bottom: 12),
                                            child: _buildWhiteCircleIcon(PhosphorIcons.checkCircle()),
                                          ))
                                      .toList(),
                                )
                              else
                                Column(
                                  children: [
                                    _buildWhiteCircleIcon(PhosphorIcons.drop()),
                                    const SizedBox(height: 12),
                                    _buildWhiteCircleIcon(PhosphorIcons.car()),
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
                                      Expanded(child: _buildRoomImage(previewPhotos[0], height: 110)),
                                      const SizedBox(width: 10),
                                      Expanded(child: _buildRoomImage(previewPhotos[1], height: 110)),
                                      const SizedBox(width: 10),
                                      Expanded(child: _buildRoomImage(previewPhotos[2], height: 110)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // --- Reviews Carousel Section ---
                        _buildReviewsCarousel(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Subtle Bottom Gradient Fade (Ensures buttons pop)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 140,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFFDCE4FF).withOpacity(0.6),
                      const Color(0xFFDCE4FF),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 5. Floating Action Buttons (No clunky white container)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 24),
              child: Row(
                children: [
                  Expanded(
                    child: _GlassContainer(
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(16),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
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
                          child: Container(
                            height: 56,
                            alignment: Alignment.center,
                            child: Text(
                              'Message',
                              style: GoogleFonts.poppins(
                                color: tenantPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: tenantPrimary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: tenantPrimary.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookingView(
                                propertyId: widget.property.id,
                              ),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(16),
                          child: Center(
                            child: Text(
                              'Book a Visit',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
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

  Widget _buildReviewsCarousel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reviews',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textDark,
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
              child: Text(
                'See All',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tenantPrimary,
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
              child: CircularProgressIndicator(color: tenantPrimary),
            ),
          )
        else if (_reviews.isEmpty)
          _GlassContainer(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(PhosphorIcons.star(), color: textLight, size: 32),
                const SizedBox(height: 12),
                Text(
                  'No reviews yet',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: textLight,
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
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              ClipOval(
                child: AppSession.buildAvatar(
                  review.reviewer?.avatar ?? '',
                  width: 40,
                  height: 40,
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
                          fontWeight: FontWeight.w700,
                          color: textDark,
                          fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          review.rating.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: textLight),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                DateFormat.yMMMd().format(review.createdAt),
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: textLight,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.comment ?? 'No comment provided.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
                fontSize: 13,
                color: textDark.withOpacity(0.8),
                height: 1.4,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // NOTE: SIGNATURE PILLS KEPT INTACT AS REQUESTED
  Widget _buildTag(IconData icon, String label, bool isPrimary) {
    return Container(
      padding: const EdgeInsets.only(left: 6, right: 16, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: isPrimary ? tenantPrimary : Colors.white.withOpacity(0.6),
        border: Border.all(color: isPrimary ? tenantPrimary : Colors.white, width: 1.5),
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
              color: isPrimary ? tenantPrimary : textLight,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isPrimary ? Colors.white : textDark,
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
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white),
      ),
      child: Icon(
        icon,
        color: tenantPrimary,
        size: 20,
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
}

class _ShortcutPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ShortcutPill(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 1.5)),
        child: Row(children: [
          Icon(icon, size: 18, color: const Color(0xFF3F37C9)), // Tenant Blue
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111827))),
        ]),
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.4)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
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
    this.blur = 20.0,
    this.opacity = 0.55,
    this.borderWidth = 1.5,
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