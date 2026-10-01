import 'package:flutter/material.dart';
import 'package:property_app/repository/remote_database_repository.dart';

class WriteReviewView extends StatefulWidget {
  final String propertyId;
  final String propertyName;
  final String bookingId; // Required: Backend requires a completed booking

  const WriteReviewView({
    super.key,
    required this.propertyId,
    required this.propertyName,
    required this.bookingId,
  });

  @override
  State<WriteReviewView> createState() => _WriteReviewViewState();
}

class _WriteReviewViewState extends State<WriteReviewView> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    final trimmedComment = _commentController.text.trim();

    if (trimmedComment.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Feedback must be at least 10 characters long')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = RemoteDatabaseRepository();
      // Using the POST /api/v1/properties/reviews endpoint
      final review = await repo.submitReview(
        propertyId: widget.propertyId,
        rating: _rating,
        comment: trimmedComment,
        bookingId: widget.bookingId,
      );
      if (review == null) {
        throw StateError('We could not submit your review. Please try again.');
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Review ${widget.propertyName}',
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.propertyName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'How was your experience?',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 16),
            ),
            const SizedBox(height: 32),

            // Star Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = index + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.star_rounded,
                      size: 48,
                      color: index < _rating
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 40),

            // Comment Field
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Your Feedback',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              maxLines: 5,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Tell us more about the property and stay...',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                counter: Text(
                  '${_commentController.text.trim().length} / 10 characters min',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _commentController.text.trim().length < 10
                        ? Colors.redAccent
                        : Colors.green,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_rating > 0 &&
                        _commentController.text.trim().length >= 10 &&
                        !_isSubmitting)
                    ? _submit
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3F37C9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Submit Review',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
