import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/user_service.dart';
import 'package:property_app/services/avatar_service.dart';
import 'package:property_app/services/landlord_payment_methods_service.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/screens/help_support_view.dart';
import 'package:property_app/utils/api_result.dart';
import 'landlord_analytics_page.dart';

// ─── Landlord Design System Constants ─────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981); // Emerald Green for Landlord Theme

// --- MAIN SETTINGS PAGE ---

class LandlordSettingsPage extends StatelessWidget {
  const LandlordSettingsPage({super.key});

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
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 130),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              Row(
                children: [
                  const Icon(PhosphorIconsRegular.caretLeft,
                      color: _dark, size: 28), // Or hide if it's a main tab
                  const SizedBox(width: 16),
                  Text(
                    'Settings',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // --- PROFILE CARD ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                  border: Border.all(color: _grey.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _grey.withOpacity(0.1)),
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
                              color: _dark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'View and edit your profile',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(PhosphorIconsRegular.pencilSimple,
                          color: _green, size: 20),
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
                  color: _grey,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              _buildSettingsBlock([
                _buildSettingRow(
                  title: 'Performance & Insights',
                  icon: PhosphorIconsRegular.trendUp,
                  onTap: () =>
                      _navigateTo(context, const LandlordAnalyticsPage()),
                ),
                _buildDivider(),
                _buildSettingRow(
                  title: 'Business Information',
                  icon: PhosphorIconsRegular.buildings,
                  onTap: () => _navigateTo(context, const BusinessInfoPage()),
                ),
                _buildDivider(),
                _buildSettingRow(
                  title: 'Payment Details',
                  icon: PhosphorIconsRegular.wallet,
                  onTap: () => _navigateTo(context, const PaymentDetailsPage()),
                ),
              ]),
              const SizedBox(height: 32),

              // --- ACCOUNT & SECURITY ---
              Text(
                'Account & Security',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _grey,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              _buildSettingsBlock([
                _buildSettingRow(
                  title: 'Personal Information',
                  icon: PhosphorIconsRegular.user,
                  onTap: () => _navigateTo(context, const PersonalInfoPage()),
                ),
                _buildDivider(),
                _buildSettingRow(
                  title: 'Notification Settings',
                  icon: PhosphorIconsRegular.bell,
                  onTap: () =>
                      _navigateTo(context, const NotificationSettingsPage()),
                ),
                _buildDivider(),
                _buildSettingRow(
                  title: 'Change Password',
                  icon: PhosphorIconsRegular.lockKey,
                  onTap: () => _navigateTo(context, const ChangePasswordPage()),
                ),
                _buildDivider(),
                _buildSettingRow(
                  title: 'Two-Factor Authentication',
                  icon: PhosphorIconsRegular.shieldCheck,
                  trailingText:
                      (user['settings']?['two_factor'] ?? false) ? 'On' : 'Off',
                  onTap: () => _navigateTo(context, const TwoFactorAuthPage()),
                ),
              ]),
              const SizedBox(height: 32),

              // --- ABOUT & SUPPORT ---
              Text(
                'About',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _grey,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              _buildSettingsBlock([
                _buildSettingRow(
                  title: 'Help & Support',
                  icon: PhosphorIconsRegular.question,
                  onTap: () => _navigateTo(context,
                      HelpSupportView(onBack: () => Navigator.pop(context))),
                ),
                _buildDivider(),
                _buildSettingRow(
                  title: 'Privacy Policy',
                  icon: PhosphorIconsRegular.fileText,
                  onTap: () => _navigateTo(context, const PrivacyPolicyPage()),
                ),
                _buildDivider(),
                _buildSettingRow(
                  title: 'App Version',
                  icon: PhosphorIconsRegular.info,
                  trailingText: 'v${AppSession.currentAppVersion}',
                  onTap: () {},
                ),
              ]),
              const SizedBox(height: 32),

              // --- LOGOUT BUTTON ---
              GestureDetector(
                onTap: () {
                  AppSession.logout();
                  Navigator.of(context, rootNavigator: true)
                      .pushNamedAndRemoveUntil('/login', (route) => false);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                    border: Border.all(
                        color: const Color(0xFFFCA5A5)
                            .withOpacity(0.3)), // Subtle red border
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(PhosphorIconsRegular.signOut,
                          color: Color(0xFFEF4444), size: 24),
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

  Widget _buildSettingsBlock(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: _grey.withOpacity(0.1)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: _grey.withOpacity(0.1),
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _green, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _dark,
                ),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _green,
                ),
              ),
              const SizedBox(width: 12),
            ],
            const Icon(
              PhosphorIconsRegular.caretRight,
              color: _grey,
              size: 20,
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
      backgroundColor: _bg,
      extendBody: true,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
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
                    child: const Icon(PhosphorIconsRegular.caretLeft,
                        color: _dark, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: _dark,
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
    );
  }
}

// Shared UI helper for Input Fields
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
            color: _dark,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w500, color: _dark),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.poppins(
                color: _grey, fontSize: 14, fontWeight: FontWeight.w400),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: _grey, size: 22)
                : null,
            filled: true,
            fillColor: _surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _grey.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _grey.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _green, width: 1.5),
            ),
          ),
        ),
      ],
    ),
  );
}

// Shared UI helper for Save Buttons
Widget _buildSaveButton(BuildContext context,
    {String text = "Save Changes", VoidCallback? onPressed}) {
  return Container(
    padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
    decoration: BoxDecoration(
      color: _surface,
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, -4)),
      ],
    ),
    child: ElevatedButton(
      onPressed: onPressed ?? () => Navigator.pop(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: _green,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32)), // Pill shape
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 56),
      ),
      child: onPressed == null &&
              text != "Save Changes" &&
              text != "Update Password" &&
              text != "Save Bank Details"
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
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
    _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    try {
      if (AppSession.apiToken != null && AppSession.currentUserId != null) {
        final user = await RemoteDatabaseRepository().loadCurrentUser();
        AppSession.updateCurrentUser(user);
        await AppSession.persistSession();
      }
    } catch (_) {}

    if (!mounted) return;
    _nameController.text = AppSession.displayName;
    _emailController.text = AppSession.displayEmail;
    _phoneController.text = AppSession.displayPhone;
    setState(() {});
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
      final image =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
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
          const SnackBar(content: Text('Name and email are required.')));
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
      await AppSession.persistSession();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')));
      Navigator.pop(context);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ApiResult.mapError(err))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildAvatar() {
    if (_selectedImage != null) {
      return Image.file(_selectedImage!,
          width: 110, height: 110, fit: BoxFit.cover);
    }
    return AppSession.buildAvatar(AppSession.displayAvatar,
        width: 110, height: 110, fit: BoxFit.cover);
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
                      border:
                          Border.all(color: _grey.withOpacity(0.2), width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 5))
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
                      color: _green,
                      shape: BoxShape.circle,
                      border: Border.all(color: _surface, width: 3),
                    ),
                    child: const Icon(PhosphorIconsRegular.camera,
                        color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            _buildTextField('Full Name',
                controller: _nameController,
                prefixIcon: PhosphorIconsRegular.user),
            _buildTextField('Email Address',
                controller: _emailController,
                prefixIcon: PhosphorIconsRegular.envelopeSimple),
            _buildTextField('Phone Number',
                controller: _phoneController,
                prefixIcon: PhosphorIconsRegular.phone),
            const SizedBox(height: 40),
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
    final business = (user['businessInfo'] as Map?) ?? user;
    _companyController = TextEditingController(
        text:
            (business['companyName'] ?? business['businessName'])?.toString() ??
                '');
    _regNumberController = TextEditingController(
        text: business['registrationNumber']?.toString() ?? '');
    _addressController =
        TextEditingController(text: business['address']?.toString() ?? '');
    _tinController = TextEditingController(
        text: (business['tin'] ?? business['taxId'])?.toString() ?? '');
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
        'businessName': _companyController.text.trim(),
        'businessDescription': _addressController.text.trim(),
        'taxId': _tinController.text.trim(),
      });

      AppSession.updateCurrentUser(updatedUser);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business info updated successfully')));
      Navigator.pop(context);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ApiResult.mapError(err))));
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
                prefixIcon: PhosphorIconsRegular.buildings),
            _buildTextField('Business Registration Number',
                controller: _regNumberController,
                hintText: 'RC-123456789',
                prefixIcon: PhosphorIconsRegular.fileText),
            _buildTextField('Business Address',
                controller: _addressController,
                hintText: '123 Real Estate Ave',
                prefixIcon: PhosphorIconsRegular.mapPin),
            _buildTextField('Tax Identification Number (TIN)',
                controller: _tinController,
                hintText: 'XXX-XX-XXXX',
                prefixIcon: PhosphorIconsRegular.receipt),
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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = AppSession.currentUser;
    final notifs = user['settings']?['notifications'] ?? {};
    emailNewBooking = notifs['email_new_booking'] ?? true;
    emailMessages = notifs['email_messages'] ?? true;
    pushNewBooking = notifs['push_new_booking'] ?? true;
    pushMessages = notifs['push_messages'] ?? false;
    smsAlerts = notifs['sms_alerts'] ?? false;
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final repo = RemoteDatabaseRepository();
      final updated = await repo.updateCurrentUser(update: {
        'settings': {
          ...(AppSession.currentUser['settings'] ?? {}),
          'notifications': {
            'email_new_booking': emailNewBooking,
            'email_messages': emailMessages,
            'push_new_booking': pushNewBooking,
            'push_messages': pushMessages,
            'sms_alerts': smsAlerts,
          }
        }
      });
      AppSession.updateCurrentUser(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification settings updated')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiResult.mapError(e))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageLayout(
      title: 'Notifications',
      bottomNavigationBar: _buildSaveButton(
        context,
        text: _isSaving ? "Saving..." : "Save Settings",
        onPressed: _isSaving ? null : _handleSave,
      ),
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
          color: _dark,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
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
                      fontSize: 15, fontWeight: FontWeight.w600, color: _dark),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(fontSize: 13, color: _grey),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: _green,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// --- 4. PAYMENT DETAILS PAGE ---
class PaymentDetailsPage extends StatefulWidget {
  const PaymentDetailsPage({super.key});

  @override
  State<PaymentDetailsPage> createState() => _PaymentDetailsPageState();
}

class _PaymentDetailsPageState extends State<PaymentDetailsPage> {
  List<LandlordPaymentMethod> _methods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    setState(() => _isLoading = true);
    final methods = await LandlordPaymentMethodsService.getPaymentMethods();
    if (!mounted) return;
    setState(() {
      _methods = methods.where((method) => method.type == 'mpesa').toList();
      _isLoading = false;
    });
  }

  Future<void> _setDefault(LandlordPaymentMethod method) async {
    try {
      await LandlordPaymentMethodsService.setDefault(method.id);
      await _loadMethods();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiResult.mapError(e))),
      );
    }
  }

  Future<void> _removeMethod(LandlordPaymentMethod method) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove payment method?'),
        content: Text(
            'Remove ${method.typeLabel} ending in ${method.maskedAccount}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await LandlordPaymentMethodsService.deleteMethod(method.id);
      await _loadMethods();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiResult.mapError(e))),
      );
    }
  }

  Future<void> _showAddMpesaSheet() async {
    final phoneController =
        TextEditingController(text: AppSession.displayPhone);
    final formKey = GlobalKey<FormState>();
    final phone = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Add M-Pesa Number',
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700, color: _dark)),
            const SizedBox(height: 16),
            Form(
              key: formKey,
              child: TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter your M-Pesa phone number';
                  }
                  if (!LandlordPaymentMethodsService.isValidMpesaPhone(value)) {
                    return 'Use 07..., 01..., or +254... format';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+254712345678',
                  prefixIcon: const Icon(PhosphorIconsRegular.phone),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () {
                  final value = phoneController.text.trim();
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.pop(
                      sheetContext,
                      LandlordPaymentMethodsService.normalizeMpesaPhone(value),
                    );
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Add M-Pesa Number'),
              ),
            ),
          ],
        ),
      ),
    );
    phoneController.dispose();
    if (phone == null || !mounted) return;

    try {
      await LandlordPaymentMethodsService.addMpesaMethod(
        phone: phone,
        isDefault: _methods.isEmpty,
      );
      await _loadMethods();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiResult.mapError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageLayout(
      title: 'Payment Details',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : RefreshIndicator(
              onRefresh: _loadMethods,
              color: _green,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _green.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(PhosphorIconsRegular.info,
                            color: _green, size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Use a saved M-Pesa number to pay for listing boosts.',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _dark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_methods.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text('No M-Pesa payment methods yet.',
                            style: GoogleFonts.poppins(color: _grey)),
                      ),
                    )
                  else
                    ..._methods.map(_buildMethodCard),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _showAddMpesaSheet,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add M-Pesa Number'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _green,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMethodCard(LandlordPaymentMethod method) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _green, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('M-PESA',
                  style: GoogleFonts.poppins(
                      color: _green,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'default') _setDefault(method);
                  if (value == 'remove') _removeMethod(method);
                },
                itemBuilder: (_) => [
                  if (!method.isDefault)
                    const PopupMenuItem(
                        value: 'default', child: Text('Set as Default')),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(method.maskedAccount,
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700, color: _grey)),
              if (method.isDefault)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                      color: _green, borderRadius: BorderRadius.circular(20)),
                  child: const Text('Default',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
            ],
          ),
        ],
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
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _grey.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Data Collection & Usage',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
              const SizedBox(height: 12),
              Text(
                'We collect information to provide better services to all our users. Information collected includes your name, email address, phone number, and properties managed.\n\nYour data is securely stored and never shared with third parties without your explicit consent.',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: _grey,
                    height: 1.6,
                    fontWeight: FontWeight.w400),
              ),
              const SizedBox(height: 32),
              Text('Your Rights',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
              const SizedBox(height: 12),
              Text(
                'You have the right to request access to the data we hold about you. You can also request deletion of your account and associated data at any time from the account settings.',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: _grey,
                    height: 1.6,
                    fontWeight: FontWeight.w400),
              ),
              const SizedBox(height: 32),
              Divider(color: _grey.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text('Last updated: October 2024',
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontStyle: FontStyle.italic, color: _grey)),
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
          const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() => _isUpdating = true);
    final res = await UserService.changePassword(
        _currentController.text, _newController.text);

    if (mounted) {
      setState(() => _isUpdating = false);
      if (res['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password updated successfully')));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text((res['error'] != null)
                  ? ApiResult.mapError(res['error'])
                  : (res['error'] ?? 'Failed to update password'))),
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
                prefixIcon: PhosphorIconsRegular.lock),
            const SizedBox(height: 8),
            _buildTextField('New Password',
                controller: _newController,
                isPassword: true,
                prefixIcon: PhosphorIconsRegular.lockKey),
            _buildTextField('Confirm New Password',
                controller: _confirmController,
                isPassword: true,
                prefixIcon: PhosphorIconsRegular.lockKey),
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
      if (mounted) {
        final message = ApiResult.mapError(err);
        setState(() => is2faEnabled = !value); // revert on failure
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
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
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _grey.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: is2faEnabled
                          ? _green.withOpacity(0.1)
                          : _grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PhosphorIconsFill.shieldCheck,
                      size: 56,
                      color: is2faEnabled ? _green : _grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    is2faEnabled
                        ? '2FA is currently Enabled'
                        : '2FA is currently Disabled',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _dark),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Two-factor authentication adds an extra layer of security to your account by requiring more than just a password to log in.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: _grey, height: 1.6),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Enable 2FA',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _dark)),
                        _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: _green))
                            : CupertinoSwitch(
                                value: is2faEnabled,
                                activeTrackColor: _green,
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
