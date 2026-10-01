class PropertyModel {
  final String id;
  final String category;
  final String name;
  final String location;
  final String image;
  final List<String> images;
  final String? videoUrl;
  final double rating;
  final int reviews;
  final String price;
  final double? lat;
  final double? lng;

  PropertyModel({
    required this.id,
    required this.category,
    required this.name,
    required this.location,
    required this.image,
    required this.images,
    this.videoUrl,
    required this.rating,
    required this.reviews,
    required this.price,
    this.lat,
    this.lng,
  });

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    final imagesList = json['images'] is List
        ? List<String>.from(json['images'] as List)
        : <String>[];
    final primaryImage = imagesList.isNotEmpty
        ? imagesList.first
        : ((json['image'] ?? json['image_url'] ?? json['property_image']) ?? '')
            .toString();

    return PropertyModel(
      id: (json['id'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? json['property_name'] ?? '')
          .toString(),
      location:
          (json['city'] ?? json['location'] ?? json['property_city'] ?? '')
              .toString(),
      image: primaryImage,
      images: imagesList,
      videoUrl: json['video_url']?.toString(),
      rating: (json['rating'] is num)
          ? (json['rating'] as num).toDouble()
          : double.tryParse((json['rating'] ?? '0').toString()) ?? 0.0,
      reviews: (json['reviews'] is int)
          ? json['reviews'] as int
          : int.tryParse((json['reviews'] ?? '0').toString()) ?? 0,
      price: (json['price'] ?? '').toString(),
      lat: json['lat'] != null ? (json['lat'] as num).toDouble() : null,
      lng: json['lng'] != null ? (json['lng'] as num).toDouble() : null,
    );
  }
}

class Agent {
  final String userId;
  final String name;
  final String avatar;
  final bool verified;
  final String? email;
  final String? businessName;
  final String? businessDescription;
  final String? memberSince;
  final int propertyCount;
  final double? responseTimeSeconds;

  const Agent({
    required this.userId,
    required this.name,
    required this.avatar,
    this.verified = false,
    this.email,
    this.businessName,
    this.businessDescription,
    this.memberSince,
    this.propertyCount = 0,
    this.responseTimeSeconds,
  });
}

class PropertyFeatures {
  final int beds;
  final int rooms;
  final int baths;
  final bool furnished;
  final int area;

  const PropertyFeatures({
    required this.beds,
    required this.rooms,
    required this.baths,
    required this.furnished,
    this.area = 0,
  });
}

class Property {
  final String id;
  final String name;
  final String location;
  final double lat;
  final double lng;
  final int price;
  final double rating;
  final int reviews;
  final String category;
  final String image;
  final List<String> images;
  final String? videoUrl;
  final PropertyFeatures features;
  final List<String> amenities;
  final List<String> customFeatures;
  final String description;
  final Agent agent;
  final DateTime? viewedAt;
  final String availabilityStatus;

  const Property({
    required this.id,
    required this.name,
    required this.location,
    required this.lat,
    required this.lng,
    required this.price,
    required this.rating,
    required this.reviews,
    required this.category,
    required this.image,
    List<String>? images,
    this.videoUrl,
    required this.features,
    this.amenities = const [],
    this.customFeatures = const [],
    required this.description,
    required this.agent,
    this.viewedAt,
    this.availabilityStatus = 'available',
  }) : images = images ?? const [];

  bool get isAvailableForBooking => !const {
        'fully_booked',
        'unavailable',
        'rented',
        'maintenance'
      }.contains(availabilityStatus.toLowerCase());

  String get availabilityLabel => switch (availabilityStatus.toLowerCase()) {
        'fully_booked' => 'Fully booked',
        'unavailable' => 'Temporarily unavailable',
        'rented' => 'Rented out',
        'maintenance' => 'Under maintenance',
        'pending_booking' => 'Booking pending',
        _ => 'Available',
      };

  factory Property.fromJson(Map<String, dynamic> json) {
    double numberValue(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    int integerValue(dynamic value) => numberValue(value).toInt();

    final imagesList = json['images'] is List
        ? (json['images'] as List)
            .map((image) => image.toString())
            .where((image) => image.isNotEmpty)
            .toList()
        : <String>[];
    final primaryImage = imagesList.isNotEmpty
        ? imagesList.first
        : ((json['image'] ?? json['image_url'] ?? json['property_image']) ?? '')
            .toString();

    final amenitiesList = json['amenities'] is List
        ? List<String>.from(json['amenities'] as List)
        : <String>[];
    final legacyStatus = (json['status'] ?? '').toString().toLowerCase();
    final rawAvailabilityStatus =
        json['availability_status']?.toString().toLowerCase();
    const occupancyStatuses = {
      'available',
      'pending_booking',
      'fully_booked',
      'unavailable',
      'rented',
      'maintenance',
    };
    final availabilityStatus = rawAvailabilityStatus == null ||
            rawAvailabilityStatus.isEmpty ||
            rawAvailabilityStatus == 'unknown'
        ? (occupancyStatuses.contains(legacyStatus)
            ? legacyStatus
            : 'available')
        : rawAvailabilityStatus;

    return Property(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? json['property_name'] ?? '')
          .toString(),
      location:
          (json['city'] ?? json['location'] ?? json['property_city'] ?? '')
              .toString(),
      lat: numberValue(json['lat']),
      lng: numberValue(json['lng']),
      price: integerValue(json['price']),
      rating: numberValue(json['rating']),
      reviews: integerValue(json['reviews']),
      category: (json['category'] ?? '').toString(),
      image: primaryImage,
      images: imagesList,
      videoUrl: json['video_url']?.toString(),
      features: PropertyFeatures(
        beds: integerValue(json['bedrooms']),
        rooms: integerValue(json['bedrooms']),
        baths: integerValue(json['bathrooms']),
        furnished: json['amenities'] is List
            ? (json['amenities'] as List).contains('Furnished')
            : false,
        area: integerValue(json['area']),
      ),
      amenities: amenitiesList,
      description: (json['description'] ?? '').toString(),
      availabilityStatus: availabilityStatus,
      agent: Agent(
        userId: (json['landlord_id'] ?? '').toString(),
        name: (json['landlord_name'] ?? 'Unknown').toString(),
        avatar: (json['landlord_avatar'] ?? '').toString(),
        verified: json['landlord_verified'] == true,
        email: json['landlord_email']?.toString(),
        businessName: json['landlord_business_name']?.toString(),
        businessDescription: json['landlord_business_description']?.toString(),
        memberSince: json['landlord_member_since']?.toString(),
      ),
    );
  }
}
