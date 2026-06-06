/// UI filter chips shown on the home screen.
const homeCategoryFilters = ['Apertments', 'Bedsitter', 'Single Room'];

/// Listing-flow / backend category values landlords can pick.
const listingCategories = [
  'Apartment',
  'Bedsitter',
  'Single Room',
  'Studio',
  'Room',
  'Home',
];

String normalizeCategoryKey(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// Maps a stored backend category to one of the home UI filter labels.
String? uiFilterForCategory(String category) {
  final key = normalizeCategoryKey(category);
  if (key.isEmpty) return null;

  const apartmentKeys = {
    'apartment',
    'apartments',
    'apertments',
    'apertment',
    'home',
    'house',
    'penthouse',
  };
  const bedsitterKeys = {
    'bedsitter',
    'studio',
    'bedsit',
  };
  const singleRoomKeys = {
    'singleroom',
    'room',
    'single',
  };

  if (apartmentKeys.contains(key)) return 'Apertments';
  if (bedsitterKeys.contains(key)) return 'Bedsitter';
  if (singleRoomKeys.contains(key)) return 'Single Room';
  return null;
}

/// Whether [propertyCategory] should appear under the selected [uiFilter] chip.
bool categoryMatchesUiFilter(String propertyCategory, String uiFilter) {
  final mapped = uiFilterForCategory(propertyCategory);
  if (mapped != null) return mapped == uiFilter;

  final propKey = normalizeCategoryKey(propertyCategory);
  final filterKey = normalizeCategoryKey(uiFilter);
  return propKey == filterKey || propKey.contains(filterKey);
}

String formatPropertyPrice(int price) {
  if (price <= 0) return 'Kes. —';
  if (price >= 1000) return 'Kes. ${price ~/ 1000}k';
  return 'Kes. $price';
}
