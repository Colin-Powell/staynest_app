import 'package:property_app/models/property.dart';
import 'package:property_app/utils/property_mapper.dart';

class FeedContext {
  final String source;
  final String campusId;
  final double radiusKm;

  FeedContext({
    required this.source,
    required this.campusId,
    required this.radiusKm,
  });

  factory FeedContext.fromJson(Map<String, dynamic> json) {
    return FeedContext(
      source: json['source'] ?? 'none',
      campusId: json['campusId'] ?? '',
      radiusKm: (json['radiusKm'] ?? 5).toDouble(),
    );
  }
}

class FeedSection {
  final String id;
  final String type; // property_carousel, property_grid, property_list
  final String title;
  final String subtitle;
  final String algorithm;
  final List<Property> items;
  final String? nextCursor;
  final bool hasMore;

  FeedSection({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.algorithm,
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });

  factory FeedSection.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List? ?? [];
    List<Property> properties = itemsList.map((item) {
      return mapApiProperty(Map<String, dynamic>.from(item));
    }).toList();

    return FeedSection(
      id: json['id'] ?? '',
      type: json['type'] ?? 'property_carousel',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      algorithm: json['algorithm'] ?? '',
      items: properties,
      nextCursor: json['nextCursor'],
      hasMore: json['hasMore'] ?? false,
    );
  }
}

class HomeFeedResponse {
  final int schemaVersion;
  final String generatedAt;
  final FeedContext context;
  final List<FeedSection> sections;
  final String? nextCursor;

  HomeFeedResponse({
    required this.schemaVersion,
    required this.generatedAt,
    required this.context,
    required this.sections,
    this.nextCursor,
  });

  factory HomeFeedResponse.fromJson(Map<String, dynamic> json) {
    var data = json['data'] ?? json;
    
    var sectionsList = data['sections'] as List? ?? [];
    List<FeedSection> sections = sectionsList.map((section) {
      return FeedSection.fromJson(Map<String, dynamic>.from(section));
    }).toList();

    return HomeFeedResponse(
      schemaVersion: data['schemaVersion'] ?? 1,
      generatedAt: data['generatedAt'] ?? '',
      context: FeedContext.fromJson(Map<String, dynamic>.from(data['context'] ?? {})),
      sections: sections,
      nextCursor: data['nextCursor'],
    );
  }
}
