// lib/screens/reviews_view.dart
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:property_app/models/review.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:intl/intl.dart';
import 'property/write_review_view.dart';

// NOTE: This file also defines ReviewsView/AllReviewsView/WriteReviewView.
// Keep any named-parameter usages in this file consistent with these widget constructors.

// Removed the duplicate embedded WriteReviewView from this file.
// The actual implementation lives in frontend/lib/screens/property/write_review_view.dart.

// ==================== MAIN REVIEWS SCREEN ====================
class ReviewsView extends StatefulWidget {
  final String propertyId;
  final String? bookingId; // Passed if coming from a completed booking
  final String propertyName;

  final double averageRating;

  final int reviewCount;
  final bool canReview;
  final bool hasReviewed;

  const ReviewsView({
    super.key,
    required this.propertyId,
    this.bookingId,
    required this.propertyName,
    this.averageRating = 0.0,
    this.reviewCount = 0,
    this.canReview = false,
    this.hasReviewed = false,
  });

  @override
  State<ReviewsView> createState() => _ReviewsViewState();
}

class _ReviewsViewState extends State<ReviewsView>
    with TickerProviderStateMixin {
  final RemoteDatabaseRepository _repo = RemoteDatabaseRepository();
  late Future<List<Review>> _reviewsFuture;
  late bool _hasReviewed;

  late final AnimationController _pageCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _pageFade = CurvedAnimation(
    parent: _pageCtrl,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _pageSlide = Tween<Offset>(
    begin: const Offset(0.08, 0),
    end: Offset.zero,
  ).animate(_pageFade);

  @override
  void initState() {
    super.initState();
    _hasReviewed = widget.hasReviewed;
    _reviewsFuture = _repo.fetchPropertyReviews(widget.propertyId);
    _pageCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _navToWriteReview() {
    // Backend requires bookingId + auth + completed booking.
    // Prevent navigation when bookingId is missing.
    if (widget.bookingId == null || widget.bookingId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Missing booking reference. Please complete the booking before leaving a review.')),
      );
      return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            WriteReviewView(
          propertyId: widget.propertyId,
          propertyName: widget.propertyName,
          bookingId: widget.bookingId!,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                      .animate(CurvedAnimation(
                          parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
      ),
    ).then((value) {
      if (value == true) {
        setState(() {
          _hasReviewed = true;
          _reviewsFuture = _repo.fetchPropertyReviews(widget.propertyId);
        });
      }
    });
  }

  void _navToAllReviews() {
    // Ensure bookingId is set for write-review FAB.
    // If bookingId is missing, FAB/submit will be disabled.
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) => AllReviewsView(
          propertyId: widget.propertyId,
          propertyName: widget.propertyName,

          bookingId: widget.bookingId, // Pass bookingId down
          hasReviewed: _hasReviewed,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                      .animate(CurvedAnimation(
                          parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
      ),
    ).then((_) {
      // Refresh in case a review was added in the AllReviewsView
      setState(() {
        _reviewsFuture = _repo.fetchPropertyReviews(widget.propertyId);
        // We don't have a direct result from AllReviewsView here, but the
        // refresh in FutureBuilder will naturally hide elements if we relied on list length.
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _pageFade,
      child: SlideTransition(
        position: _pageSlide,
        child: Scaffold(
          backgroundColor: const Color(0xFFFFFFFF),
          body: Column(
            children: [
              _Header(title: 'Reviews', onBack: () => Navigator.pop(context)),
              Expanded(
                child: ScrollConfiguration(
                  behavior: const AppScrollBehavior(),
                  child: ListView(
                    physics: const BouncingScrollPhysics(
                      decelerationRate: ScrollDecelerationRate.fast,
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
                    children: [
                      FutureBuilder<List<Review>>(
                        future: _reviewsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final reviews = snapshot.data ?? [];

                          // SHOW BEAUTIFUL EMPTY STATE IF NO REVIEWS
                          if (reviews.isEmpty) {
                            return _buildEmptyState(
                              widget.canReview ? _navToWriteReview : null,
                              isEligible: widget.canReview,
                            );
                          }

                          // Calculate live stats for the utility header
                          Map<int, int> distribution = {
                            5: 0,
                            4: 0,
                            3: 0,
                            2: 0,
                            1: 0
                          };
                          double sum = 0;
                          for (var r in reviews) {
                            sum += r.rating;
                            if (r.rating >= 1 && r.rating <= 5) {
                              distribution[r.rating] =
                                  (distribution[r.rating] ?? 0) + 1;
                            }
                          }
                          final avg = reviews.isEmpty
                              ? widget.averageRating
                              : sum / reviews.length;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _OverallRatingSection(
                                rating: avg,
                                count: reviews.length,
                                ratingCounts: distribution,
                              ),
                              const SizedBox(height: 48),
                              const Text(
                                'Recent Reviews',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827)),
                              ),
                              const SizedBox(height: 24),
                              ...reviews.map((review) => ReviewCard(
                                    avatar: review.reviewer?.avatar ?? '',
                                    name: review.reviewer?.name ?? 'Anonymous',
                                    role: 'Tenant',
                                    rating: review.rating.toDouble(),
                                    review: review.comment ?? '',
                                    reviewId: review
                                        .id, // Pass review ID for reporting
                                    date: DateFormat.yMMMd()
                                        .format(review.createdAt),
                                  )),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // FLOATING ACTION BUTTON
          floatingActionButton: widget.canReview && !_hasReviewed
              ? ScaleTransition(
                  scale:
                      Tween<double>(begin: 0.85, end: 1.0).animate(_pageFade),
                  child: _buildAddReviewFab(),
                )
              : null,

          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withValues(alpha: 0.0), Colors.white],
                ),
              ),
              child: _OutlinedActionButton(
                text: 'View All Reviews',
                onTap: _navToAllReviews,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddReviewFab() {
    return GestureDetector(
      onTap: _navToWriteReview,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF3F3CD4),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3F3CD4).withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline_rounded,
                color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Add a Review',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reporting is currently disabled because RemoteDatabaseRepository does not
  // yet implement reportReview.
  Future<void> _reportReview(String reviewId, String reason) async {
    debugPrint('reportReview disabled: reviewId=$reviewId reason=$reason');
  }

  void _showReportReviewDialog(String reviewId) {
    final TextEditingController reportReasonController =
        TextEditingController();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Report Review',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please tell us why you are reporting this review:',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: reportReasonController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText:
                          'e.g., Inappropriate content, spam, fake review...',
                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (reportReasonController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Please provide a reason for reporting.')),
                          );
                          return;
                        }
                        Navigator.pop(context); // Close dialog
                        await _reportReview(
                          reviewId,
                          reportReasonController.text.trim(),
                        );

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Review reported successfully. Thank you!')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFEF4444), // Red color for report
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Submit Report',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }
}

// ==================== ALL REVIEWS SCREEN ====================
class AllReviewsView extends StatefulWidget {
  final String propertyId;
  final String propertyName;
  final String? bookingId; // Passed down to allow writing reviews here too
  final bool hasReviewed;

  const AllReviewsView({
    super.key,
    required this.propertyId,
    required this.propertyName,
    this.bookingId,
    this.hasReviewed = false,
  });

  @override
  State<AllReviewsView> createState() => _AllReviewsViewState();
}

class _AllReviewsViewState extends State<AllReviewsView> {
  final RemoteDatabaseRepository _repo = RemoteDatabaseRepository();
  late Future<List<Review>> _reviewsFuture;
  String _sortBy = 'Most Recent';
  int? _selectedRating;
  late bool _hasReviewed;

  @override
  void initState() {
    super.initState();
    _hasReviewed = widget.hasReviewed;
    _reviewsFuture = _repo.fetchPropertyReviews(widget.propertyId);
  }

  void _navToWriteReview() {
    if (widget.bookingId == null || widget.bookingId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Missing booking reference. Please complete the booking before leaving a review.')),
      );
      return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            WriteReviewView(
          propertyId: widget.propertyId,
          propertyName: widget.propertyName,
          bookingId: widget.bookingId!,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                      .animate(CurvedAnimation(
                          parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
      ),
    ).then((value) {
      if (value == true) {
        setState(() {
          _hasReviewed = true;
          _reviewsFuture = _repo.fetchPropertyReviews(widget.propertyId);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Column(
        children: [
          _Header(title: 'All Reviews', onBack: () => Navigator.pop(context)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Sort by:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _sortBy,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3F3CD4),
                  ),
                  items: ['Most Recent', 'Highest Rated'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() => _sortBy = newValue);
                    }
                  },
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                _RatingFilterChip(
                  label: 'All',
                  selected: _selectedRating == null,
                  onSelected: (_) => setState(() => _selectedRating = null),
                ),
                ...List.generate(5, (index) {
                  final rating = 5 - index;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _RatingFilterChip(
                      label: '$rating Stars',
                      selected: _selectedRating == rating,
                      onSelected: (_) =>
                          setState(() => _selectedRating = rating),
                    ),
                  );
                }),
              ],
            ),
          ),
          Expanded(
            child: ScrollConfiguration(
              behavior: const AppScrollBehavior(),
              child: FutureBuilder<List<Review>>(
                future: _reviewsFuture,
                builder: (context, snapshot) {
                  final bool isLoading =
                      snapshot.connectionState == ConnectionState.waiting;
                  final List<Review> reviews = List.from(snapshot.data ?? []);

                  if (!isLoading && reviews.isNotEmpty) {
                    // Filter by rating
                    if (_selectedRating != null) {
                      reviews.retainWhere((r) => r.rating == _selectedRating);
                    }

                    if (_sortBy == 'Most Recent') {
                      reviews
                          .sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    } else if (_sortBy == 'Highest Rated') {
                      reviews.sort((a, b) => b.rating.compareTo(a.rating));
                    }
                  }

                  if (isLoading) {
                    return ListView.builder(
                      itemCount: 5,
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                      itemBuilder: (context, index) =>
                          const _ReviewCardSkeleton(),
                    );
                  }

                  // EMPTY STATE FOR ALL REVIEWS SCREEN
                  if (reviews.isEmpty) {
                    return _buildEmptyState(
                      widget.bookingId != null ? _navToWriteReview : null,
                      isEligible: widget.bookingId != null,
                      isFiltered: (snapshot.data?.isNotEmpty ?? false) &&
                          _selectedRating != null,
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                    itemCount: reviews.length,
                    itemBuilder: (context, index) {
                      final review = reviews[index];
                      return ReviewCard(
                        avatar: review.reviewer?.avatar ?? '',
                        name: review.reviewer?.name ?? 'Anonymous',
                        role: 'Tenant',
                        rating: review.rating.toDouble(),
                        review: review.comment ?? '',
                        reviewId: review.id, // Pass review ID for reporting
                        onReport:
                            () {}, // Reporting wiring handled in parent view
                        date: DateFormat.yMMMd().format(review.createdAt),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),

      // FLOATING ACTION BUTTON
      floatingActionButton: (widget.bookingId != null && !_hasReviewed)
          ? GestureDetector(
              onTap: _navToWriteReview,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3F3CD4),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3F3CD4).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline_rounded,
                        color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Add a Review',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// ==================== SHARED WIDGETS ====================

Widget _buildEmptyState(
  VoidCallback? onAddReview, {
  bool isEligible = false,
  bool isFiltered = false,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.rate_review_outlined,
                size: 48, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 24),
          Text(
            isFiltered ? 'No matches' : 'No reviews yet',
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered
                ? 'No reviews match your filter. Try adjusting your selection.'
                : (isEligible
                    ? 'Be the first to share your experience!'
                    : 'Only verified guests with completed bookings can leave reviews.'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _Header({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 16,
        left: 20,
        right: 20,
      ),
      color: Colors.white,
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: const Icon(Icons.arrow_back,
                size: 28, color: Color(0xFF111827)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverallRatingSection extends StatelessWidget {
  final double rating;
  final int count;
  final Map<int, int> ratingCounts;

  const _OverallRatingSection({
    required this.rating,
    required this.count,
    required this.ratingCounts,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overall Rating',
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF9CA3AF),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                height: 1.1,
                letterSpacing: -2,
              ),
            ),
            const SizedBox(width: 24),
            _StarRating(rating: rating),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '($count reviews)',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 32),
        // Progress Bars Stacked Below
        Column(
          children: List.generate(5, (index) {
            final star = 5 - index;
            final value = count > 0 ? (ratingCounts[star] ?? 0) / count : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    child: Text(
                      '${5 - index}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.star_rounded,
                      size: 16, color: Color(0xFFD1D5DB)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBBF24),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

class ReviewCard extends StatelessWidget {
  final String avatar;
  final String name;
  final String role;
  final double rating;
  final String review;
  final String date;
  final String reviewId; // Added for reporting feature
  final VoidCallback? onReport;

  const ReviewCard({
    super.key,
    required this.avatar,
    required this.name,
    required this.role,
    required this.rating,
    required this.review,
    required this.date,
    required this.reviewId, // Added for reporting feature
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: AppSession.buildAvatar(
                  avatar,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16.5,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role,
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFFBBF24), size: 22),
                  const SizedBox(width: 4),
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              const Spacer(), // Pushes report icon to the right
              GestureDetector(
                onTap: onReport,
                child: const Icon(
                  Icons.flag_outlined,
                  color: Color(0xFF9CA3AF),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            review,
            style: const TextStyle(
              height: 1.5,
              fontSize: 15,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            date,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlinedActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _OutlinedActionButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF3F3CD4),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF3F3CD4),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  final double rating;
  final double size;
  final Color color;
  final Color backgroundColor;

  const _StarRating({
    required this.rating,
    this.size = 18,
    this.color = const Color(0xFFFBBF24),
    this.backgroundColor = const Color(0xFFE5E7EB),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        double fill = 0.0;
        if (rating >= index + 1) {
          fill = 1.0;
        } else if (rating > index) {
          fill = rating - index;
        }

        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: CustomPaint(
            size: Size(size, size),
            painter: _StarPainter(
              fill: fill,
              color: color,
              backgroundColor: backgroundColor,
            ),
          ),
        );
      }),
    );
  }
}

class _StarPainter extends CustomPainter {
  final double fill;
  final Color color;
  final Color backgroundColor;

  _StarPainter({
    required this.fill,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    const iconData = Icons.star_rounded;
    final textStyle = TextStyle(
      fontSize: size.width,
      fontFamily: iconData.fontFamily,
      package: iconData.fontPackage,
    );

    // 1. Draw Background Star
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: textStyle.copyWith(color: backgroundColor),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);

    // 2. Draw Foreground Star with Clipping
    if (fill > 0) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width * fill, size.height));
      textPainter.text = TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: textStyle.copyWith(color: color),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class _RatingFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _RatingFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : const Color(0xFF6B7280),
      ),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      selectedColor: const Color(0xFF3F3CD4),
      backgroundColor: const Color(0xFFF3F4F6),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.transparent),
      ),
    );
  }
}

class AppScrollBehavior extends ScrollBehavior {
  const AppScrollBehavior();
  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(
          decelerationRate: ScrollDecelerationRate.fast);
}

class _SkeletonPlaceholder extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _SkeletonPlaceholder({
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<_SkeletonPlaceholder> createState() => _SkeletonPlaceholderState();
}

class _SkeletonPlaceholderState extends State<_SkeletonPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

class _ReviewCardSkeleton extends StatelessWidget {
  const _ReviewCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SkeletonPlaceholder(width: 52, height: 52, borderRadius: 26),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonPlaceholder(width: 120, height: 16),
                  SizedBox(height: 8),
                  _SkeletonPlaceholder(width: 80, height: 12),
                ],
              ),
              Spacer(),
              _SkeletonPlaceholder(width: 40, height: 20),
            ],
          ),
          SizedBox(height: 16),
          _SkeletonPlaceholder(width: double.infinity, height: 14),
          SizedBox(height: 8),
          _SkeletonPlaceholder(width: 200, height: 14),
          SizedBox(height: 12),
          _SkeletonPlaceholder(width: 100, height: 12),
        ],
      ),
    );
  }
}

class _OverallRatingSkeleton extends StatelessWidget {
  const _OverallRatingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SkeletonPlaceholder(width: 100, height: 14),
        const SizedBox(height: 8),
        Row(
          children: [
            const _SkeletonPlaceholder(width: 80, height: 64),
            const SizedBox(width: 24),
            Row(
              children: List.generate(
                5,
                (i) => const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: _SkeletonPlaceholder(
                      width: 32, height: 32, borderRadius: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const _SkeletonPlaceholder(width: 90, height: 14),
        const SizedBox(height: 32),
        Column(
          children: List.generate(5, (index) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  _SkeletonPlaceholder(width: 12, height: 14),
                  SizedBox(width: 8),
                  _SkeletonPlaceholder(width: 16, height: 16, borderRadius: 8),
                  SizedBox(width: 16),
                  Expanded(
                      child: _SkeletonPlaceholder(
                          width: double.infinity, height: 8)),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}
