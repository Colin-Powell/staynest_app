import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'landlord_analytics_page.dart';

// --- MAIN SETTINGS PAGE ---

class LandlordSettingsPage extends StatelessWidget {
  const LandlordSettingsPage({super.key});

  static const Color textDark = Color(0xFF111827);
  static const Color textLight = Color(0xFF9CA3AF);
  static const Color iconColor = Color(0xFF9CA3AF);

  // Smooth slide transition for navigating to subpages
  void _navigateTo(BuildContext context, Widget page) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Let portal gradient show through
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 130),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              Row(
                children: [
                  const Icon(Icons.arrow_back, color: textDark, size: 28),
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
                title: 'Performance & Insights',
                icon: PhosphorIcons.chartLineUp(PhosphorIconsStyle.fill),
                onTap: () =>
                    _navigateTo(context, const LandlordAnalyticsPage()),
              ),
              _buildSettingRow(
                title: 'Personal Information',
                icon: PhosphorIcons.user(PhosphorIconsStyle.fill),
                onTap: () => _navigateTo(context, const PersonalInfoPage()),
              ),
              _buildSettingRow(
                title: 'Business Information',
                icon: PhosphorIcons.buildings(PhosphorIconsStyle.fill),
                onTap: () => _navigateTo(context, const BusinessInfoPage()),
              ),
              _buildSettingRow(
                title: 'Notification Settings',
                icon: PhosphorIcons.bell(PhosphorIconsStyle.fill),
                onTap: () =>
                    _navigateTo(context, const NotificationSettingsPage()),
              ),
              _buildSettingRow(
                title: 'Bank Details',
                icon: PhosphorIcons.creditCard(PhosphorIconsStyle.fill),
                onTap: () => _navigateTo(context, const BankDetailsPage()),
              ),
              _buildSettingRow(
                title: 'Privacy Policy',
                icon: PhosphorIcons.fileLock(PhosphorIconsStyle.fill),
                onTap: () => _navigateTo(context, const PrivacyPolicyPage()),
              ),
              _buildSettingRow(
                title: 'Change Password',
                icon: PhosphorIcons.lockKey(PhosphorIconsStyle.fill),
                onTap: () => _navigateTo(context, const ChangePasswordPage()),
              ),
              _buildSettingRow(
                title: 'Two-Factor Authentication',
                icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                trailingText: 'On',
                onTap: () => _navigateTo(context, const TwoFactorAuthPage()),
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
                        color: const Color(0xFFEF4444),
                        size: 28,
                      ),
                      const SizedBox(width: 20),
                      Text(
                        'Logout',
                        style: GoogleFonts.poppins(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFEF4444),
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
        padding: const EdgeInsets.only(bottom: 32),
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
                  color: const Color(0xFF059669),
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

// --- SHARED SUBPAGE LAYOUT ---
// Wraps every subpage with the Portal's global background gradient and a standardized Appbar
class SettingsPageLayout extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? bottomNavigationBar;

  const SettingsPageLayout({
    super.key,
    required this.title,
    required this.child,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      bottomNavigationBar: bottomNavigationBar,
      body: Stack(
        children: [
          // Background Gradient (Matches Portal)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF7FDF9),
                  Color(0xFFE8F6EF),
                  Color(0xFFD4EFE1),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Custom Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        behavior: HitTestBehavior.opaque,
                        child: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF111827),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Page Content
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Shared UI helper for Input Fields
Widget _buildTextField(String label,
    {String? hintText, bool isPassword = false, IconData? prefixIcon}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          obscureText: isPassword,
          style: GoogleFonts.poppins(fontSize: 15),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.poppins(
                color: const Color(0xFF9CA3AF), fontSize: 15),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: const Color(0xFF9CA3AF), size: 22)
                : null,
            filled: true,
            fillColor: Colors.white.withOpacity(0.8),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF059669), width: 1.5),
            ),
          ),
        ),
      ],
    ),
  );
}

// Shared UI helper for Save Buttons
Widget _buildSaveButton(BuildContext context, {String text = "Save Changes"}) {
  return Container(
    padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.6),
      border: Border(top: BorderSide(color: Colors.black.withOpacity(0.05))),
    ),
    child: ElevatedButton(
      onPressed: () => Navigator.pop(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF059669),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 56),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    ),
  );
}

// --- 1. PERSONAL INFORMATION PAGE ---
class PersonalInfoPage extends StatelessWidget {
  const PersonalInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPageLayout(
      title: 'Personal Info',
      bottomNavigationBar: _buildSaveButton(context),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                      )
                    ],
                    image: const DecorationImage(
                      image: NetworkImage(
                          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?ixlib=rb-4.0.3&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF059669),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: Colors.white, size: 18),
                )
              ],
            ),
            const SizedBox(height: 40),
            _buildTextField('Full Name', hintText: 'Jomison'),
            _buildTextField('Email Address',
                hintText: 'jomison@example.com',
                prefixIcon: PhosphorIcons.envelopeSimple()),
            _buildTextField('Phone Number',
                hintText: '+1 (555) 000-0000',
                prefixIcon: PhosphorIcons.phone()),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// --- 2. BUSINESS INFORMATION PAGE ---
class BusinessInfoPage extends StatelessWidget {
  const BusinessInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPageLayout(
      title: 'Business Info',
      bottomNavigationBar: _buildSaveButton(context),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildTextField('Company / Agency Name',
                hintText: 'StayNest Properties LLC',
                prefixIcon: PhosphorIcons.buildings()),
            _buildTextField('Business Registration Number',
                hintText: 'RC-123456789'),
            _buildTextField('Business Address',
                hintText: '123 Real Estate Ave, Suite 100',
                prefixIcon: PhosphorIcons.mapPin()),
            _buildTextField('Tax Identification Number (TIN)',
                hintText: 'XXX-XX-XXXX'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// --- 3. NOTIFICATION SETTINGS PAGE ---
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool emailNewBooking = true;
  bool emailMessages = true;
  bool pushNewBooking = true;
  bool pushMessages = false;
  bool smsAlerts = false;

  @override
  Widget build(BuildContext context) {
    return SettingsPageLayout(
      title: 'Notifications',
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          _buildSectionHeader('Email Notifications'),
          _buildSwitchTile(
              'New Bookings',
              'Get notified when a new booking is made',
              emailNewBooking,
              (v) => setState(() => emailNewBooking = v)),
          _buildSwitchTile(
              'New Messages',
              'Get notified of new tenant messages',
              emailMessages,
              (v) => setState(() => emailMessages = v)),
          const SizedBox(height: 24),
          _buildSectionHeader('Push Notifications'),
          _buildSwitchTile('New Bookings', 'Push alerts for new bookings',
              pushNewBooking, (v) => setState(() => pushNewBooking = v)),
          _buildSwitchTile('New Messages', 'Push alerts for new messages',
              pushMessages, (v) => setState(() => pushMessages = v)),
          const SizedBox(height: 24),
          _buildSectionHeader('SMS Notifications'),
          _buildSwitchTile(
              'Critical Alerts',
              'Important account or booking updates via SMS',
              smsAlerts,
              (v) => setState(() => smsAlerts = v)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF059669),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: const Color(0xFF059669),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// --- 4. BANK DETAILS PAGE ---
class BankDetailsPage extends StatelessWidget {
  const BankDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPageLayout(
      title: 'Bank Details',
      bottomNavigationBar: _buildSaveButton(context, text: "Save Bank Details"),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 32, top: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFF059669).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.info(PhosphorIconsStyle.fill),
                      color: const Color(0xFF059669)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'These details will be used to process your rental payouts.',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: const Color(0xFF064E3B)),
                    ),
                  ),
                ],
              ),
            ),
            _buildTextField('Bank Name',
                hintText: 'e.g. Chase Bank', prefixIcon: PhosphorIcons.bank()),
            _buildTextField('Account Holder Name',
                hintText: 'Jomison Real Estate'),
            _buildTextField('Account Number', hintText: '1234567890'),
            _buildTextField('Routing Number', hintText: '098765432'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// --- 5. PRIVACY POLICY PAGE ---
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPageLayout(
      title: 'Privacy Policy',
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data Collection & Usage',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827)),
              ),
              const SizedBox(height: 12),
              Text(
                'We collect information to provide better services to all our users. Information collected includes your name, email address, phone number, and properties managed.\n\nYour data is securely stored and never shared with third parties without your explicit consent.',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: const Color(0xFF4B5563), height: 1.6),
              ),
              const SizedBox(height: 24),
              Text(
                'Your Rights',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827)),
              ),
              const SizedBox(height: 12),
              Text(
                'You have the right to request access to the data we hold about you. You can also request deletion of your account and associated data at any time from the account settings.',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: const Color(0xFF4B5563), height: 1.6),
              ),
              const SizedBox(height: 24),
              Text(
                'Last updated: October 2024',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 6. CHANGE PASSWORD PAGE ---
class ChangePasswordPage extends StatelessWidget {
  const ChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPageLayout(
      title: 'Change Password',
      bottomNavigationBar: _buildSaveButton(context, text: "Update Password"),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildTextField('Current Password',
                hintText: '••••••••',
                isPassword: true,
                prefixIcon: PhosphorIcons.lock()),
            const SizedBox(height: 8),
            _buildTextField('New Password',
                hintText: '••••••••',
                isPassword: true,
                prefixIcon: PhosphorIcons.lockKey()),
            _buildTextField('Confirm New Password',
                hintText: '••••••••',
                isPassword: true,
                prefixIcon: PhosphorIcons.lockKey()),
          ],
        ),
      ),
    );
  }
}

// --- 7. TWO-FACTOR AUTHENTICATION PAGE ---
class TwoFactorAuthPage extends StatefulWidget {
  const TwoFactorAuthPage({super.key});

  @override
  State<TwoFactorAuthPage> createState() => _TwoFactorAuthPageState();
}

class _TwoFactorAuthPageState extends State<TwoFactorAuthPage> {
  bool is2faEnabled = true;

  @override
  Widget build(BuildContext context) {
    return SettingsPageLayout(
      title: 'Two-Factor Auth',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Column(
                children: [
                  Icon(
                    PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                    size: 64,
                    color: is2faEnabled
                        ? const Color(0xFF059669)
                        : const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    is2faEnabled
                        ? '2FA is currently Enabled'
                        : '2FA is currently Disabled',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Two-factor authentication adds an extra layer of security to your account by requiring more than just a password to log in.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF6B7280),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Enable 2FA',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      CupertinoSwitch(
                        value: is2faEnabled,
                        activeTrackColor: const Color(0xFF059669),
                        onChanged: (v) {
                          setState(() => is2faEnabled = v);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
