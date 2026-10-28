import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:property_app/utils/property_mapper.dart';
import 'package:property_app/utils/property_links.dart';

void main() {
  test(
      'Property.fromJson normalizes api payload where name and image are provided',
      () {
    final property = mapApiProperty({
      'id': 'prop_123',
      'name': 'Harbor View Apartment',
      'image': 'https://cdn.example.com/property/cover.jpg',
      'category': 'Apartment',
      'city': 'Nairobi',
      'price': 2500,
      'lat': '-1.2921',
      'lng': '36.8219',
      'bedrooms': '2',
      'bathrooms': '2',
      'area': '120',
      'description': 'Nice place',
      'landlord_id': 'user_42',
      'landlord_name': 'Jane Doe',
      'landlord_avatar': 'https://cdn.example.com/avatar.jpg',
      'landlord_verified': true,
      'landlord_property_count': 3,
      'landlord_response_time_seconds': '7200',
      'average_rating': 4.7,
      'review_count': 42,
    });

    expect(property.name, 'Harbor View Apartment');
    expect(property.image, 'https://cdn.example.com/property/cover.jpg');
    expect(property.location, 'Nairobi');
    expect(property.category, 'Apartment');
    expect(property.features.rooms, 2);
    expect(property.features.beds, 0);
    expect(property.features.baths, 2);
    expect(property.agent.name, 'Jane Doe');
    expect(property.agent.propertyCount, 3);
    expect(property.agent.responseTimeSeconds, 7200);
  });

  test('missing property details are not filled with display defaults', () {
    final property = mapApiProperty({});

    expect(property.category, isEmpty);
    expect(property.features.rooms, 0);
    expect(property.features.beds, 0);
    expect(property.features.baths, 0);
  });

  test('moderation and availability remain separate in mapped properties', () {
    final property = mapApiProperty({
      'id': 'approved-with-unknown-availability',
      'status': 'approved',
      'availability_status': 'unknown',
      'published_at': '2026-10-18T12:00:00.000Z',
    });

    expect(property.moderationStatus, 'approved');
    expect(property.availabilityStatus, 'unknown');
    expect(property.isAvailableForBooking, isFalse);
    expect(property.publishedAt, DateTime.utc(2026, 10, 18, 12));
  });

  test('property share URL uses the configured frontend origin', () {
    dotenv.testLoad(fileInput: 'FRONTEND_URL=https://app.example.test');

    expect(
      PropertyLinks.forProperty('property-123'),
      'https://app.example.test/properties/property-123',
    );
  });
}
