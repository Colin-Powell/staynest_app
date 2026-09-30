import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';

import 'package:property_app/models/property.dart';
import 'package:property_app/models/property_taxonomy.dart';
import 'package:property_app/models/review.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/services/analytics/analytics_service.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/theme.dart';
import 'package:property_app/widgets/property_image.dart';

import 'amenities_view.dart';
import 'booking_view.dart';
import '../reviews_view.dart';

// ─── StayNest Design Tokens ───────────────────────────────────────────────────
const Color _dark = StayNestColors.textPrimaryLight;
const Color _grey = StayNestColors.textSecondaryLight;
const Color _surface = StayNestColors.surfaceLight;
const Color _stayNestPrimary = StayNestColors.primary;
const Color _dividerColor = StayNestColors.divider;
const double _maxWebWidth = 1200;

class PropertyDetails extends StatefulWidget {
  final Property property;
  final VoidCallback? onBack;
  final VoidCallback? onViewGallery;
  final VoidCallback? onViewAmenities;
  final VoidCallback? onViewLocation;
  final VoidCallback? onViewLandlord;
  final VoidCallback? onBookNow;
  final Function(String userId, String name, String avatar)? onMessage;
  final Future<void> Function({VoidCallback? onAuthenticated})?
      onRequireAuthentication;

  const PropertyDetails({
    super.key,
    required this.property,
    this.onBack,
    this.onViewGallery,
    this.onViewAmenities,
    this.onViewLocation,
    this.onViewLandlord,
    this.onBookNow,
    this.onMessage,
    this.onRequireAuthentication,
  });

  @override
  State<PropertyDetails> createState() => _PropertyDetailsState();
}

class _PropertyDetailsState extends State<PropertyDetails> {
  late final ScrollController _scrollController;

  final GlobalKey _photosKey = GlobalKey();
  final GlobalKey _amenitiesKey = GlobalKey();
  final GlobalKey _locationKey = GlobalKey();
  final GlobalKey _landlordKey = GlobalKey();
  final GlobalKey _reviewsKey = GlobalKey();
  GlobalKey? _bookingCardKey;

  GlobalKey get _mainBookingCardKey => _bookingCardKey ??= GlobalKey();

  bool _showAllReviews = false;
  bool _showLandlordDetails = false;
  bool _isDesktopScrolled = false;
  bool _loadingReviews = true;
  final bool _hasReviewed = false;

  List<Review> _reviews = [];
  List<Property> _landlordProperties = [];
  String? _eligibleBookingId;
  double _avgRating = 0.0;
  int _reviewCount = 0;
  DateTime? _viewStartTime;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    _viewStartTime = DateTime.now();
    _fetchReviews();
    _fetchLandlordProperties();
    _checkBookingEligibility();
  }

  void _handleScroll() {
    final bookingCardRenderObject =
        _mainBookingCardKey.currentContext?.findRenderObject();
    final shouldHideHeader = bookingCardRenderObject is RenderBox &&
        bookingCardRenderObject.hasSize &&
        bookingCardRenderObject.localToGlobal(Offset.zero).dy +
                bookingCardRenderObject.size.height <=
            80;
    if (shouldHideHeader != _isDesktopScrolled) {
      setState(() => _isDesktopScrolled = shouldHideHeader);
    }
  }

  void _scrollToKey(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _checkBookingEligibility() async {
    if (AppSession.isGuest) {
      return;
    }
  }

  Future<void> _fetchReviews() async {
    setState(() => _loadingReviews = true);
    try {
      final fetchedReviews = await RemoteDatabaseRepository()
          .fetchPropertyReviews(widget.property.id);
      if (!mounted) return;

      final count = fetchedReviews.length;
      final avg = count == 0
          ? 0.0
          : fetchedReviews
                  .map((review) => review.rating)
                  .fold<double>(0.0, (total, next) => total + next) /
              count;

      setState(() {
        _reviews = fetchedReviews;
        _reviewCount = count;
        _avgRating = avg;
        _loadingReviews = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingReviews = false);
    }
  }

  Future<void> _fetchLandlordProperties() async {
    final landlordId = widget.property.agent.userId;
    if (landlordId.isEmpty) return;

    try {
      final rawProperties =
          await RemoteDatabaseRepository().loadPropertiesForUser(landlordId);
      if (!mounted) return;

      final properties = rawProperties
          .map(Property.fromJson)
          .where((property) => property.id != widget.property.id)
          .toList();

      setState(() => _landlordProperties = properties);
    } catch (_) {
      if (!mounted) return;
      setState(() => _landlordProperties = const <Property>[]);
    }
  }

  void _shareProperty() async {
    final link = 'https://staynest.top/properties/${widget.property.id}';
    await Share.share('${widget.property.name} on StayNest: $link');
    await AnalyticsService.trackPropertyShare(widget.property.id);
  }

  void _handleMessageTap() {
    if (AppSession.isGuest) {
      widget.onRequireAuthentication?.call(
        onAuthenticated: () => widget.onMessage?.call(
          widget.property.agent.userId,
          widget.property.agent.name,
          widget.property.agent.avatar,
        ),
      );
      return;
    }
    if (widget.onMessage != null) {
      widget.onMessage!(widget.property.agent.userId,
          widget.property.agent.name, widget.property.agent.avatar);
    } else {
      Navigator.pushNamed(context, '/chat', arguments: <String, String>{
        'userId': widget.property.agent.userId,
        'name': widget.property.agent.name,
        'avatar': widget.property.agent.avatar,
      });
    }
  }

  void _handleBookTap() {
    if (!widget.property.isAvailableForBooking) return;
    if (AppSession.isGuest) {
      widget.onRequireAuthentication?.call(onAuthenticated: _openBooking);
      return;
    }
    _openBooking();
  }

  void _openBooking() {
    if (widget.onBookNow != null) {
      widget.onBookNow!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingView(propertyId: widget.property.id),
      ),
    );
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
    _scrollController.dispose();
    super.dispose();
  }

  // ─── MAIN BUILDER ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;
          return Stack(
            children: [
              isDesktop
                  ? _buildDesktopLayout(constraints)
                  : _buildMobileLayout(constraints),
              if (isDesktop) _buildDesktopStickyHeader(),
              if (!isDesktop) // Mobile Floating Bottom Bar
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: EdgeInsets.fromLTRB(24, 16, 24,
                            MediaQuery.of(context).padding.bottom + 16),
                        decoration: BoxDecoration(
                          color: _surface.withValues(alpha: 0.85),
                          border: const Border(
                              top:
                                  BorderSide(color: _dividerColor, width: 1.0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _handleMessageTap,
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  side: const BorderSide(
                                      color: _dark, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('Message',
                                    style: GoogleFonts.poppins(
                                        color: _dark,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _handleBookTap,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _stayNestPrimary,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('Reserve',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMobileLayout(BoxConstraints constraints) {
    final image = widget.property.images.isNotEmpty
        ? widget.property.images.first
        : widget.property.image;

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                if (widget.onBack != null)
                  IconButton(
                    tooltip: 'Back',
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'Share property',
                  onPressed: _shareProperty,
                  icon: const Icon(Icons.ios_share_rounded),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: GestureDetector(
            onTap: widget.onViewGallery,
            child: AspectRatio(
              aspectRatio: 1.15,
              child: buildPropertyImage(
                image,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(context).padding.bottom + 150,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text(
                'Entire home in ${widget.property.location}',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.property.features.rooms} bedrooms · ${widget.property.features.beds} beds · ${widget.property.features.baths} baths',
                style: GoogleFonts.poppins(fontSize: 15, color: _dark),
              ),
              const SizedBox(height: 24),
              _buildHostSection(),
              _buildDivider(),
              Text(
                'About this space',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.property.description.isNotEmpty
                    ? widget.property.description
                    : 'No description provided for this property.',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  height: 1.6,
                  color: _dark.withValues(alpha: 0.85),
                ),
              ),
              _buildDivider(),
              SizedBox(
                key: _amenitiesKey,
                child: _buildAmenitiesSection(),
              ),
              _buildDivider(),
              SizedBox(
                key: _locationKey,
                child: _buildLocationSection(),
              ),
              _buildDivider(),
              SizedBox(
                key: _landlordKey,
                child: _buildLandlordSection(),
              ),
              _buildDivider(),
              SizedBox(
                key: _reviewsKey,
                child: _buildReviewsSection(),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  // ─── DESKTOP STICKY HEADER ───────────────────────────────────────────────────
  Widget _buildDesktopStickyHeader() {
    return AnimatedPositioned(
      top: _isDesktopScrolled ? 0 : -100,
      left: 0,
      right: 0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          border:
              const Border(bottom: BorderSide(color: _dividerColor, width: 1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4))
          ],
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWebWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _StickyTab(
                            label: 'Photos',
                            onTap: () => _scrollToKey(_photosKey)),
                        _StickyTab(
                            label: 'Amenities', onTap: _openAmenitiesView),
                        _StickyTab(
                            label: 'Reviews',
                            onTap: () => _scrollToKey(_reviewsKey)),
                        _StickyTab(
                            label: 'Location',
                            onTap: () => _scrollToKey(_locationKey)),
                        _StickyTab(
                            label: 'Landlord',
                            onTap: () => _scrollToKey(_landlordKey)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  _buildDesktopBookingCard(isSticky: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── DESKTOP PROPERTY LAYOUT ─────────────────────────────────────────────────
  Widget _buildDesktopLayout(BoxConstraints constraints) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWebWidth),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
                child:
                    SizedBox(height: MediaQuery.of(context).padding.top + 24)),

            // Back Button (If navigated natively)
            if (widget.onBack != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.only(left: 24, right: 24, bottom: 24),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: widget.onBack,
                      child: Row(
                        children: [
                          const Icon(PhosphorIconsRegular.caretLeft,
                              size: 24, color: _dark),
                          const SizedBox(width: 8),
                          Text('Back to Search',
                              style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _dark)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Top Header: Title and Share/Save actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.property.name,
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: _dark,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _ActionTextButton(
                            icon: PhosphorIconsRegular.shareNetwork,
                            label: 'Share',
                            onTap: _shareProperty),
                        const SizedBox(width: 16),
                        _ActionTextButton(
                            icon: PhosphorIconsRegular.heart,
                            label: 'Save',
                            onTap: () {}),
                      ],
                    )
                  ],
                ),
              ),
            ),

            // Desktop property gallery
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 24, right: 24, top: 24, bottom: 32),
                child: SizedBox(
                  key: _photosKey,
                  height: 400,
                  child: _buildDesktopGallery(),
                ),
              ),
            ),

            // Main Two-Column Content Layout
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT COLUMN (Content)
                    Expanded(
                      flex: 65,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Brief Summary
                          Text(
                            'Stay in ${widget.property.location}',
                            style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: _dark),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.property.features.rooms} bedrooms · ${widget.property.features.beds} beds · ${widget.property.features.baths} baths',
                            style:
                                GoogleFonts.poppins(fontSize: 16, color: _dark),
                          ),
                          const SizedBox(height: 24),

                          // Big Review Banner
                          if (_reviewCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 24, horizontal: 24),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: _dividerColor, width: 1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.emoji_events_rounded,
                                          size: 32,
                                          color: StayNestColors.accent),
                                      const SizedBox(width: 16),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Top rated stay',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: _dark)),
                                          Text('Guest ratings and reviews',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 14, color: _grey)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(_avgRating.toStringAsFixed(2),
                                          style: GoogleFonts.poppins(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                              color: _dark)),
                                      Row(
                                        children: List.generate(
                                            5,
                                            (index) => const Icon(
                                                PhosphorIconsFill.star,
                                                size: 10,
                                                color: _dark)),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(_reviewCount.toString(),
                                          style: GoogleFonts.poppins(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                              color: _dark)),
                                      Text('Reviews',
                                          style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: _dark,
                                              decoration:
                                                  TextDecoration.underline)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          if (_reviewCount > 0) const SizedBox(height: 24),
                          _buildDivider(),

                          // Host Info
                          _buildHostSection(isDesktop: true),
                          _buildDivider(),

                          // Description
                          Text('About this space',
                              style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: _dark)),
                          const SizedBox(height: 16),
                          Text(
                            widget.property.description.isNotEmpty
                                ? widget.property.description
                                : 'No description provided for this property.',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                height: 1.6,
                                color: _dark.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w400),
                          ),
                          _buildDivider(),

                          // Amenities
                          SizedBox(
                              key: _amenitiesKey,
                              child: _buildAmenitiesSection(isDesktop: true)),
                        ],
                      ),
                    ),

                    const SizedBox(width: 56),

                    // RIGHT COLUMN (Booking Widget)
                    Expanded(
                      flex: 35,
                      child: Container(
                        alignment: Alignment.topCenter,
                        child: _buildDesktopBookingCard(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
                child: Divider(height: 64, color: _dividerColor, thickness: 1)),

            // Location precedes the final reviews section.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                    key: _locationKey,
                    child: _buildLocationSection(isDesktop: true)),
              ),
            ),

            const SliverToBoxAdapter(
                child: Divider(height: 64, color: _dividerColor, thickness: 1)),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                    key: _landlordKey,
                    child: _buildLandlordSection(isDesktop: true)),
              ),
            ),

            const SliverToBoxAdapter(
                child: Divider(height: 64, color: _dividerColor, thickness: 1)),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                    key: _reviewsKey,
                    child: _buildReviewsSection(isDesktop: true)),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  // ─── Desktop Special Elements ───

  Widget _buildDesktopGallery() {
    final images = widget.property.images.isNotEmpty
        ? widget.property.images
        : [
            widget.property.image,
            widget.property.image,
            widget.property.image,
            widget.property.image,
            widget.property.image
          ];
    final gridImages = List<String>.from(images);
    while (gridImages.length < 5) {
      gridImages.add(widget.property.image);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
              flex: 3,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                    onTap: widget.onViewGallery,
                    child: buildPropertyImage(gridImages[0],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity)),
              )),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                          child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                  onTap: widget.onViewGallery,
                                  child: buildPropertyImage(gridImages[1],
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity)))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                  onTap: widget.onViewGallery,
                                  child: buildPropertyImage(gridImages[2],
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity)))),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                          child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                  onTap: widget.onViewGallery,
                                  child: buildPropertyImage(gridImages[3],
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity)))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: widget.onViewGallery,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              buildPropertyImage(gridImages[4],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity),
                              Positioned(
                                bottom: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _dark)),
                                  child: Row(
                                    children: [
                                      const Icon(
                                          PhosphorIconsRegular.squaresFour,
                                          size: 16,
                                          color: _dark),
                                      const SizedBox(width: 8),
                                      Text('Show all photos',
                                          style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: _dark)),
                                    ],
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopBookingCard({bool isSticky = false}) {
    if (isSticky) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Ksh ${widget.property.price} / month',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(PhosphorIconsFill.star,
                      color: StayNestColors.accent, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    _reviewCount > 0
                        ? '${_avgRating.toStringAsFixed(2)} · $_reviewCount reviews'
                        : 'New',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _dark,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: _handleBookTap,
              style: FilledButton.styleFrom(
                backgroundColor: _stayNestPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Reserve',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      key: _mainBookingCardKey,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ksh ${widget.property.price}',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    Text('per month',
                        style: GoogleFonts.poppins(fontSize: 14, color: _grey)),
                  ],
                ),
              ),
              if (_reviewCount > 0) ...[
                const Icon(PhosphorIconsFill.star,
                    color: StayNestColors.accent, size: 16),
                const SizedBox(width: 4),
                Text(_avgRating.toStringAsFixed(1),
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _dark)),
              ],
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: _dividerColor),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _handleBookTap,
              style: FilledButton.styleFrom(
                backgroundColor: _stayNestPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Book this property',
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _handleMessageTap,
              icon: const Icon(PhosphorIconsRegular.chatCircleText, size: 18),
              label: Text('Message landlord',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _dark,
                side: const BorderSide(color: _dividerColor),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── General Section Component Builders ───

  Widget _buildHostSection({bool isDesktop = false}) {
    final agent = widget.property.agent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (isDesktop) {
              setState(() => _showLandlordDetails = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToKey(_landlordKey);
              });
            } else {
              widget.onViewLandlord?.call();
            }
          },
          child: Row(
            children: [
              ClipOval(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration:
                      BoxDecoration(border: Border.all(color: _dividerColor)),
                  child: AppSession.buildAvatar(
                    agent.avatar,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Hosted by ${agent.name}',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: _dark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (agent.verified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            PhosphorIconsFill.sealCheck,
                            color: Color(0xFF10B981),
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      agent.verified
                          ? 'Superhost · Verified Landlord'
                          : 'Landlord',
                      style: GoogleFonts.poppins(fontSize: 14, color: _grey),
                    ),
                  ],
                ),
              ),
              if (isDesktop)
                Icon(
                  _showLandlordDetails
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: _dark,
                ),
            ],
          ),
        ),
        if (isDesktop && _showLandlordDetails) ...[
          const SizedBox(height: 20),
          if ((agent.businessName ?? '').isNotEmpty)
            Text(
              agent.businessName!,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _dark,
              ),
            ),
          if ((agent.businessDescription ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              agent.businessDescription!,
              style:
                  GoogleFonts.poppins(fontSize: 14, height: 1.5, color: _grey),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              if (agent.propertyCount > 0)
                Text('${agent.propertyCount} listings',
                    style: GoogleFonts.poppins(fontSize: 13, color: _grey)),
              if ((agent.memberSince ?? '').isNotEmpty)
                Text('Member since ${agent.memberSince}',
                    style: GoogleFonts.poppins(fontSize: 13, color: _grey)),
              if (agent.responseTimeSeconds != null)
                Text(
                  'Responds in ${(agent.responseTimeSeconds! / 3600).ceil()} hours',
                  style: GoogleFonts.poppins(fontSize: 13, color: _grey),
                ),
            ],
          ),
        ],
      ],
    );
  }

  void _openAmenitiesView() {
    final onViewAmenities = widget.onViewAmenities;
    if (onViewAmenities != null) {
      onViewAmenities();
      return;
    }

    if (MediaQuery.sizeOf(context).width >= 900) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AmenitiesView(
          amenities: widget.property.amenities,
          customFeatures: widget.property.customFeatures,
          onClose: () => Navigator.pop(dialogContext),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AmenitiesView(
          amenities: widget.property.amenities,
          customFeatures: widget.property.customFeatures,
        ),
      ),
    );
  }

  Widget _buildAmenitiesSection({bool isDesktop = false}) {
    final combinedAmenities = [
      ...widget.property.amenities
          .map((id) => PropertyTaxonomy.getAttributeById(id)?.label ?? id),
      ...widget.property.customFeatures,
    ];
    final displayAmenities = combinedAmenities.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What this place offers',
            style: GoogleFonts.poppins(
                fontSize: 22, fontWeight: FontWeight.w600, color: _dark)),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isDesktop ? 2 : 2,
            childAspectRatio: 5,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
          ),
          itemCount: displayAmenities.length,
          itemBuilder: (context, index) {
            return Row(
              children: [
                const Icon(PhosphorIconsRegular.checkCircle,
                    size: 24, color: _dark),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    displayAmenities[index],
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: _dark,
                        fontWeight: FontWeight.w400),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 32),
        if (combinedAmenities.length > 6)
          SizedBox(
            width: isDesktop ? 240 : double.infinity,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: OutlinedButton(
                onPressed: _openAmenitiesView,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: _dark, width: 1.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Show all ${combinedAmenities.length} amenities',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _dark)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLocationSection({bool isDesktop = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Where you\'ll be',
            style: GoogleFonts.poppins(
                fontSize: 22, fontWeight: FontWeight.w600, color: _dark)),
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: isDesktop ? 480 : 320,
            width: double.infinity,
            child: IgnorePointer(
              child: FlutterMap(
                options: MapOptions(
                    initialCenter:
                        LatLng(widget.property.lat, widget.property.lng),
                    initialZoom: 14.0,
                    interactionOptions:
                        const InteractionOptions(flags: InteractiveFlag.none)),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.staynest.property_app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(widget.property.lat, widget.property.lng),
                        width: 60,
                        height: 60,
                        child: Center(
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _stayNestPrimary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4))
                              ],
                            ),
                            child: const Center(
                                child: Icon(PhosphorIconsFill.house,
                                    color: Colors.white, size: 20)),
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
        const SizedBox(height: 24),
        Text(widget.property.location,
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w600, color: _dark)),
        const SizedBox(height: 8),
        Text('Exact location provided after booking.',
            style: GoogleFonts.poppins(fontSize: 16, color: _dark)),
      ],
    );
  }

  Widget _buildLandlordSection({bool isDesktop = false}) {
    final agent = widget.property.agent;
    final listingCount = agent.propertyCount > 0
        ? agent.propertyCount
        : _landlordProperties.length + 1;
    final memberSince = agent.memberSince?.trim();
    final description = agent.businessDescription?.trim();
    final hasDescription = description != null && description.isNotEmpty;

    Widget hostStat(String value, String label) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 11, color: _grey),
            ),
          ],
        ),
      );
    }

    final hostSummary = Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipOval(
                      child: AppSession.buildAvatar(
                        agent.avatar,
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (agent.verified)
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: Container(
                          width: 25,
                          height: 25,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            PhosphorIconsFill.sealCheck,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  agent.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (agent.verified) ...[
                      const Icon(Icons.verified_rounded,
                          size: 13, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        agent.verified ? 'Verified host' : 'StayNest host',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 11, color: _grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(width: 1, height: 128, color: _dividerColor),
          const SizedBox(width: 18),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                hostStat('$_reviewCount', 'Property reviews'),
                const Divider(height: 1, color: _dividerColor),
                hostStat(
                  _reviewCount > 0
                      ? '${_avgRating.toStringAsFixed(1)} ★'
                      : 'New',
                  'Property rating',
                ),
                const Divider(height: 1, color: _dividerColor),
                hostStat('$listingCount', 'Listings'),
              ],
            ),
          ),
        ],
      ),
    );

    final hostDetails = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          agent.businessName?.trim().isNotEmpty == true
              ? agent.businessName!.trim()
              : 'About ${agent.name}',
          style: GoogleFonts.poppins(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: _dark,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          hasDescription ? description : 'This host has not added a bio yet.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: _dark.withValues(alpha: 0.85),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Host details',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _dark,
          ),
        ),
        const SizedBox(height: 10),
        if (agent.verified)
          _buildLandlordDetailRow(
            Icons.shield_outlined,
            'StayNest-verified host',
          ),
        if (memberSince != null && memberSince.isNotEmpty)
          _buildLandlordDetailRow(
            Icons.calendar_today_outlined,
            'Member since $memberSince',
          ),
        if (agent.responseTimeSeconds != null)
          _buildLandlordDetailRow(
            Icons.chat_bubble_outline_rounded,
            'Usually responds within ${(agent.responseTimeSeconds! / 3600).ceil()} hours',
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _handleMessageTap,
          icon: const Icon(PhosphorIconsRegular.chatCircleText, size: 18),
          label: const Text('Message host'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _dark,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            side: const BorderSide(color: _dividerColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meet your host',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: _dark,
          ),
        ),
        const SizedBox(height: 20),
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: hostSummary),
              const SizedBox(width: 40),
              Expanded(flex: 6, child: hostDetails),
            ],
          )
        else ...[
          hostSummary,
          const SizedBox(height: 24),
          hostDetails,
        ],
        const SizedBox(height: 32),
        if (_landlordProperties.isNotEmpty) ...[
          Text(
            'More places by ${agent.name}',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _landlordProperties.length.clamp(0, 6),
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final property = _landlordProperties[index];
                return SizedBox(
                  width: 250,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PropertyDetails(property: property),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(18),
                            ),
                            child: buildPropertyImage(
                              property.image,
                              width: 250,
                              height: 130,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    property.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _dark,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    property.location,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: _grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Ksh ${property.price}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: _dark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLandlordDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, size: 17, color: _grey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 13, color: _dark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection({bool isDesktop = false}) {
    final ratingCounts = <int, int>{
      for (var rating = 1; rating <= 5; rating++) rating: 0,
    };
    for (final review in _reviews) {
      if (ratingCounts.containsKey(review.rating)) {
        ratingCounts[review.rating] = ratingCounts[review.rating]! + 1;
      }
    }

    final visibleReviews =
        _showAllReviews ? _reviews : _reviews.take(10).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loadingReviews)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: _stayNestPrimary)))
        else if (_reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'This property doesn\'t have any reviews yet.',
              style: GoogleFonts.poppins(fontSize: 15, color: _grey),
            ),
          )
        else ...[
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded,
                        color: StayNestColors.accent, size: 38),
                    const SizedBox(width: 10),
                    Text(
                      _avgRating.toStringAsFixed(2),
                      style: GoogleFonts.poppins(
                        fontSize: 64,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.star_rounded,
                        color: StayNestColors.accent, size: 38),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _reviewCount >= 5 && _avgRating >= 4.8
                      ? 'Guest favorite'
                      : 'Guest rating',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Based on $_reviewCount guest reviews',
                  style: GoogleFonts.poppins(fontSize: 14, color: _grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          _buildRatingDistribution(ratingCounts, isDesktop: isDesktop),
          const SizedBox(height: 28),
          const Divider(height: 1, color: _dividerColor),
          const SizedBox(height: 20),
          Text(
            'Guest reviews mention',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _dark,
            ),
          ),
          const SizedBox(height: 14),
          _buildReviewMentions(),
          const SizedBox(height: 28),
          const Divider(height: 1, color: _dividerColor),
          const SizedBox(height: 22),
          Text(
            'Guest reviews',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 2 : 1,
              mainAxisExtent: isDesktop ? 210 : 220,
              crossAxisSpacing: 48,
              mainAxisSpacing: 24,
            ),
            itemCount: visibleReviews.length,
            itemBuilder: (context, index) =>
                _buildReviewCard(visibleReviews[index]),
          ),
          if (_reviews.length > 10) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: isDesktop ? 240 : double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  if (isDesktop) {
                    setState(() => _showAllReviews = !_showAllReviews);
                    return;
                  }
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
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: _dark, width: 1.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  isDesktop && _showAllReviews
                      ? 'Show fewer reviews'
                      : 'Show all ${_reviews.length} reviews',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _dark,
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildRatingDistribution(
    Map<int, int> ratingCounts, {
    required bool isDesktop,
  }) {
    final ratingBars = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overall rating',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _dark,
          ),
        ),
        const SizedBox(height: 8),
        for (final rating in [5, 4, 3, 2, 1])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  child: Text(
                    '$rating',
                    style: GoogleFonts.poppins(fontSize: 11, color: _grey),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: _reviewCount == 0
                        ? 0
                        : ratingCounts[rating]! / _reviewCount,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFE5E7EB),
                    color: _dark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 20,
                  child: Text(
                    '${ratingCounts[rating]}',
                    textAlign: TextAlign.end,
                    style: GoogleFonts.poppins(fontSize: 11, color: _grey),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    final reviewSummary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_reviewCount guest reviews',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _dark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ratings are shared by guests after their stay.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: _grey,
            height: 1.5,
          ),
        ),
      ],
    );

    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: double.infinity, child: ratingBars),
          const SizedBox(height: 16),
          reviewSummary,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 260, child: ratingBars),
        const SizedBox(width: 28),
        Container(width: 1, height: 92, color: _dividerColor),
        const SizedBox(width: 28),
        Expanded(child: reviewSummary),
      ],
    );
  }

  Widget _buildReviewMentions() {
    final topics = <Map<String, Object>>[
      {
        'label': 'Pool',
        'icon': Icons.pool_outlined,
        'terms': ['pool', 'swim']
      },
      {
        'label': 'Beach',
        'icon': Icons.beach_access_outlined,
        'terms': ['beach', 'shore']
      },
      {
        'label': 'Hospitality',
        'icon': Icons.waving_hand_outlined,
        'terms': ['host', 'welcoming', 'hospitality']
      },
      {
        'label': 'Family',
        'icon': Icons.family_restroom_rounded,
        'terms': ['family', 'kids', 'children']
      },
      {
        'label': 'Cleanliness',
        'icon': Icons.cleaning_services_outlined,
        'terms': ['clean', 'immaculate', 'tidy']
      },
      {
        'label': 'Location',
        'icon': Icons.location_on_outlined,
        'terms': ['location', 'nearby', 'walk']
      },
      {
        'label': 'Value',
        'icon': Icons.sell_outlined,
        'terms': ['value', 'price', 'affordable']
      },
    ];

    final mentions = topics
        .map((topic) {
          final terms = topic['terms']! as List<String>;
          final count = _reviews.where((review) {
            final comment = (review.comment ?? '').toLowerCase();
            return terms.any((term) =>
                RegExp('\\b${RegExp.escape(term)}\\b').hasMatch(comment));
          }).length;
          return (topic: topic, count: count);
        })
        .where((mention) => mention.count > 0)
        .toList();

    if (mentions.isEmpty) {
      return Text(
        'No recurring topics in reviews yet.',
        style: GoogleFonts.poppins(fontSize: 14, color: _grey),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final mention in mentions)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _dividerColor),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(mention.topic['icon']! as IconData,
                        size: 16, color: _dark),
                    const SizedBox(width: 8),
                    Text(
                      mention.topic['label']! as String,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${mention.count}',
                      style: GoogleFonts.poppins(fontSize: 12, color: _grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    final comment = review.comment?.trim() ?? '';
    final reviewerName = review.reviewer?.name ?? 'Anonymous';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipOval(
              child: AppSession.buildAvatar(
                review.reviewer?.avatar ?? '',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reviewerName,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _dark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    DateFormat.yMMMM().format(review.createdAt),
                    style: GoogleFonts.poppins(fontSize: 12, color: _grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  Icons.star_rounded,
                  size: 13,
                  color:
                      index < review.rating ? _dark : const Color(0xFFD1D5DB),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat.yMMMM().format(review.createdAt),
              style: GoogleFonts.poppins(fontSize: 12, color: _grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          comment.isEmpty ? 'No written comment.' : comment,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: _dark,
            height: 1.45,
          ),
        ),
        if (comment.length > 180)
          TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(reviewerName),
                content: SingleChildScrollView(child: Text(comment)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 24),
              alignment: Alignment.centerLeft,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Show more',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _dark,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
      ],
    );
  }

  // ─── Helpers ───

  Widget _buildDivider({bool isDesktop = false}) {
    return Padding(
      padding:
          EdgeInsets.symmetric(vertical: 32, horizontal: isDesktop ? 0 : 24),
      child: const Divider(height: 1, color: _dividerColor, thickness: 1.0),
    );
  }
}

// ─── Components ───

class _ActionTextButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTextButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 20, color: _dark),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _dark,
                    decoration: TextDecoration.underline)),
          ],
        ),
      ),
    );
  }
}

class _StickyTab extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _StickyTab({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(right: 24),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _dark,
            ),
          ),
        ),
      ),
    );
  }
}
