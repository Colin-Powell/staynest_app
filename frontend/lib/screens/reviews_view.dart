// lib/screens/reviews_view.dart
import 'package:flutter/material.dart';

// --- MOCK DATA ---
class Review {
  final String name;
  final String role;
  final double rating;
  final String text;
  final String date;
  final String avatar;

  Review({
    required this.name,
    required this.role,
    required this.rating,
    required this.text,
    required this.date,
    required this.avatar,
  });
}

final List<Review> _mockReviews = [
  Review(
    name: 'Mary Wanjiku',
    role: 'Tenant',
    rating: 4.0,
    text: 'Great landlord, The place is\ngreat and clean.',
    date: 'May 14, 2026',
    avatar: 'https://i.pravatar.cc/150?img=31',
  ),
  Review(
    name: 'James Odhiambo',
    role: 'Tenant',
    rating: 4.5,
    text: 'Great landlord, The place is\ngreat and clean.',
    date: 'May 14, 2026',
    avatar: 'https://i.pravatar.cc/150?img=33',
  ),
  Review(
    name: 'Aisha Njeri',
    role: 'Tenant',
    rating: 4.8,
    text: 'The apartment was exactly as shown in the pictures. Very safe neighborhood.',
    date: 'April 22, 2026',
    avatar: 'https://i.pravatar.cc/150?img=35',
  ),
];

// ==================== MAIN REVIEWS SCREEN ====================
class ReviewsView extends StatefulWidget {
  const ReviewsView({super.key});

  @override
  State<ReviewsView> createState() => _ReviewsViewState();
}

class _ReviewsViewState extends State<ReviewsView> with TickerProviderStateMixin {
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
        pageBuilder: (context, animation, secondaryAnimation) => const WriteReviewView(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                  .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _navToAllReviews() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) => const AllReviewsView(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                  .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
      ),
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
                      const _OverallRatingSection(),
                      const SizedBox(height: 40),
                      const Divider(color: Color(0xFFF3F4F6), thickness: 1.5, height: 1),
                      const SizedBox(height: 32),
                      ..._mockReviews.map((review) => _ReviewCard(
                            avatar: review.avatar,
                            name: review.name,
                            role: review.role,
                            rating: review.rating,
                            review: review.text,
                            date: review.date,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: GestureDetector(
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
                  Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 20),
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
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withOpacity(0.0), Colors.white],
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
  const AllReviewsView({super.key});

  @override
  State<AllReviewsView> createState() => _AllReviewsViewState();
}

class _AllReviewsViewState extends State<AllReviewsView> {
  // Multiply mock data to show a long list
  final List<Review> _allReviews = [..._mockReviews, ..._mockReviews, ..._mockReviews];

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
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                itemCount: _allReviews.length,
                itemBuilder: (context, index) {
                  final review = _allReviews[index];
                  return _ReviewCard(
                    avatar: review.avatar,
                    name: review.name,
                    role: review.role,
                    rating: review.rating,
                    review: review.text,
                    date: review.date,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== WRITE REVIEW SCREEN ====================
class WriteReviewView extends StatefulWidget {
  const WriteReviewView({super.key});

  @override
  State<WriteReviewView> createState() => _WriteReviewViewState();
}

class _WriteReviewViewState extends State<WriteReviewView>
    with TickerProviderStateMixin {
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
    super.dispose();
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
                    color: Colors.black.withOpacity(0.05),
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
                      Navigator.pop(context); // Close WriteReviewView
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
              _Header(title: 'Write a Review', onBack: () => Navigator.pop(context)),
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
                                onTap: () => setState(() => _rating = index + 1.0),
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
                            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                          ),
                          child: const TextField(
                            maxLines: 8,
                            decoration: InputDecoration(
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
                    text: 'Submit Review',
                    onTap: _showSuccessModal,
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
            child: const Icon(Icons.arrow_back, size: 28, color: Color(0xFF111827)),
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

// Matches the exact stacked vertical layout from the PDF
class _OverallRatingSection extends StatelessWidget {
  const _OverallRatingSection();

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
            const Text(
              '4.8',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                height: 1.1,
                letterSpacing: -2,
              ),
            ),
            const SizedBox(width: 24),
            Row(
              children: List.generate(5, (i) => 
                const Padding(
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
        const Text(
          '(200 reviews)',
          style: TextStyle(
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
                  const Icon(Icons.star_rounded, size: 16, color: Color(0xFFD1D5DB)),
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

class _ReviewCard extends StatelessWidget {
  final String avatar;
  final String name;
  final String role;
  final double rating;
  final String review;
  final String date;

  const _ReviewCard({
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
                  const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 22),
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
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(decelerationRate: ScrollDecelerationRate.fast);
}