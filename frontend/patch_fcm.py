import re

with open('lib/services/fcm_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = """      // Note: createNotificationChannel requires a platform-specific plugin
      // resolve API which differs across flutter_local_notifications versions.
      // If channel creation fails to compile, we safely skip it here; the
      // channel will still be usable with valid Android channel identifiers."""

replacement = """      // Create Android Notification Channel
      final androidImplementation = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(_channel);
      }"""

if target in content:
    content = content.replace(target, replacement)
    with open('lib/services/fcm_service.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Patched fcm_service.dart")
else:
    print("Could not find target in fcm_service.dart")
