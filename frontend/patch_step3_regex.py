import re

with open('lib/screens/landlord/listing_flow.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update imports
if "property_taxonomy.dart" not in content:
    content = content.replace("import 'package:property_app/widgets/property_image.dart';", "import 'package:property_app/widgets/property_image.dart';\nimport 'package:property_app/models/property_taxonomy.dart';")


# 2. State variables
content = re.sub(
    r'// --- Step 3: Amenities ---.*?// --- Step 4: Photos ---',
    """// --- Step 3: Amenities ---
  final Set<String> _selectedAttributes = {};
  final List<String> _customFeatures = [];
  final TextEditingController _customFeatureController = TextEditingController();

  // --- Step 4: Photos ---""",
    content,
    flags=re.DOTALL
)

# 3. Clean up the messed up get properties
content = re.sub(
    r'  get _selectedAttributes => null;\s*get _customFeatures => null;\s*',
    '',
    content,
    flags=re.DOTALL
)

# 4. _loadDraft logic
load_draft_target = """      final existingAmenities = existing['amenities'];
      if (existingAmenities is List) {
        for (final amenity in existingAmenities) {
          final name = amenity.toString();
          if (_amenities.containsKey(name)) _amenities[name] = true;
        }
      }"""
load_draft_replacement = """      final existingAmenities = existing['amenities'];
      if (existingAmenities is List) {
        for (final amenity in existingAmenities) {
          final str = amenity.toString();
          if (str.startsWith('custom:')) {
            _customFeatures.add(str.substring(7));
          } else {
            final mapped = PropertyTaxonomy.mapLegacyLabel(str);
            final attr = PropertyTaxonomy.getAttributeById(mapped);
            if (attr != null) _selectedAttributes.add(attr.id);
          }
        }
      }"""
content = content.replace(load_draft_target, load_draft_replacement)


# 5. initState _amenities loop removal
init_target = """    for (var key in [..._essentialAmenities.keys, ..._additionalAmenities.keys]) {
      _amenities[key] = false;
    }"""
content = content.replace(init_target, "")


# 6. saveDraft payload
payload_target = """        'amenities': _amenities.entries.where((e) => e.value).map((e) => e.key).toList(),"""
payload_replacement = """        'amenities': [..._selectedAttributes, ..._customFeatures.map((c) => 'custom:$c')],"""
content = content.replace(payload_target, payload_replacement)


# 7. UI Widget _buildStep3Amenities
content = re.sub(
    r'Widget _buildStep3Amenities\(\) \{.*?\n  Widget _buildCheckbox\(String label, IconData icon\) \{.*?\n  \}',
    """Widget _buildStep3Amenities() {
    final popular = PropertyTaxonomy.getPopularAttributes(propertyType: _propertyType);
    final allAttrs = PropertyTaxonomy.getAttributesForPropertyType(_propertyType);
    final categorized = <String, List<PropertyAttribute>>{};
    
    for (var attr in allAttrs) {
      if (!categorized.containsKey(attr.category)) {
        categorized[attr.category] = [];
      }
      categorized[attr.category]!.add(attr);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Property Features',
              style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: _dark, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text('Select the features, utilities and services available at this property.',
              style: GoogleFonts.poppins(fontSize: 14, color: _grey)),
          const SizedBox(height: 32),

          if (popular.isNotEmpty) ...[
            Text('Popular for students',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: _dark)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: popular.map((p) => _buildFeatureChip(p)).toList(),
            ),
            const SizedBox(height: 32),
            Container(height: 1, color: _grey.withValues(alpha: 0.2)),
            const SizedBox(height: 24),
          ],

          ...PropertyTaxonomy.categories.map((cat) {
            final catAttrs = categorized[cat.id] ?? [];
            if (catAttrs.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.label,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: _dark)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 12,
                  children: catAttrs.map((p) => _buildFeatureChip(p)).toList(),
                ),
                const SizedBox(height: 32),
              ],
            );
          }),
          
          Text('Custom Features',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: _dark)),
          const SizedBox(height: 16),
          ..._customFeatures.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: _green, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(c, style: GoogleFonts.poppins(fontSize: 14))),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: _grey),
                  onPressed: () => setState(() => _customFeatures.remove(c)),
                ),
              ],
            ),
          )),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customFeatureController,
                  decoration: InputDecoration(
                    hintText: 'Add another feature...',
                    hintStyle: GoogleFonts.poppins(color: _grey, fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _grey.withValues(alpha: 0.3))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _grey.withValues(alpha: 0.3))),
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) {
                      setState(() {
                        _customFeatures.add(v.trim());
                        _customFeatureController.clear();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.add_circle, color: _green, size: 36),
                onPressed: () {
                  if (_customFeatureController.text.trim().isNotEmpty) {
                    setState(() {
                      _customFeatures.add(_customFeatureController.text.trim());
                      _customFeatureController.clear();
                    });
                  }
                },
              )
            ],
          ),

          const SizedBox(height: 48),
          _buildNextButton('Next: Photos', _nextStep),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(PropertyAttribute attr) {
    final isSelected = _selectedAttributes.contains(attr.id);
    return FilterChip(
      selected: isSelected,
      label: Text(attr.label),
      labelStyle: GoogleFonts.poppins(
        fontSize: 13,
        color: isSelected ? Colors.white : _dark,
        fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
      ),
      selectedColor: _green,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? _green : _grey.withValues(alpha: 0.3),
        ),
      ),
      onSelected: (val) {
        setState(() {
          if (val) _selectedAttributes.add(attr.id);
          else _selectedAttributes.remove(attr.id);
        });
      },
    );
  }""",
    content,
    flags=re.DOTALL
)

# 8. Step 6 Review UI
content = re.sub(
    r'List<MapEntry<String, bool>> selectedAmenities =.*?\n        const Divider\(height: 32, color: _grey, thickness: 0\.3\),',
    """final selectedAmenities = [
        ..._selectedAttributes.map((id) => PropertyTaxonomy.getAttributeById(id)?.label ?? id),
        ..._customFeatures
      ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Basic Info'),
        _buildReviewRow('Type', _propertyType),
        _buildReviewRow('Title', _title.text),
        _buildReviewRow('Bedrooms', _bedrooms.toString()),
        _buildReviewRow('Bathrooms', _bathrooms.toString()),
        _buildReviewRow(
            'Furnished', _selectedAttributes.contains('furnished') ? 'Yes' : 'No'),
        const Divider(height: 32, color: _grey, thickness: 0.3),
        _buildSectionTitle('Location'),
        _buildReviewRow('City', _selectedCity ?? ''),
        _buildReviewRow('Neighborhood', _neighborhood.text),
        const Divider(height: 32, color: _grey, thickness: 0.3),
        _buildSectionTitle('Features'),
        if (selectedAmenities.isNotEmpty)
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: selectedAmenities.map((label) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 16, color: _green),
                  const SizedBox(width: 6),
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: _dark)),
                ],
              );
            }).toList(),
          ),
        if (selectedAmenities.isEmpty)
          Text('No features selected.',
              style:
                  GoogleFonts.poppins(fontSize: 14, color: _grey)),
        const Divider(height: 32, color: _grey, thickness: 0.3),""",
    content,
    flags=re.DOTALL
)


with open('lib/screens/landlord/listing_flow.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Regex patched listing_flow.dart")
