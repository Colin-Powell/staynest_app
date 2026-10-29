import 'package:flutter_test/flutter_test.dart';
import 'package:property_app/utils/promotion_notification.dart';

void main() {
  test('promotion payload maps its validated property ID to the app route', () {
    expect(
      promotionPropertyRoute({
        'type': 'property_promotion',
        'propertyId': '123e4567-e89b-42d3-a456-426614174000',
      }),
      '/properties/123e4567-e89b-42d3-a456-426614174000',
    );
  });

  test('malformed promotion property IDs are rejected', () {
    expect(
      promotionPropertyRoute({
        'type': 'property_promotion',
        'propertyId': '../admin',
      }),
      isNull,
    );
    expect(
      promotionPropertyRoute({'type': 'property_promotion'}),
      isNull,
    );
  });

  test('non-promotion notifications do not produce property routes', () {
    expect(
      promotionPropertyRoute({
        'type': 'new_message',
        'propertyId': '123e4567-e89b-42d3-a456-426614174000',
      }),
      isNull,
    );
  });

  test('promotion images require HTTPS on the approved Cloudinary host', () {
    expect(
      isSafePromotionImageUrl(
        'https://res.cloudinary.com/staynest/image/upload/listing.jpg',
      ),
      isTrue,
    );
    expect(
      isSafePromotionImageUrl(
        'http://res.cloudinary.com/staynest/image/upload/listing.jpg',
      ),
      isFalse,
    );
    expect(
      isSafePromotionImageUrl('https://example.test/listing.jpg'),
      isFalse,
    );
  });
}
