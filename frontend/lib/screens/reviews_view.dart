// lib/screens/reviews_view.dart
import 'package:flutter/material.dart';
import 'package:property_app/models/review.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:intl/intl.dart';

// ==================== MAIN REVIEWS SCREEN ====================
class ReviewsView extends StatefulWidget {
  final String propertyId;
  final String? bookingId; // Passed if coming from a completed booking
  final double averageRating;
  final int reviewCount;

  const ReviewsView({
    super.key,
    required this.propertyId,
    this.bookingId,
    this.averageRating = 0.0,
    this.reviewCount = 0,
  });

  @override
  State<ReviewsView> createState() => _ReviewsViewState();
}

class _ReviewsViewState extends State<ReviewsView>
    with TickerProviderStateMixin {
  final RemoteDatabaseRepository _repo = RemoteDatabaseRepository();
  late Future<List<Review>> _reviewsFuture;

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
    _reviewsFuture = _repo.fetchPropertyReviews(widget.propertyId);
    _pageCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _navToWriteReview() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            WriteReviewView(
          propertyId: widget.propertyId,
          bookingId: widget.bookingId ?? '',
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
        setState(() =>
            _reviewsFuture = _repo.fetchPropertyReviews(widget.propertyId));
      }
    });
  }

  void _navToAllReviews() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            AllReviewsView(
          propertyId: widget.propertyId,
          bookingId: widget.bookingId, // Pass bookingId down
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
      setState(() =>
          _reviewsFuture = _repo.fetchPropertyReviews(widget.propertyId));
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
                      _OverallRatingSection(
                        rating: widget.averageRating,
                        count: widget.reviewCount,
                      ),
                      const SizedBox(height: 40),
                      const Divider(
                          color: Color(0xFFF3F4F6), thickness: 1.5, height: 1),
                      const SizedBox(height: 32),
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
                              // Only provide add review function if eligible
                              widget.bookingId != null ? _navToWriteReview : null
                            );
                          }
                          
                          // Show top 3 reviews on main view
                          return Column(
                            children: reviews
                                .take(3)
                                .map((review) => ReviewCard(
                                      avatar: review.reviewer?.avatar ?? '',
                                      name:
                                          review.reviewer?.name ?? 'Anonymous',
                                      role: 'Tenant',
                                      rating: review.rating.toDouble(),
                                      review: review.comment ?? '',
                                      date: DateFormat.yMMMd()
                                          .format(review.createdAt),
                                    ))
                                .toList(),
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
          floatingActionButton: widget.bookingId != null
              ? GestureDetector(
                  onTap: _navToWriteReview,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
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
}

// ==================== ALL REVIEWS SCREEN ====================
class AllReviewsView extends StatefulWidget {
  final String propertyId;
  final String? bookingId; // Passed down to allow writing reviews here too

  const AllReviewsView({super.key, required this.propertyId, this.bookingId});

  @override
  State<AllReviewsView> createState() => _AllReviewsViewState();
}

class _AllReviewsViewState extends State<AllReviewsView> {
  final RemoteDatabaseRepository _repo = RemoteDatabaseRepository();
  late Future<List<Review>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = _repo.fetchPropertyReviews(widget.propertyId);
  }

  void _navToWriteReview() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            WriteReviewView(
          propertyId: widget.propertyId,
          bookingId: widget.bookingId ?? '',
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
        setState(() =>
            _reviewsFuture = _repo.fetchPropertyReviews(widget.propertyId));
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
          Expanded(
            child: ScrollConfiguration(
              behavior: const AppScrollBehavior(),
              child: FutureBuilder<List<Review>>(
                future: _reviewsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final reviews = snapshot.data ?? [];
                  
                  // EMPTY STATE FOR ALL REVIEWS SCREEN
                  if (reviews.isEmpty) {
                    return _buildEmptyState(
                      widget.bookingId != null ? _navToWriteReview : null
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
      floatingActionButton: widget.bookingId != null
          ? GestureDetector(
              onTap: _navToWriteReview,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
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

// ==================== WRITE REVIEW SCREEN ====================
class WriteReviewView extends StatefulWidget {
  final String propertyId;
  final String bookingId;

  const WriteReviewView(
      {super.key, required this.propertyId, required this.bookingId});

  @override
  State<WriteReviewView> createState() => _WriteReviewViewState();
}

class _WriteReviewViewState extends State<WriteReviewView>
    with TickerProviderStateMixin {
  final RemoteDatabaseRepository _repo = RemoteDatabaseRepository();
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

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

  double _rating = 4.0;

  @override
  void initState() {
    super.initState();
    _pageCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);
    try {
      final review = await _repo.submitReview(
        bookingId: widget.bookingId,
        propertyId: widget.propertyId,
        rating: _rating.toInt(),
        comment: _commentController.text.trim(),
      );
      if (review != null) {
        if (!mounted) return;
        _showSuccessModal();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit review')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessModal() {
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
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD1FAE5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF10B981),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Review Submitted!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Thank you for sharing your experience. Your review helps others find great places.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 32),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context); // Close Dialog
                      Navigator.pop(context,
                          true); // Close WriteReviewView with success signal
                    },
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3F3CD4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'Done',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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
              _Header(
                  title: 'Write a Review',
                  onBack: () => Navigator.pop(context)),
              Expanded(
                child: ScrollConfiguration(
                  behavior: const AppScrollBehavior(),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Overall Rating',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(5, (index) {
                            return Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _rating = index + 1.0),
                                child: Icon(
                                  Icons.star_rounded,
                                  color: index < _rating
                                      ? const Color(0xFFFBBF24)
                                      : const Color(0xFFD1D5DB),
                                  size: 48,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'Your Review',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFE5E7EB), width: 1.5),
                          ),
                          child: TextField(
                            controller: _commentController,
                            maxLines: 8,
                            decoration: const InputDecoration(
                              hintText: 'Share your experience...',
                              hintStyle: TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 15,
                              ),
                              contentPadding: EdgeInsets.all(20),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: _OutlinedActionButton(
                    text: _isSubmitting ? 'Submitting...' : 'Submit Review',
                    onTap: _isSubmitting ? () {} : _handleSubmit,
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

// ==================== SHARED WIDGETS ====================

Widget _buildEmptyState(VoidCallback? onAddReview) {
  return Padding(
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
          child: const Icon(Icons.rate_review_outlined, size: 48, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 24),
        const Text(
          'No reviews yet',
          style: TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.w800, 
            color: Color(0xFF111827)
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Be the first to share your experience!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15, 
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
        // Display the big button if the user is eligible
        if (onAddReview != null) ...[
          const SizedBox(height: 32),
          GestureDetector(
            onTap: onAddReview,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF3F3CD4),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3F3CD4).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Text(
                'Add a Review',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ],
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

  const _OverallRatingSection({required this.rating, required this.count});

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
            Row(
              children: List.generate(
                5,
                (i) => const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFBBF24),
                    size: 32,
                  ),
                ),
              ),
            ),
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
            final value = [0.9, 0.65, 0.45, 0.25, 0.1][index];
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

  const ReviewCard({
    super.key,
    required this.avatar,
    required this.name,
    required this.role,
    required this.rating,
    required this.review,
    required this.date,
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
                child: Image.network(
                  avatar,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 52,
                      height: 52,
                      color: const Color(0xFFF3F4F6),
                      child: const Icon(Icons.person, color: Color(0xFF9CA3AF)),
                    );
                  },
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