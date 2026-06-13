// lib/screens/dashboard/landlord_settings_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';

import 'package:image_picker/image_picker.dart';

import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/user_service.dart';
import 'package:property_app/services/avatar_service.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/screens/home/how_it_works_view.dart';
import 'package:property_app/widgets/property_image.dart';
import 'landlord_analytics_page.dart';

// --- MAIN SETTINGS PAGE ---

class LandlordSettingsPage extends StatelessWidget {
  const LandlordSettingsPage({super.key});
  static const Color textDark = Color(0xFF111827);
  static const Color textLight = Color(0xFF9CA3AF);
  static const Color primaryGreen = Color(0xFF059669);

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
    final user = AppSession.currentUser;
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
              const SizedBox(height: 32),

              // --- PROFILE GLASS CARD ---
              _GlassContainer(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: AppSession.buildAvatar(
                          AppSession.displayAvatar,
                          width: 64,
                          height: 64,
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
                            AppSession.displayName,
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
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_rounded, color: primaryGreen, size: 20),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // --- BUSINESS & PERFORMANCE ---
              Text(
                'Business & Performance',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: primaryGreen,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _GlassContainer(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildSettingRow(
                      title: 'Performance & Insights',
                      icon: PhosphorIcons.chartLineUp(PhosphorIconsStyle.fill),
                      onTap: () => _navigateTo(context, const LandlordAnalyticsPage()),
                    ),
                    _buildDivider(),
                    _buildSettingRow(
                      title: 'Business Information',
                      icon: PhosphorIcons.buildings(PhosphorIconsStyle.fill),
                      onTap: () => _navigateTo(context, const BusinessInfoPage()),
                    ),
                    _buildDivider(),
                    _buildSettingRow(
                      title: 'Bank Details',
                      icon: PhosphorIcons.creditCard(PhosphorIconsStyle.fill),
                      onTap: () => _navigateTo(context, const BankDetailsPage()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // --- ACCOUNT & SECURITY ---
              Text(
                'Account & Security',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: primaryGreen,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _GlassContainer(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildSettingRow(
                      title: 'Personal Information',
                      icon: PhosphorIcons.user(PhosphorIconsStyle.fill),
                      onTap: () => _navigateTo(context, const PersonalInfoPage()),
                    ),
                    _buildDivider(),
                    _buildSettingRow(
                      title: 'Notification Settings',
                      icon: PhosphorIcons.bell(PhosphorIconsStyle.fill),
                      onTap: () => _navigateTo(context, const NotificationSettingsPage()),
                    ),
                    _buildDivider(),
                    _buildSettingRow(
                      title: 'Change Password',
                      icon: PhosphorIcons.lockKey(PhosphorIconsStyle.fill),
                      onTap: () => _navigateTo(context, const ChangePasswordPage()),
                    ),
                    _buildDivider(),
                    _buildSettingRow(
                      title: 'Two-Factor Authentication',
                      icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                      trailingText: (user['settings']?['two_factor'] ?? false) ? 'On' : 'Off',
                      onTap: () => _navigateTo(context, const TwoFactorAuthPage()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // --- ABOUT & SUPPORT ---
              Text(
                'About',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: primaryGreen,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _GlassContainer(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildSettingRow(
                      title: 'Help & Support',
                      icon: PhosphorIcons.question(PhosphorIconsStyle.fill),
                      onTap: () => _navigateTo(
                        context,
                        const HowItWorksView(
                          title: 'Landlord Support',
                          subtitle: 'Managing your properties and tenants on StayNest.',
                          details: 'Find comprehensive guides on optimizing your listings, managing booking requests, and tracking your business performance analytics.',
                        )
                      ),
                    ),
                    _buildDivider(),
                    _buildSettingRow(
                      title: 'Privacy Policy',
                      icon: PhosphorIcons.fileLock(PhosphorIconsStyle.fill),
                      onTap: () => _navigateTo(context, const PrivacyPolicyPage()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // --- LOGOUT BUTTON ---
              GestureDetector(
                onTap: () {
                  AppSession.logout();
                  Navigator.of(context, rootNavigator: true)
                      .pushNamedAndRemoveUntil('/login', (route) => false);
                },
                behavior: HitTestBehavior.opaque,
                child: _GlassContainer(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(PhosphorIcons.signOut(), color: const Color(0xFFEF4444), size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Logout',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
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

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withOpacity(0.6),
      indent: 64, // Aligns with text start
      endIndent: 20,
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
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: primaryGreen, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: textDark,
                ),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: textLight.withOpacity(0.6),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// --- SHARED SUBPAGE LAYOUT ---
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
      extendBody: true, // Let content flow under bottom nav glass
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
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
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

// Shared UI helper for Glass Input Fields
Widget _buildTextField(String label,
    {String? hintText,
    bool isPassword = false,
    IconData? prefixIcon,
    TextEditingController? controller}) {
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
          controller: controller,
          obscureText: isPassword,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.poppins(
                color: const Color(0xFF9CA3AF), fontSize: 15),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: const Color(0xFF9CA3AF), size: 22)
                : null,
            filled: true,
            fillColor: Colors.white.withOpacity(0.55), // Glassy fill
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF059669), width: 2),
            ),
          ),
        ),
      ],
    ),
  );
}

// Shared UI helper for Save Buttons (Glass Bottom Bar)
Widget _buildSaveButton(BuildContext context,
    {String text = "Save Changes", VoidCallback? onPressed}) {
  return ClipRRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.55),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.5)),
        ),
        child: ElevatedButton(
          onPressed: onPressed ?? () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size(double.infinity, 56),
          ),
          child: onPressed == null && text != "Save Changes" && text != "Update Password" && text != "Save Bank Details"
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  text,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    ),
  );
}

// --- 1. PERSONAL INFORMATION PAGE ---
class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  File? _selectedImage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: AppSession.displayName);
    _emailController = TextEditingController(text: AppSession.displayEmail);
    _phoneController = TextEditingController(text: AppSession.displayPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image == null) return;
      setState(() => _selectedImage = File(image.path));
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and email are required.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      String? avatarPublicId;
      if (_selectedImage != null) {
        avatarPublicId = await AvatarService.uploadAvatar(_selectedImage!);
      }

      final repository = RemoteDatabaseRepository();
      final updatedUser = await repository.updateCurrentUser(update: {
        'name': name,
        'email': email,
        'phone': phone,
        if (avatarPublicId != null) 'avatar': avatarPublicId,
      });

      AppSession.updateCurrentUser(updatedUser);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.pop(context);
    } catch (err) {
      if (!mounted) return;
      debugPrint('Profile update failed: $err');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildAvatar() {
    if (_selectedImage != null) {
      return Image.file(
        _selectedImage!,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
      );
    }
    return AppSession.buildAvatar(
      AppSession.displayAvatar,
      width: 100,
      height: 100,
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageLayout(
      title: 'Personal Info',
      bottomNavigationBar: _buildSaveButton(
        context,
        onPressed: _isSaving ? null : _handleSave,
        text: _isSaving ? "Saving..." : "Save Changes",
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: ClipOval(child: _buildAvatar()),
                  ),
                ),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            _buildTextField('Full Name', controller: _nameController),
            _buildTextField('Email Address',
                controller: _emailController,
                prefixIcon: PhosphorIcons.envelopeSimple()),
            _buildTextField('Phone Number',
                controller: _phoneController,
                prefixIcon: PhosphorIcons.phone()),
            const SizedBox(height: 40), // Extra space for bottom nav
          ],
        ),
      ),
    );
  }
}

// --- 2. BUSINESS INFORMATION PAGE ---
class BusinessInfoPage extends StatefulWidget {
  const BusinessInfoPage({super.key});

  @override
  State<BusinessInfoPage> createState() => _BusinessInfoPageState();
}

class _BusinessInfoPageState extends State<BusinessInfoPage> {
  late TextEditingController _companyController;
  late TextEditingController _regNumberController;
  late TextEditingController _addressController;
  late TextEditingController _tinController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = AppSession.currentUser;
    final business = (user['businessInfo'] as Map?) ?? {};
    _companyController =
        TextEditingController(text: business['companyName']?.toString() ?? '');
    _regNumberController = TextEditingController(
        text: business['registrationNumber']?.toString() ?? '');
    _addressController =
        TextEditingController(text: business['address']?.toString() ?? '');
    _tinController =
        TextEditingController(text: business['tin']?.toString() ?? '');
  }

  @override
  void dispose() {
    _companyController.dispose();
    _regNumberController.dispose();
    _addressController.dispose();
    _tinController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final repository = RemoteDatabaseRepository();
      final updatedUser = await repository.updateCurrentUser(update: {
        'businessInfo': {
          'companyName': _companyController.text.trim(),
          'registrationNumber': _regNumberController.text.trim(),
          'address': _addressController.text.trim(),
          'tin': _tinController.text.trim(),
        },
      });

      AppSession.updateCurrentUser(updatedUser);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business info updated successfully')),
      );
      Navigator.pop(context);
    } catch (err) {
      if (!mounted) return;
      debugPrint('Business info update failed: $err');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update business info')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageLayout(
      title: 'Business Info',
      bottomNavigationBar: _buildSaveButton(
        context,
        onPressed: _isSaving ? null : _handleSave,
        text: _isSaving ? "Saving..." : "Save Changes",
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          children: [
            _buildTextField('Company / Agency Name',
                controller: _companyController,
                hintText: 'StayNest Properties LLC',
                prefixIcon: PhosphorIcons.buildings()),
            _buildTextField('Business Registration Number',
                controller: _regNumberController, hintText: 'RC-123456789'),
            _buildTextField('Business Address',
                controller: _addressController,
                hintText: '123 Real Estate Ave, Suite 100',
                prefixIcon: PhosphorIcons.mapPin()),
            _buildTextField('Tax Identification Number (TIN)',
                controller: _tinController, hintText: 'XXX-XX-XXXX'),
            const SizedBox(height: 40),
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
          const SizedBox(height: 16),
          _buildSectionHeader('Push Notifications'),
          _buildSwitchTile('New Bookings', 'Push alerts for new bookings',
              pushNewBooking, (v) => setState(() => pushNewBooking = v)),
          _buildSwitchTile('New Messages', 'Push alerts for new messages',
              pushMessages, (v) => setState(() => pushMessages = v)),
          const SizedBox(height: 16),
          _buildSectionHeader('SMS Notifications'),
          _buildSwitchTile(
              'Critical Alerts',
              'Important account or booking updates via SMS',
              smsAlerts,
              (v) => setState(() => smsAlerts = v)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _GlassContainer(
        padding: const EdgeInsets.all(16),
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
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          children: [
            _GlassContainer(
              padding: const EdgeInsets.all(16),
              opacity: 0.8,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(PhosphorIcons.info(PhosphorIconsStyle.fill), color: const Color(0xFF059669), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'These details will be used to process your rental payouts.',
                      style: GoogleFonts.poppins(
                          fontSize: 13.5, fontWeight: FontWeight.w500, color: const Color(0xFF374151)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildTextField('Bank Name',
                hintText: 'e.g. Chase Bank', prefixIcon: PhosphorIcons.bank()),
            _buildTextField('Account Holder Name',
                hintText: 'Jomison Real Estate'),
            _buildTextField('Account Number', hintText: '1234567890'),
            _buildTextField('Routing Number', hintText: '098765432'),
            const SizedBox(height: 40),
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
        child: _GlassContainer(
          padding: const EdgeInsets.all(24),
          opacity: 0.85,
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
                    fontSize: 14.5, color: const Color(0xFF4B5563), height: 1.6, fontWeight: FontWeight.w500),
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
                    fontSize: 14.5, color: const Color(0xFF4B5563), height: 1.6, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 32),
              Text(
                'Last updated: October 2024',
                style: GoogleFonts.poppins(
                    fontSize: 13,
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
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isUpdating = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    if (_newController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _isUpdating = true);
    final res = await UserService.changePassword(
        _currentController.text, _newController.text);

    if (mounted) {
      setState(() => _isUpdating = false);
      if (res['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'] ?? 'Failed to update password')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageLayout(
      title: 'Change Password',
      bottomNavigationBar: _buildSaveButton(
        context,
        text: _isUpdating ? "Updating..." : "Update Password",
        onPressed: _isUpdating ? null : _handleUpdate,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          children: [
            _buildTextField('Current Password',
                controller: _currentController,
                isPassword: true,
                prefixIcon: PhosphorIcons.lock()),
            const SizedBox(height: 8),
            _buildTextField('New Password',
                controller: _newController,
                isPassword: true,
                prefixIcon: PhosphorIcons.lockKey()),
            _buildTextField('Confirm New Password',
                controller: _confirmController,
                isPassword: true,
                prefixIcon: PhosphorIcons.lockKey()),
            const SizedBox(height: 40),
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
  late bool is2faEnabled;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = AppSession.currentUser;
    is2faEnabled = (user['settings']?['two_factor'] ?? false) == true;
  }

  Future<void> _handleToggle(bool value) async {
    setState(() {
      is2faEnabled = value;
      _isSaving = true;
    });

    try {
      final repository = RemoteDatabaseRepository();
      final updatedUser = await repository.updateCurrentUser(update: {
        'settings': {
          'two_factor': value,
        },
      });
      AppSession.updateCurrentUser(updatedUser);
    } catch (err) {
      debugPrint('2FA update failed: $err');
      if (mounted) {
        setState(() => is2faEnabled = !value); // revert on failure
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update 2FA setting')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageLayout(
      title: 'Two-Factor Auth',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GlassContainer(
              padding: const EdgeInsets.all(24),
              opacity: 0.8,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: is2faEnabled ? const Color(0xFF059669).withOpacity(0.15) : const Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                      size: 56,
                      color: is2faEnabled
                          ? const Color(0xFF059669)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    is2faEnabled
                        ? '2FA is currently Enabled'
                        : '2FA is currently Disabled',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Two-factor authentication adds an extra layer of security to your account by requiring more than just a password to log in.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4B5563),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Enable 2FA',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF059669)),
                              )
                            : CupertinoSwitch(
                                value: is2faEnabled,
                                activeTrackColor: const Color(0xFF059669),
                                onChanged: _handleToggle,
                              ),
                      ],
                    ),
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

// ─── Glassmorphism Core Utility ──────────────────────────────────────────────
class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final double blur;
  final double opacity;
  final double borderWidth;

  const _GlassContainer({
    required this.child,
    required this.padding,
    this.borderRadius,
    this.blur = 20.0,
    this.opacity = 0.55,
    this.borderWidth = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(24);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withOpacity(0.8),
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}