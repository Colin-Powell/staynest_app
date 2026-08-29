import re

with open('lib/screens/dashboard/admin_dashboard_view.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("Widget _buildAdminNotificationItem(int index, NotificationItem item)", "Widget _buildAdminNotificationItem(int index, AdminNotificationItem item)")

with open('lib/screens/dashboard/admin_dashboard_view.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patched NotificationItem")
