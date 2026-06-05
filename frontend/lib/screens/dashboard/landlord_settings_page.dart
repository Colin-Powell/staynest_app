// lib/screens/dashboard/landlord_settings_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class LandlordSettingsPage extends StatelessWidget {
  const LandlordSettingsPage({super.key});

  static const Color textDark = Color(0xFF111827);
  static const Color textLight = Color(0xFF9CA3AF); // Lighter grey for subtitles
  static const Color iconColor = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Let portal gradient show through
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          // Padding of 130 at bottom ensures it scrolls above the glass nav bar
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 130),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      // Handle back navigation if needed, or open menu
                    },
                    behavior: HitTestBehavior.opaque,
                    child: const Icon(Icons.arrow_back, color: textDark, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Settings',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // --- PROFILE SECTION ---
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      image: const DecorationImage(
                        image: NetworkImage(
                          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?ixlib=rb-4.0.3&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jomison',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'View and edit your profile',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // --- SETTINGS LIST ---
              _buildSettingRow(
                title: 'Personal Information',
                icon: PhosphorIcons.user(PhosphorIconsStyle.fill),
                onTap: () {},
              ),
              _buildSettingRow(
                title: 'Business Information',
                icon: PhosphorIcons.buildings(PhosphorIconsStyle.fill),
                onTap: () {},
              ),
              _buildSettingRow(
                title: 'Notification Settings',
                icon: PhosphorIcons.bell(PhosphorIconsStyle.fill),
                onTap: () {},
              ),
              _buildSettingRow(
                title: 'Bank Details',
                icon: PhosphorIcons.creditCard(PhosphorIconsStyle.fill),
                onTap: () {},
              ),
              _buildSettingRow(
                title: 'Privacy Policy',
                icon: PhosphorIcons.fileLock(PhosphorIconsStyle.fill),
                onTap: () {},
              ),
              _buildSettingRow(
                title: 'Change Password',
                icon: PhosphorIcons.lockKey(PhosphorIconsStyle.fill), // Alternative to shopping bag icon in PDF
                onTap: () {},
              ),
              _buildSettingRow(
                title: 'Two-Factor Authentication',
                icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                trailingText: 'On',
                onTap: () {},
              ),

              const SizedBox(height: 32),

              // --- LOGOUT BUTTON ---
              GestureDetector(
                onTap: () {
                  // Handle logout logic
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIcons.signOut(),
                        color: const Color(0xFFEF4444), // Red
                        size: 28,
                      ),
                      const SizedBox(width: 20),
                      Text(
                        'Logout',
                        style: GoogleFonts.poppins(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFEF4444), // Red
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    String? trailingText,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 32), // High vertical spacing matching PDF
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 28,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: textDark,
                ),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF10B981), // Green color for "On"
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: iconColor.withOpacity(0.8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}