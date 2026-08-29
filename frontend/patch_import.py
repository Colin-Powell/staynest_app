import re

with open('lib/screens/dashboard/admin_dashboard_view.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import 'package:property_app/screens/screens.dart' show NotificationItem;", "import 'package:property_app/screens/screens.dart';")

with open('lib/screens/dashboard/admin_dashboard_view.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Removed show NotificationItem")
