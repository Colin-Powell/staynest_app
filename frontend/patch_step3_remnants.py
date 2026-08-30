import re

with open('lib/screens/landlord/listing_flow.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix backend fetch logic at line 198 (in initState _fetchBackendDraft maybe?)
fetch_target = """        if (data['amenities'] is List) {
          for (final a in (data['amenities'] as List)) {
            _amenities[a.toString()] = true;
          }
        }"""
fetch_replacement = """        if (data['amenities'] is List) {
          for (final a in (data['amenities'] as List)) {
            final str = a.toString();
            if (str.startsWith('custom:')) {
              _customFeatures.add(str.substring(7));
            } else {
              final mapped = PropertyTaxonomy.mapLegacyLabel(str);
              final attr = PropertyTaxonomy.getAttributeById(mapped);
              if (attr != null) _selectedAttributes.add(attr.id);
            }
          }
        }"""
content = content.replace(fetch_target, fetch_replacement)

# Fix _publishProperty payload at line 331
publish_target = """      final selectedAmenities = _amenities.entries.where((e) => e.value).map((e) => e.key).toList();"""
publish_replacement = """      final selectedAmenities = [..._selectedAttributes, ..._customFeatures.map((c) => 'custom:$c')];"""
content = content.replace(publish_target, publish_replacement)

# Fix _buildStep6Review (line 1094)
review_start_target = """  Widget _buildStep6Review() {
    List<MapEntry<String, bool>> selectedAmenities = _amenities.entries.where((e) => e.value).toList();"""
review_start_replacement = """  Widget _buildStep6Review() {
    final selectedAmenities = [
        ..._selectedAttributes.map((id) => PropertyTaxonomy.getAttributeById(id)?.label ?? id),
        ..._customFeatures
    ];"""
content = content.replace(review_start_target, review_start_replacement)

# Fix 'Furnished' reference at line 1203
furnish_target = """_buildReviewRow('Furnished', _amenities['Furnished'] == true ? 'Yes' : 'No'),"""
furnish_replacement = """_buildReviewRow('Furnished', _selectedAttributes.contains('furnished') ? 'Yes' : 'No'),"""
content = content.replace(furnish_target, furnish_replacement)

# Fix Amenities Wrap mapping at line 1223
wrap_target = """          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: selectedAmenities.map((e) {
              IconData icon = _essentialAmenities[e.key] ?? _additionalAmenities[e.key] ?? PhosphorIconsRegular.check;
              return _buildAmenityPill(e.key, icon);
            }).toList()..addAll([
              if (selectedAmenities.isEmpty)
                Text('No amenities selected.', style: GoogleFonts.poppins(color: _grey, fontStyle: FontStyle.italic, fontSize: 14))
            ]),
          ),"""
wrap_replacement = """          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: selectedAmenities.map((label) {
              return _buildAmenityPill(label, PhosphorIconsRegular.check);
            }).toList()..addAll([
              if (selectedAmenities.isEmpty)
                Text('No features selected.', style: GoogleFonts.poppins(color: _grey, fontStyle: FontStyle.italic, fontSize: 14))
            ]),
          ),"""
content = content.replace(wrap_target, wrap_replacement)

with open('lib/screens/landlord/listing_flow.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patched remaining amenity errors")
