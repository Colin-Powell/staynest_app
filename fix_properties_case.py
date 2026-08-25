import re

with open("frontend/lib/screens/dashboard/landlord_portal_view.dart", "r", encoding="utf-8") as f:
    code = f.read()

old_switch = """switch (_selectedNav) {
  case 'Bookings':"""

new_switch = """switch (_selectedNav) {
      case 'Properties':
        return LandlordPropertiesPage(onAddProperty: widget.onAddProperty);
      case 'Bookings':"""

if "case 'Properties':" not in code:
    code = code.replace(old_switch, new_switch)

with open("frontend/lib/screens/dashboard/landlord_portal_view.dart", "w", encoding="utf-8") as f:
    f.write(code)

print("Added case 'Properties' to switch")
