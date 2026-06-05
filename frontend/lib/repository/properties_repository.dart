import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:property_app/models/property.dart';

class PropertiesRepository {
  const PropertiesRepository();

  Future<List<Property>> loadAll() async {
    final jsonStr = await rootBundle.loadString(
      'assets/data/properties_by_category.json',
    );
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

    final List<Property> all = [];
    for (final categoryList in decoded.values) {
      if (categoryList is List) {
        all.addAll(categoryList.map((e) => _propertyFromJson(e)));
      }
    }
    return all;
  }

  Future<List<Property>> loadByUiCategory(String uiCategory) async {
    final jsonStr = await rootBundle.loadString(
      'assets/data/properties_by_category.json',
    );
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

    final list = decoded[uiCategory] as List<dynamic>?;
    if (list == null) return [];

    return list.map((e) => _propertyFromJson(e)).toList();
  }

  Property _propertyFromJson(dynamic e) {
    final m = e as Map<String, dynamic>;

    final featuresMap = m['features'] as Map<String, dynamic>;
    final agentMap = m['agent'] as Map<String, dynamic>;

    final images = (m['images'] as List?)?.cast<String>();
    final amenities = (m['amenities'] as List?)?.cast<String>() ?? <String>[];

    return Property(
      id: m['id'].toString(),
      name: m['name'].toString(),
      location: m['location'].toString(),
      lat: (m['lat'] as num).toDouble(),
      lng: (m['lng'] as num).toDouble(),
      price: (m['price'] as num).toInt(),
      rating: (m['rating'] as num).toDouble(),
      reviews: (m['reviews'] as num).toInt(),
      category: m['category'].toString(),
      image: m['image'].toString(),
      images: images,
      features: PropertyFeatures(
        beds: (featuresMap['beds'] as num).toInt(),
        rooms: (featuresMap['rooms'] as num).toInt(),
        baths: (featuresMap['baths'] as num).toInt(),
        furnished: featuresMap['furnished'] as bool,
      ),
      amenities: amenities,
      description: m['description'].toString(),
      agent: Agent(
        userId: agentMap['user_id']?.toString() ?? agentMap['id']?.toString() ?? '',
        name: agentMap['name'].toString(),
        avatar: agentMap['avatar'].toString(),
      ),
    );
  }
}
