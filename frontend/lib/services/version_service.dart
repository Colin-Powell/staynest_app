import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:property_app/session/app_session.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VersionService {
  static const String _lastPromptKey = 'last_update_prompt_time';
  static const String _lastPromptedVersionKey = 'last_prompted_update_version';
  static bool _isChecking = false;
  static bool _isPromptVisible = false;

  static Future<void> checkVersion(BuildContext context) async {
    if (_isChecking || _isPromptVisible) return;
    _isChecking = true;

    try {
      await AppSession.initializeAppInfo();
      final prefs = await SharedPreferences.getInstance();

      final response = await http
          .get(Uri.parse('${AppSession.apiBaseUrl}/version'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) return;

        final latestVersion = decoded['latestVersion']?.toString().trim();
        if (latestVersion == null || latestVersion.isEmpty) return;
        final String updateUrl = decoded['updateUrl']?.toString() ??
            'https://staynest.top/update.html';
        const bool forceUpdate = false; // Overridden to always allow skipping

        if (_isUpdateAvailable(AppSession.currentAppVersion, latestVersion)) {
          final lastPromptedVersion = prefs.getString(_lastPromptedVersionKey);
          final lastPromptStr = prefs.getString(_lastPromptKey);
          final lastPromptTime =
              lastPromptStr == null ? null : DateTime.tryParse(lastPromptStr);
          final wasPromptedRecently = lastPromptedVersion == latestVersion &&
              lastPromptTime != null &&
              DateTime.now().difference(lastPromptTime).inHours < 24;

          if (!wasPromptedRecently) {
            if (!context.mounted) return;
            await prefs.setString(
                _lastPromptKey, DateTime.now().toIso8601String());
            await prefs.setString(_lastPromptedVersionKey, latestVersion);
            if (!context.mounted) return;
            _isPromptVisible = true;
            try {
              await _showUpgradePrompt(context, updateUrl, forceUpdate);
            } finally {
              _isPromptVisible = false;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Version check failed: $e');
    } finally {
      _isChecking = false;
    }
  }

  static bool _isUpdateAvailable(String current, String latest) {
    final v1 = _parseVersion(current);
    final v2 = _parseVersion(latest);

    final length = v1.length > v2.length ? v1.length : v2.length;
    for (int i = 0; i < length; i++) {
      final c = i < v1.length ? v1[i] : 0;
      final l = i < v2.length ? v2[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  static List<int> _parseVersion(String version) {
    return version
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('+')
        .first
        .split('-')
        .first
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }

  static Future<void> _showUpgradePrompt(
      BuildContext context, String url, bool force) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: !force,
      enableDrag: !force,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return PopScope(
          canPop: !force,
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: Color(0xFF2563EB),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Update Available',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'A new version of StayNest is available. Please update to continue enjoying the best experience.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      final uri = Uri.parse(url);
                      try {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      } catch (e) {
                        debugPrint('Could not launch update URL: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Update Now',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (!force) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Maybe Later',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}
