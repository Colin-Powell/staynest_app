const fs = require('fs');
const file = 'frontend/lib/screens/notification_settings_view.dart';
let text = fs.readFileSync(file, 'utf8');

text = `import 'package:property_app/repository/remote_database_repository.dart';\nimport 'package:property_app/session/app_session.dart';\n` + text;

text = text.replace(
  `final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enableAllNotifications = prefs.getBool('enableAllNotifications') ?? true;
      _enableChatNotifications =
          prefs.getBool('enableChatNotifications') ?? true;
      _enableBookingUpdates = prefs.getBool('enableBookingUpdates') ?? true;
      _enablePromotions = prefs.getBool('enablePromotions') ?? false;
    });`,
  `final prefs = await SharedPreferences.getInstance();
    final user = AppSession.currentUser;
    final notifs = user['settings']?['tenant_notifications'] ?? {};
    
    setState(() {
      _enableAllNotifications = notifs['enableAllNotifications'] ?? prefs.getBool('enableAllNotifications') ?? true;
      _enableChatNotifications = notifs['enableChatNotifications'] ?? prefs.getBool('enableChatNotifications') ?? true;
      _enableBookingUpdates = notifs['enableBookingUpdates'] ?? prefs.getBool('enableBookingUpdates') ?? true;
      _enablePromotions = notifs['enablePromotions'] ?? prefs.getBool('enablePromotions') ?? false;
    });`
);

text = text.replace(
  `Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);`,
  `Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    
    try {
      final repo = RemoteDatabaseRepository();
      final updated = await repo.updateCurrentUser(update: {
        'settings': {
          ...(AppSession.currentUser['settings'] ?? {}),
          'tenant_notifications': {
            'enableAllNotifications': key == 'enableAllNotifications' ? value : _enableAllNotifications,
            'enableChatNotifications': key == 'enableChatNotifications' ? value : _enableChatNotifications,
            'enableBookingUpdates': key == 'enableBookingUpdates' ? value : _enableBookingUpdates,
            'enablePromotions': key == 'enablePromotions' ? value : _enablePromotions,
          }
        }
      });
      AppSession.updateCurrentUser(updated);
    } catch (e) {
      debugPrint('Failed to sync notification settings: $e');
    }`
);

fs.writeFileSync(file, text, 'utf8');
