import 'package:flutter_test/flutter_test.dart';
import 'package:property_app/models/property.dart';

void main() {
  test(
      'Property.fromJson normalizes api payload where name and image are provided',
      () {
    final property = Property.fromJson({
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
      'average_rating': 4.7,
      'review_count': 42,
    });

    expect(property.name, 'Harbor View Apartment');
    expect(property.image, 'https://cdn.example.com/property/cover.jpg');
    expect(property.location, 'Nairobi');
    expect(property.agent.name, 'Jane Doe');
  });
}
