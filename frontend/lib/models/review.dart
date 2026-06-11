import 'user.dart';

class Review {
  final String id;
  final String bookingId;
  final String propertyId;
  final String reviewerId;
  final User? reviewer; // Optional: to embed reviewer details
  final int rating;
  final String? comment;
  final String? landlordResponse;
  final DateTime createdAt;
  final DateTime updatedAt;

  Review({
    required this.id,
    required this.bookingId,
    required this.propertyId,
    required this.reviewerId,
    this.reviewer,
    required this.rating,
    this.comment,
    this.landlordResponse,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      propertyId: json['property_id'] as String,
      reviewerId: json['reviewer_id'] as String,
      reviewer:
          json['reviewer'] != null ? User.fromJson(json['reviewer']) : null,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      landlordResponse: json['landlord_response'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
