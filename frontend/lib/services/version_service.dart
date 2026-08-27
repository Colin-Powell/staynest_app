import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:property_app/session/app_session.dart';
import 'package:google_fonts/google_fonts.dart';

class VersionService {
  static Future<void> checkVersion(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse('${AppSession.apiBaseUrl}/version'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String latestVersion = data['latestVersion'] ?? '1.0.0';
        final String updateUrl = data['updateUrl'] ?? 'https://staynest.top/update.html';
        final bool forceUpdate = false; // Overridden to always allow skipping

        // Simple string comparison for versions (assumes semantic versioning like 1.0.1)
        if (_isUpdateAvailable(AppSession.currentAppVersion, latestVersion)) {
          _showUpgradePrompt(context, updateUrl, forceUpdate);
        }
      }
    } catch (e) {
      debugPrint('Version check failed: $e');
    }
  }

  static bool _isUpdateAvailable(String current, String latest) {
    final v1 = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final v2 = latest.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    
    for (int i = 0; i < 3; i++) {
      final c = i < v1.length ? v1[i] : 0;
      final l = i < v2.length ? v2[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  static void _showUpgradePrompt(BuildContext context, String url, bool force) {
    showModalBottomSheet(
      context: context,
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
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
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
