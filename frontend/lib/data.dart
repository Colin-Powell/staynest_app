import 'models/property.dart';

const List<Property> properties = [
  // NOTE: Use local assets so images load instantly across all screens.
  Property(
    id: '1',
    name: '11 Green Bank',
    location: 'Kilifi, Kenya',
    lat: 3.6410,
    lng: 39.8560,
    price: 14500,
    rating: 4.8,
    reviews: 120,
    category: 'Apartment',
    image: 'assets/images/hero.jpg',
    images: [
      'assets/images/hero.jpg',
      'assets/images/apertment1.jpg',
      'assets/images/apertment2.jpg',
      'assets/images/apertment3.jpg',
    ],
    features: PropertyFeatures(beds: 2, rooms: 4, baths: 2, furnished: true),
    amenities: ['wifi', 'water', 'parking', 'security'],
    description:
        'Modern luxury home with great access to amenities and transport. Clean finishes and a comfortable layout.',
    agent: Agent(
      userId: '550e8400-e29b-41d4-a716-446655440001',
      name: 'John Kamau',
      avatar: 'https://i.pravatar.cc/150?img=11',
    ),
  ),
  Property(
    id: '2',
    name: 'Azure Heights',
    location: 'Mombasa, Kenya',
    lat: -4.0435,
    lng: 39.6682,
    price: 12000,
    rating: 4.6,
    reviews: 85,
    category: 'Apartment',
    image: 'assets/images/hero1.jpg',
    images: [
      'assets/images/hero1.jpg',
      'assets/images/apertment2.jpg',
      'assets/images/apertment3.jpg',
      'assets/images/hero2.jpg',
    ],
    features: PropertyFeatures(beds: 3, rooms: 3, baths: 2, furnished: true),
    amenities: ['wifi', 'water', 'security'],
    description:
        'Stylish apartment with spacious rooms and a calm neighborhood vibe. Perfect for long stays.',
    agent: Agent(
      userId: '550e8400-e29b-41d4-a716-446655440002',
      name: 'Mary Wanjiku',
      avatar: 'https://i.pravatar.cc/150?img=32',
    ),
  ),
  Property(
    id: '3',
    name: 'Modern Studio',
    location: 'Nairobi, Kenya',
    lat: -1.2864,
    lng: 36.8172,
    price: 8000,
    rating: 4.5,
    reviews: 64,
    category: 'Studio',
    image: 'assets/images/hero3.jpg',
    images: [
      'assets/images/hero3.jpg',
      'assets/images/apertment1.jpg',
      'assets/images/apertment3.jpg',
      'assets/images/hero.jpg',
    ],
    features: PropertyFeatures(beds: 1, rooms: 1, baths: 1, furnished: false),
    amenities: ['wifi', 'water'],
    description:
        'A compact studio with everything you need—bright spaces, modern touches, and a clean environment.',
    agent: Agent(
      userId: '550e8400-e29b-41d4-a716-446655440003',
      name: 'David Ochieng',
      avatar: 'https://i.pravatar.cc/150?img=68',
    ),
  ),
  // Extra local-image properties so listings/screens have more cards.
  Property(
    id: '4',
    name: 'Minimal Space',
    location: 'Nakuru, Kenya',
    lat: -0.3031,
    lng: 36.0800,
    price: 5000,
    rating: 4.2,
    reviews: 45,
    category: 'Studio',
    image: 'assets/images/apertment1.jpg',
    images: [
      'assets/images/apertment1.jpg',
      'assets/images/apertment2.jpg',
      'assets/images/apertment3.jpg',
      'assets/images/rec1.jpg',
    ],
    features: PropertyFeatures(beds: 1, rooms: 1, baths: 1, furnished: true),
    amenities: ['wifi', 'water'],
    description:
        'A simple and affordable space designed for comfort and convenience.',
    agent: Agent(
      userId: '550e8400-e29b-41d4-a716-446655440004',
      name: 'Leah Odhiambo',
      avatar: 'https://i.pravatar.cc/150?img=44',
    ),
  ),
  Property(
    id: '5',
    name: 'Cozy Studio',
    location: 'Nairobi, Kenya',
    lat: -1.2921,
    lng: 36.8219,
    price: 8000,
    rating: 4.5,
    reviews: 90,
    category: 'Studio',
    image: 'assets/images/apertment2.jpg',
    images: [
      'assets/images/apertment2.jpg',
      'assets/images/apertment3.jpg',
      'assets/images/hero2.jpg',
      'assets/images/rec2.jpg',
    ],
    features: PropertyFeatures(beds: 1, rooms: 1, baths: 1, furnished: false),
    amenities: ['wifi', 'water', 'security'],
    description:
        'Cozy interiors with a clean layout—ideal for individuals and couples.',
    agent: Agent(
      userId: '550e8400-e29b-41d4-a716-446655440005',
      name: 'Brian Otieno',
      avatar: 'https://i.pravatar.cc/150?img=28',
    ),
  ),
  Property(
    id: '6',
    name: 'Luxury Bedsitter',
    location: 'Westlands, Nairobi',
    lat: -1.2669,
    lng: 36.8010,
    price: 15000,
    rating: 4.9,
    reviews: 201,
    category: 'Apartment',
    image: 'assets/images/apertment3.jpg',
    images: [
      'assets/images/apertment3.jpg',
      'assets/images/hero1.jpg',
      'assets/images/hero3.jpg',
      'assets/images/rec3.jpg',
    ],
    features: PropertyFeatures(beds: 2, rooms: 2, baths: 1, furnished: true),
    amenities: ['wifi', 'water', 'security', 'parking'],
    description:
        'Premium bedsitter with modern finishes and excellent security.',
    agent: Agent(
      userId: '550e8400-e29b-41d4-a716-446655440006',
      name: 'Aisha Njeri',
      avatar: 'https://i.pravatar.cc/150?img=20',
    ),
  ),
];

String formatPrice(int price) {
  if (price >= 1000) {
    final thousands = price / 1000;
    return '\$${thousands.toStringAsFixed(thousands % 1 != 0 ? 1 : 0)}k';
  }
  return '\$$price';
}
