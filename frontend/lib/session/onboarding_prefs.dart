import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPrefs {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static bool hasSeen(String key) {
    return _prefs.getBool(key) ?? false;
  }

  static Future<void> markAsSeen(String key) async {
    await _prefs.setBool(key, true);
  }
}
