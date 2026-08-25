import re

# --- 1. Fix landlord_properties_page.dart ---
with open("frontend/lib/screens/dashboard/landlord_properties_page.dart", "r", encoding="utf-8") as f:
    code = f.read()

if "PropertiesApi.getLandlordProperties()" not in code:
    if "import 'package:property_app/services/properties_api.dart';" not in code:
        code = code.replace(
            "import 'package:property_app/services/property_service.dart';",
            "import 'package:property_app/services/property_service.dart';\nimport 'package:property_app/services/properties_api.dart';\nimport 'package:property_app/utils/property_mapper.dart';"
        )
    
    old_load = """final loaded = await _propertyService.fetchProperties();
      if (!mounted) return;
      setState(() {
        _properties = loaded.cast<Property>();
        _loading = false;
      });"""
    new_load = """final rawList = await PropertiesApi.getLandlordProperties();
      if (!mounted) return;
      setState(() {
        _properties = rawList.map((m) => mapApiProperty(m)).toList();
        _loading = false;
      });"""
    code = code.replace(old_load, new_load)
    
    with open("frontend/lib/screens/dashboard/landlord_properties_page.dart", "w", encoding="utf-8") as f:
        f.write(code)

# --- 2. Fix landlord_overview_page.dart ---
with open("frontend/lib/screens/dashboard/landlord_overview_page.dart", "r", encoding="utf-8") as f:
    code = f.read()

# Make it accept onViewAllProperties
old_class = """class LandlordOverviewPage extends StatefulWidget {
  const LandlordOverviewPage({super.key});

  @override
  State<LandlordOverviewPage> createState() => _LandlordOverviewPageState();
}"""
new_class = """class LandlordOverviewPage extends StatefulWidget {
  final VoidCallback? onViewAllProperties;
  const LandlordOverviewPage({super.key, this.onViewAllProperties});

  @override
  State<LandlordOverviewPage> createState() => _LandlordOverviewPageState();
}"""
if "final VoidCallback? onViewAllProperties;" not in code:
    code = code.replace(old_class, new_class)

# Add GestureDetector to View All Properties
old_button = """// --- VIEW ALL PROPERTIES BUTTON ---
            GlassContainer(
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'View All Properties',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textLight,
                  ),
                ),
              ),
            ),"""
new_button = """// --- VIEW ALL PROPERTIES BUTTON ---
            GestureDetector(
              onTap: widget.onViewAllProperties,
              child: GlassContainer(
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'View All Properties',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textLight,
                    ),
                  ),
                ),
              ),
            ),"""
code = code.replace(old_button, new_button)

# Add GestureDetector to Property Cards
old_card_loop = """..._properties.take(3).map((property) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _buildPropertyCard(property),
              );
            }),"""
new_card_loop = """..._properties.take(3).map((property) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(
                      context, 
                      '/landlord_property_management',
                      arguments: <String, dynamic>{'propertyId': property['id']},
                    );
                  },
                  child: _buildPropertyCard(property),
                ),
              );
            }),"""
code = code.replace(old_card_loop, new_card_loop)

with open("frontend/lib/screens/dashboard/landlord_overview_page.dart", "w", encoding="utf-8") as f:
    f.write(code)

# --- 3. Fix landlord_portal_view.dart ---
with open("frontend/lib/screens/dashboard/landlord_portal_view.dart", "r", encoding="utf-8") as f:
    code = f.read()

old_overview_return = "return const LandlordOverviewPage();"
new_overview_return = "return LandlordOverviewPage(onViewAllProperties: () => setState(() => _selectedNav = 'Properties'));"
code = code.replace(old_overview_return, new_overview_return)

with open("frontend/lib/screens/dashboard/landlord_portal_view.dart", "w", encoding="utf-8") as f:
    f.write(code)

print("Fixed landlord issues")
