enum PropertyStatus { published, draft, review }

enum BookingStatus { upcoming, completed, cancelled }

enum MessageAuthor { landlord, tenant }

class Property {
  final String id;
  final String title;
  final String location;
  final String type;
  final int price;
  final PropertyStatus status;
  final int views;
  final int favorites;
  final double rating;
  final String heroImage;
  final String description;
  final List<String> amenities;
  final List<String> gallery;

  const Property({
    required this.id,
    required this.title,
    required this.location,
    required this.type,
    required this.price,
    required this.status,
    required this.views,
    required this.favorites,
    required this.rating,
    required this.heroImage,
    required this.description,
    required this.amenities,
    required this.gallery,
  });
}

class Booking {
  final String id;
  final String propertyId;
  final String title;
  final DateTime date;
  final String time;
  final BookingStatus status;
  final String tenantName;
  final String image;

  const Booking({
    required this.id,
    required this.propertyId,
    required this.title,
    required this.date,
    required this.time,
    required this.status,
    required this.tenantName,
    required this.image,
  });
}

class Tenant {
  final String id;
  final String name;
  final String apartment;
  final String location;
  final String leaseStatus;
  final String photo;
  final String phone;
  final String email;

  const Tenant({
    required this.id,
    required this.name,
    required this.apartment,
    required this.location,
    required this.leaseStatus,
    required this.photo,
    required this.phone,
    required this.email,
  });
}

class ChatConversation {
  final int id;
  final String name;
  final String avatar;
  final String lastMessage;
  final String time;
  final int unread;
  final List<ChatMessage> messages;

  const ChatConversation({
    required this.id,
    required this.name,
    required this.avatar,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.messages,
  });
}

class ChatMessage {
  final MessageAuthor author;
  final String text;
  final DateTime timestamp;

  const ChatMessage({
    required this.author,
    required this.text,
    required this.timestamp,
  });
}

class RevenuePoint {
  final String label;
  final double value;

  const RevenuePoint({required this.label, required this.value});
}

class NotificationItem {
  final String id;
  final String title;
  final String subtitle;
  final String time;
  final bool unread;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.unread,
  });
}

class UserProfile {
  final String name;
  final String role;
  final String email;
  final String phone;
  final String avatar;
  final String location;
  final String bio;

  const UserProfile({
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
    required this.avatar,
    required this.location,
    required this.bio,
  });
}

class MockRepository {
  const MockRepository();

  UserProfile get landlordProfile => const UserProfile(
        name: 'Jomison',
        role: 'Landlord',
        email: 'jomison@staynest.co.ke',
        phone: '+254 700 123 456',
        avatar: 'assets/images/profile.jpg',
        location: 'Nairobi, Kenya',
        bio: 'Premium landlord portfolio owner with 12 active listings.',
      );

  List<Property> get properties => const [
        Property(
          id: 'prop_001',
          title: '11 Green Bank',
          location: 'Kilifi, Kenya',
          type: 'Apartment',
          price: 12500,
          status: PropertyStatus.published,
          views: 1243,
          favorites: 24,
          rating: 4.8,
          heroImage: 'assets/images/hero.jpg',
          description:
              'Modern Mediterranean-style apartment with polished interiors, smart amenities, and a spacious balcony view.',
          amenities: ['Wifi', 'Parking', 'Security', 'Water'],
          gallery: [
            'assets/images/hero.jpg',
            'assets/images/hero1.jpg',
            'assets/images/apertment1.jpg',
            'assets/images/apertment2.jpg',
          ],
        ),
        Property(
          id: 'prop_002',
          title: '1-bedroom Apartment',
          location: 'Nairobi, Kenya',
          type: 'Apartment',
          price: 12000,
          status: PropertyStatus.published,
          views: 300,
          favorites: 200,
          rating: 4.6,
          heroImage: 'assets/images/hero1.jpg',
          description:
              'Chic one-bedroom apartment with abundant sunlight, premium finishes, and a quiet neighborhood vibe.',
          amenities: ['Wifi', 'Water', 'Electricity'],
          gallery: [
            'assets/images/hero1.jpg',
            'assets/images/hero2.jpg',
            'assets/images/apertment3.jpg',
            'assets/images/rec3.jpg',
          ],
        ),
        Property(
          id: 'prop_003',
          title: 'Open Single Room',
          location: 'Kilifi, Kenya',
          type: 'Single Room',
          price: 9000,
          status: PropertyStatus.draft,
          views: 1243,
          favorites: 24,
          rating: 4.2,
          heroImage: 'assets/images/apertment1.jpg',
          description:
              'Comfortable single-room setup with private bathroom and seamless access to community amenities.',
          amenities: ['Wifi', 'Water', 'Furnished'],
          gallery: [
            'assets/images/apertment1.jpg',
            'assets/images/rec1.jpg',
            'assets/images/rec2.jpg',
          ],
        ),
        Property(
          id: 'prop_004',
          title: 'Smart Villa',
          location: 'Westlands, Nairobi',
          type: 'Villa',
          price: 22000,
          status: PropertyStatus.review,
          views: 987,
          favorites: 72,
          rating: 4.9,
          heroImage: 'assets/images/hero2.jpg',
          description:
              'A luxury villa designed for premium rentals, complete with garden terraces and smart home controls.',
          amenities: ['Wifi', 'Parking', 'Security', 'CCTV', 'Furnished'],
          gallery: [
            'assets/images/hero2.jpg',
            'assets/images/hero3.jpg',
            'assets/images/apertment3.jpg',
          ],
        ),
      ];

  List<Booking> get bookings => [
        Booking(
          id: 'book_001',
          propertyId: 'prop_001',
          title: '11 Green Bank',
          date: DateTime(2026, 5, 24),
          time: '10:00 AM',
          status: BookingStatus.upcoming,
          tenantName: 'James Mora',
          image: 'assets/images/hero.jpg',
        ),
        Booking(
          id: 'book_002',
          propertyId: 'prop_002',
          title: 'Smart Apartment',
          date: DateTime(2026, 5, 27),
          time: '10:00 AM',
          status: BookingStatus.completed,
          tenantName: 'Mary Wanjiru',
          image: 'assets/images/hero1.jpg',
        ),
        Booking(
          id: 'book_003',
          propertyId: 'prop_003',
          title: 'Cozy Bedsitter',
          date: DateTime(2026, 5, 30),
          time: '10:00 AM',
          status: BookingStatus.cancelled,
          tenantName: 'David Odhiambo',
          image: 'assets/images/apertment1.jpg',
        ),
        Booking(
          id: 'book_004',
          propertyId: 'prop_001',
          title: '11 Green Bank',
          date: DateTime(2026, 6, 2),
          time: '01:00 PM',
          status: BookingStatus.upcoming,
          tenantName: 'Aisha Njeri',
          image: 'assets/images/hero.jpg',
        ),
      ];

  List<Tenant> get tenants => const [
        Tenant(
          id: 'tenant_001',
          name: 'John Kamau',
          apartment: '11 Green Bank',
          location: 'Kilifi, Kenya',
          leaseStatus: 'Active Lease',
          photo: 'assets/images/hero3.jpg',
          phone: '+254 701 559 377',
          email: 'john.kamau@example.com',
        ),
        Tenant(
          id: 'tenant_002',
          name: 'Mary Wanjiku',
          apartment: '1-bedroom Apartment',
          location: 'Nairobi, Kenya',
          leaseStatus: 'Renewal Due',
          photo: 'assets/images/hero2.jpg',
          phone: '+254 701 223 445',
          email: 'mary.wanjiku@example.com',
        ),
        Tenant(
          id: 'tenant_003',
          name: 'David Odhiambo',
          apartment: 'Open Single Room',
          location: 'Kilifi, Kenya',
          leaseStatus: 'Notice Period',
          photo: 'assets/images/hero1.jpg',
          phone: '+254 700 987 123',
          email: 'david.odhiambo@example.com',
        ),
      ];

  List<ChatConversation> get conversations => [
        ChatConversation(
          id: 1,
          name: 'John Kamau',
          avatar: 'assets/images/hero3.jpg',
          lastMessage: 'Hi, is the room still available?',
          time: '2m',
          unread: 2,
          messages: [
            ChatMessage(
              author: MessageAuthor.tenant,
              text: 'Hi, is the room still available?',
              timestamp: DateTime(2026, 5, 30, 10, 24),
            ),
            ChatMessage(
              author: MessageAuthor.landlord,
              text:
                  'Yes, it is still available. Would you like to schedule a viewing?',
              timestamp: DateTime(2026, 5, 30, 10, 25),
            ),
          ],
        ),
        ChatConversation(
          id: 2,
          name: 'Mary Wanjiku',
          avatar: 'assets/images/hero2.jpg',
          lastMessage: 'Are you available for visit?',
          time: '1h',
          unread: 0,
          messages: [
            ChatMessage(
              author: MessageAuthor.tenant,
              text: 'Are you available for visit?',
              timestamp: DateTime(2026, 5, 30, 9, 10),
            ),
            ChatMessage(
              author: MessageAuthor.landlord,
              text: 'Yes, tomorrow afternoon works well.',
              timestamp: DateTime(2026, 5, 30, 9, 12),
            ),
          ],
        ),
        ChatConversation(
          id: 3,
          name: 'GreenHomes Ltd.',
          avatar: 'assets/images/logo_green.png',
          lastMessage: 'Your update is ready.',
          time: '9:15 AM',
          unread: 0,
          messages: [
            ChatMessage(
              author: MessageAuthor.tenant,
              text: 'Your update is ready.',
              timestamp: DateTime(2026, 5, 30, 8, 15),
            ),
          ],
        ),
      ];

  List<RevenuePoint> get revenueTrend => const [
        RevenuePoint(label: 'Jan', value: 12.0),
        RevenuePoint(label: 'Feb', value: 18.5),
        RevenuePoint(label: 'Mar', value: 14.0),
        RevenuePoint(label: 'Apr', value: 21.0),
        RevenuePoint(label: 'May', value: 28.0),
        RevenuePoint(label: 'Jun', value: 24.0),
      ];

  List<NotificationItem> get notifications => const [
        NotificationItem(
          id: 'note_001',
          title: 'Booking confirmed',
          subtitle: '11 Green Bank has a new viewing request.',
          time: 'Just now',
          unread: true,
        ),
        NotificationItem(
          id: 'note_002',
          title: 'Property review',
          subtitle: 'Open Single Room is pending approval.',
          time: '1h ago',
          unread: false,
        ),
      ];

  Property? findPropertyById(String id) => properties
      .firstWhere((item) => item.id == id, orElse: () => properties.first);

  ChatConversation? findConversationById(int id) => conversations.firstWhere(
        (item) => item.id == id,
        orElse: () => conversations.first,
      );

  List<Booking> bookingsByStatus(BookingStatus status) =>
      bookings.where((booking) => booking.status == status).toList();
}
