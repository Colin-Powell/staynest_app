import re

with open('lib/session/app_session.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = """    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await _storage.delete(key: _prefsKey);
        return;
      }

      currentUserId = decoded['userId'];
      currentUserRole = decoded['userRole'];
      currentUserName = decoded['userName'];
      currentUserAvatar = decoded['userAvatar'];
      _token = decoded['token'];"""

replacement = """    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await _storage.delete(key: _prefsKey);
        return;
      }

      currentUserId = decoded['userId'];
      currentUserRole = decoded['userRole'];
      currentUserName = decoded['userName'];
      currentUserAvatar = decoded['userAvatar'];
      _token = decoded['token'];
      
      // Sync FCM token if the user is restored
      if (currentUserId != null) {
        // We import it dynamically or just call it if available.
        // Wait, app_session might not have AuthService imported.
      }"""
# Wait, I need to know if AuthService is imported in app_session.dart
