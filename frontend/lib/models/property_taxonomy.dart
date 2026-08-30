class PropertyAttribute {
  final String id;
  final String label;
  final String category;
  final String iconKey;
  final List<String> propertyTypes;
  final bool isPopular;
  final bool isFilterable;
  final bool isSearchable;
  final bool isTenantVisible;

  const PropertyAttribute({
    required this.id,
    required this.label,
    required this.category,
    required this.iconKey,
    this.propertyTypes = const [],
    this.isPopular = false,
    this.isFilterable = true,
    this.isSearchable = true,
    this.isTenantVisible = true,
  });
}

class PropertyCategory {
  final String id;
  final String label;

  const PropertyCategory(this.id, this.label);
}

class PropertyTaxonomy {
  static const List<PropertyCategory> categories = [
    PropertyCategory('room_features', 'Room Features'),
    PropertyCategory('utilities', 'Utilities'),
    PropertyCategory('security', 'Security'),
    PropertyCategory('location_context', 'Location & Surroundings'),
    PropertyCategory('student_features', 'Student-oriented Features'),
    PropertyCategory('generic', 'Other Amenities'),
  ];

  static const List<PropertyAttribute> attributes = [
    // Room Features
    PropertyAttribute(id: 'tiles', label: 'Tiles', category: 'room_features', iconKey: 'squares_four', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room'], isPopular: true),
    PropertyAttribute(id: 'ceiling', label: 'Ceiling', category: 'room_features', iconKey: 'columns', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room'], isPopular: true),
    PropertyAttribute(id: 'spacious', label: 'Spacious', category: 'room_features', iconKey: 'arrows_out', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom'], isPopular: false),
    PropertyAttribute(id: 'well_lit', label: 'Well Lit', category: 'room_features', iconKey: 'sun', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom']),
    PropertyAttribute(id: 'large_windows', label: 'Large Windows', category: 'room_features', iconKey: 'app_window', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom']),
    PropertyAttribute(id: 'wardrobe', label: 'Wardrobe', category: 'room_features', iconKey: 'archive_box', propertyTypes: ['bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'self_contained', label: 'Self-Contained', category: 'room_features', iconKey: 'door', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom']),
    PropertyAttribute(id: 'furnished', label: 'Furnished', category: 'room_features', iconKey: 'armchair', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'semi_furnished', label: 'Semi-Furnished', category: 'room_features', iconKey: 'couch', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'newly_built', label: 'Newly Built', category: 'room_features', iconKey: 'buildings', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom']),
    PropertyAttribute(id: 'renovated', label: 'Renovated', category: 'room_features', iconKey: 'paint_roller', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom']),

    // Utilities
    PropertyAttribute(id: 'water_available', label: 'Water Available', category: 'utilities', iconKey: 'drop', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room'], isPopular: true),
    PropertyAttribute(id: 'reliable_water', label: 'Reliable Water', category: 'utilities', iconKey: 'drop_half_bottom', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'water_24_7', label: 'Water 24/7', category: 'utilities', iconKey: 'clock', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'own_token', label: 'Own Token', category: 'utilities', iconKey: 'lightning', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom'], isPopular: true),
    PropertyAttribute(id: 'shared_token', label: 'Shared Token', category: 'utilities', iconKey: 'plugs', propertyTypes: ['single_room', 'bedsitter', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'electricity_available', label: 'Electricity Available', category: 'utilities', iconKey: 'lightbulb', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'wifi', label: 'Wi-Fi', category: 'utilities', iconKey: 'wifi_high', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room'], isPopular: true),
    PropertyAttribute(id: 'fibre_available', label: 'Fibre Available', category: 'utilities', iconKey: 'broadcast', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'backup_power', label: 'Backup Power', category: 'utilities', iconKey: 'battery_charging', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom']),
    PropertyAttribute(id: 'solar_power', label: 'Solar Power', category: 'utilities', iconKey: 'sun_dim', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom']),

    // Security
    PropertyAttribute(id: 'secure_compound', label: 'Secure Compound', category: 'security', iconKey: 'shield_check', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room'], isPopular: true),
    PropertyAttribute(id: 'gated_compound', label: 'Gated Compound', category: 'security', iconKey: 'lock_key', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'perimeter_wall', label: 'Perimeter Wall', category: 'security', iconKey: 'wall', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'security_guard', label: 'Security Guard', category: 'security', iconKey: 'user_circle_gear', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'night_security', label: 'Night Security', category: 'security', iconKey: 'moon', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'cctv', label: 'CCTV', category: 'security', iconKey: 'camera', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'security_lighting', label: 'Security Lighting', category: 'security', iconKey: 'lightbulb_filament', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),

    // Location & Surroundings
    PropertyAttribute(id: 'near_campus', label: 'Near Campus', category: 'location_context', iconKey: 'student', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room'], isPopular: true),
    PropertyAttribute(id: 'walking_distance', label: 'Walking Distance', category: 'location_context', iconKey: 'sneaker', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room'], isPopular: true),
    PropertyAttribute(id: 'near_stage', label: 'Near Stage', category: 'location_context', iconKey: 'bus', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'near_shops', label: 'Near Shops', category: 'location_context', iconKey: 'shopping_cart', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'near_market', label: 'Near Market', category: 'location_context', iconKey: 'storefront', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'near_main_road', label: 'Near Main Road', category: 'location_context', iconKey: 'road_horizon', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'quiet_area', label: 'Quiet Area', category: 'location_context', iconKey: 'speaker_none', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'accessible_road', label: 'Accessible Road', category: 'location_context', iconKey: 'car_profile', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),

    // Student-oriented features
    PropertyAttribute(id: 'student_friendly', label: 'Student Friendly', category: 'student_features', iconKey: 'backpack', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'cooking_allowed', label: 'Cooking Allowed', category: 'student_features', iconKey: 'cooking_pot', propertyTypes: ['single_room', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'visitors_allowed', label: 'Visitors Allowed', category: 'student_features', iconKey: 'users', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'laundry_area', label: 'Laundry Area', category: 'student_features', iconKey: 't_shirt', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom']),
    PropertyAttribute(id: 'parking', label: 'Parking', category: 'student_features', iconKey: 'car', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'study_friendly', label: 'Study Friendly', category: 'student_features', iconKey: 'book_open', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    
    // Generic
    PropertyAttribute(id: 'generator', label: 'Backup Generator', category: 'generic', iconKey: 'engine', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom']),
    PropertyAttribute(id: 'elevator', label: 'Elevator', category: 'generic', iconKey: 'elevator', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom']),
    PropertyAttribute(id: 'wheelchair_accessible', label: 'Wheelchair Accessible', category: 'generic', iconKey: 'wheelchair', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom', 'shared_room', 'hostel_room']),
    PropertyAttribute(id: 'pet_friendly', label: 'Pet Friendly', category: 'generic', iconKey: 'paw_print', propertyTypes: ['single_room', 'bedsitter', 'studio', 'one_bedroom', 'two_bedroom']),
    PropertyAttribute(id: 'balcony', label: 'Balcony', category: 'generic', iconKey: 'house_line', propertyTypes: ['bedsitter', 'studio', 'one_bedroom', 'two_bedroom']),
    PropertyAttribute(id: 'garden', label: 'Garden', category: 'generic', iconKey: 'tree', propertyTypes: ['one_bedroom', 'two_bedroom']),
    PropertyAttribute(id: 'gym', label: 'Gym', category: 'generic', iconKey: 'barbell', propertyTypes: ['one_bedroom', 'two_bedroom', 'studio']),
    PropertyAttribute(id: 'pool', label: 'Swimming Pool', category: 'generic', iconKey: 'swimming_pool', propertyTypes: ['one_bedroom', 'two_bedroom', 'studio']),
  ];

  static Map<String, PropertyAttribute> get _attributeMap {
    return {for (var attr in attributes) attr.id: attr};
  }
  
  static final Map<String, String> _legacyMappings = {
    'wifi': 'wifi',
    'water included': 'water_available',
    'electricity included': 'electricity_available',
    'heating': 'well_lit', // rough fallback
    'air conditioning': 'well_lit', // rough fallback
    'hot water': 'water_available',
    'parking': 'parking',
    'security': 'secure_compound',
    'cctv': 'cctv',
    'furnished': 'furnished',
    'gym': 'gym',
    'swimming pool': 'pool',
    'elevator': 'elevator',
    'wheelchair accessible': 'wheelchair_accessible',
    'pet friendly': 'pet_friendly',
    'balcony / patio': 'balcony',
    'balcony': 'balcony',
    'garden': 'garden',
    'backup generator': 'generator',
    'laundry / washer': 'laundry_area',
    'laundry': 'laundry_area',
    'dishwasher': 'cooking_allowed', // rough fallback
  };

  static String mapLegacyLabel(String legacyLabel) {
    final lower = legacyLabel.toLowerCase();
    return _legacyMappings[lower] ?? lower.replaceAll(' ', '_');
  }

  static PropertyAttribute? getAttributeById(String id) {
    return _attributeMap[id] ?? _attributeMap[mapLegacyLabel(id)];
  }

  static List<PropertyAttribute> getAttributesForPropertyType(String propertyType) {
    final mappedType = _mapApiCategory(propertyType);
    return attributes.where((attr) => attr.propertyTypes.isEmpty || attr.propertyTypes.contains(mappedType)).toList();
  }

  static List<PropertyAttribute> getAttributesByCategory(String category, {String? propertyType}) {
    List<PropertyAttribute> attrs = attributes.where((attr) => attr.category == category).toList();
    if (propertyType != null) {
      final mappedType = _mapApiCategory(propertyType);
      attrs = attrs.where((attr) => attr.propertyTypes.isEmpty || attr.propertyTypes.contains(mappedType)).toList();
    }
    return attrs;
  }

  static List<PropertyAttribute> getPopularAttributes({String? propertyType}) {
    List<PropertyAttribute> attrs = attributes.where((attr) => attr.isPopular).toList();
    if (propertyType != null) {
      final mappedType = _mapApiCategory(propertyType);
      attrs = attrs.where((attr) => attr.propertyTypes.isEmpty || attr.propertyTypes.contains(mappedType)).toList();
    }
    return attrs;
  }

  static String _mapApiCategory(String category) {
    final lower = category.toLowerCase().replaceAll(' ', '_');
    if (lower.contains('single')) return 'single_room';
    if (lower.contains('bed_sitter') || lower.contains('bedsitter')) return 'bedsitter';
    if (lower.contains('studio')) return 'studio';
    if (lower.contains('one') || lower.contains('1')) return 'one_bedroom';
    if (lower.contains('two') || lower.contains('2')) return 'two_bedroom';
    if (lower.contains('shared')) return 'shared_room';
    if (lower.contains('hostel')) return 'hostel_room';
    return lower;
  }
}
