class PropertyModel {
  final String id;
  final String category;
  final String name;
  final String location;
  final String image;
  final List<String> images;
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
        : (json['image_url'] ?? '').toString();

    return PropertyModel(
      id: (json['id'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      name: (json['title'] ?? json['name'] ?? '').toString(),
      location: (json['city'] ?? json['location'] ?? '').toString(),
      image: primaryImage,
      images: imagesList,
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
  final PropertyFeatures features;
  final List<String> amenities;
  final String description;
  final Agent agent;

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
    required this.features,
    required this.amenities,
    required this.description,
    required this.agent,
  }) : images = images ?? const [];

  factory Property.fromJson(Map<String, dynamic> json) {
    final imagesList = json['images'] is List
        ? List<String>.from(json['images'] as List)
        : <String>[];
    final primaryImage = imagesList.isNotEmpty
        ? imagesList.first
        : (json['image_url'] ?? '').toString();

    final amenitiesList = json['amenities'] is List
        ? List<String>.from(json['amenities'] as List)
        : <String>[];

    return Property(
      id: (json['id'] ?? '').toString(),
      name: (json['title'] ?? json['name'] ?? '').toString(),
      location: (json['city'] ?? json['location'] ?? '').toString(),
      lat: json['lat'] != null ? (json['lat'] as num).toDouble() : 0.0,
      lng: json['lng'] != null ? (json['lng'] as num).toDouble() : 0.0,
      price: json['price'] != null
          ? (json['price'] is num
              ? (json['price'] as num).toInt()
              : int.tryParse(json['price'].toString()) ?? 0)
          : 0,
      rating: (json['rating'] is num)
          ? (json['rating'] as num).toDouble()
          : double.tryParse((json['rating'] ?? '0').toString()) ?? 0.0,
      reviews: (json['reviews'] is int)
          ? json['reviews'] as int
          : int.tryParse((json['reviews'] ?? '0').toString()) ?? 0,
      category: (json['category'] ?? '').toString(),
      image: primaryImage,
      images: imagesList,
      features: PropertyFeatures(
        beds: json['bedrooms'] != null
            ? (json['bedrooms'] as num).toInt()
            : 0,
        rooms: json['bedrooms'] != null
            ? (json['bedrooms'] as num).toInt()
            : 0,
        baths: json['bathrooms'] != null
            ? (json['bathrooms'] as num).toInt()
            : 0,
        furnished: json['amenities'] is List
            ? (json['amenities'] as List).contains('Furnished')
            : false,
        area: json['area'] != null
            ? (json['area'] as num).toInt()
            : 0,
      ),
      amenities: amenitiesList,
      description: (json['description'] ?? '').toString(),
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