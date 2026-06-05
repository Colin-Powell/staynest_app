class PropertyModel {
  final String id;
  final String category;
  final String name;
  final String location;
  final String image;
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
    required this.rating,
    required this.reviews,
    required this.price,
    this.lat,
    this.lng,
  });

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    return PropertyModel(
      id: (json['id'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
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

  const Agent({required this.userId, required this.name, required this.avatar});
}

class PropertyFeatures {
  final int beds;
  final int rooms;
  final int baths;
  final bool furnished;

  const PropertyFeatures({
    required this.beds,
    required this.rooms,
    required this.baths,
    required this.furnished,
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
  final List<String>? images;
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
    this.images,
    required this.features,
    required this.amenities,
    required this.description,
    required this.agent,
  });
}
