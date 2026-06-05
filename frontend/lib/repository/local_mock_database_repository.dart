import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class LocalMockDatabaseRepository {
  const LocalMockDatabaseRepository();

  Future<Map<String, dynamic>> loadDatabase() async {
    final jsonStr = await rootBundle.loadString(
      'assets/data/local_mock_database.json',
    );
    final decoded = jsonDecode(jsonStr);
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<List<Map<String, dynamic>>> loadProperties() async {
    final data = await loadDatabase();
    final all = data['properties']?['all'] as List<dynamic>? ?? const [];
    return all.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<Map<String, List<Map<String, dynamic>>>>
      loadPropertiesByCategory() async {
    final data = await loadDatabase();
    final categories =
        data['properties']?['categories'] as Map<String, dynamic>? ?? const {};

    final result = <String, List<Map<String, dynamic>>>{};
    for (final entry in categories.entries) {
      final items = (entry.value as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      result[entry.key] = items;
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> loadUsers() async {
    final data = await loadDatabase();
    final users = data['users'] as List<dynamic>? ?? const [];
    return users.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> loadSignupDrafts() async {
    final data = await loadDatabase();
    final drafts = data['auth']?['signupDrafts'] as List<dynamic>? ?? const [];
    return drafts
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> loadAuthDefaults() async {
    final data = await loadDatabase();
    return Map<String, dynamic>.from(data['auth'] as Map);
  }

  Future<List<Map<String, dynamic>>> loadVerificationStates() async {
    final data = await loadDatabase();
    final states = data['verification'] as List<dynamic>? ?? const [];
    return states
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> loadSettingsOptions() async {
    final data = await loadDatabase();
    final settings = data['settings'] as List<dynamic>? ?? const [];
    return settings
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>?> authenticate(
      String email, String password) async {
    final authDefaults = await loadAuthDefaults();
    final loginFallbacks =
        (authDefaults['loginFallbacks'] as List<dynamic>? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();

    final matchedLogin = loginFallbacks.firstWhere(
      (item) =>
          item['email'].toString().toLowerCase() == email.toLowerCase() &&
          item['password'].toString() == password,
      orElse: () => <String, dynamic>{},
    );

    if (matchedLogin.isEmpty) {
      return null;
    }

    final users = await loadUsers();
    final user = users.firstWhere(
      (item) => item['email'].toString().toLowerCase() == email.toLowerCase(),
      orElse: () => <String, dynamic>{},
    );

    if (user.isEmpty) {
      return null;
    }

    final resolved = Map<String, dynamic>.from(user);
    resolved['role'] = matchedLogin['role'];
    return resolved;
  }

  Future<List<Map<String, dynamic>>> loadPropertiesForUser(
      String userId) async {
    final users = await loadUsers();
    final user = users.firstWhere(
      (item) => item['id'].toString() == userId,
      orElse: () => <String, dynamic>{},
    );

    if (user.isEmpty) {
      return const [];
    }

    final linkedIds = (user['linkedProperties'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toSet();

    final allProperties = await loadProperties();
    return allProperties
        .where((property) => linkedIds.contains(property['id'].toString()))
        .toList();
  }

  Future<List<String>> loadLocalAssetImages() async {
    final data = await loadDatabase();
    final assets = data['assets'] as List<dynamic>? ?? const [];
    return assets.map((item) => item.toString()).toList();
  }
}
