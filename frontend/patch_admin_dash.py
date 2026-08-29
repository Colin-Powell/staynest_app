import re

with open('lib/screens/dashboard/admin_dashboard_view.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("class NotificationsView", "class AdminNotificationsView")
content = content.replace("State<NotificationsView>", "State<AdminNotificationsView>")
content = content.replace("_NotificationsViewState", "_AdminNotificationsViewState")
content = content.replace("const NotificationsView", "const AdminNotificationsView")
content = content.replace("class NotificationItem", "class AdminNotificationItem")
content = content.replace("List<NotificationItem>", "List<AdminNotificationItem>")
content = content.replace("NotificationItem(", "AdminNotificationItem(")

with open('lib/screens/dashboard/admin_dashboard_view.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patched admin_dashboard_view.dart")
