// lib/screens/edit_profile_view.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/services/api_client.dart';
import 'package:property_app/services/avatar_service.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/utils/api_result.dart';

const Color _primary = Color(0xFF3F37C9);
const Color _bgColor = Colors.white;

class EditProfileView extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSave;

  const EditProfileView({
    super.key,
    required this.onBack,
    required this.onSave,
  });

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView>
    with TickerProviderStateMixin {
  late final AnimationController _pageCtrl;
  late final AnimationController _staggerCtrl;

  late final Animation<Offset> _pageSlide;
  late final Animation<double> _pageFade;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  File? _selectedImage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Page Entrance Animation
    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _pageSlide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));
    _pageFade = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeIn);

    _nameController.text = AppSession.displayName;
    _emailController.text = AppSession.displayEmail;
    _phoneController.text = AppSession.displayPhone;

    // Staggered Content Animation
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pageCtrl.forward().then((_) => _staggerCtrl.forward());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _staggerCtrl.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Widget _buildAvatarWidget(String avatarPath) {
    return AppSession.buildAvatar(
      avatarPath,
      width: 120,
      height: 120,
      fit: BoxFit.cover,
    );
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  /// Helper to create a smooth staggered fade and upward slide for list items
  Widget _buildStaggered({required int index, required Widget child}) {
    final double start = (index * 0.1).clamp(0.0, 1.0);
    final double end = (start + 0.4).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _staggerCtrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _pageSlide,
      child: FadeTransition(
        opacity: _pageFade,
        child: Scaffold(
          backgroundColor: _bgColor,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 16,
                      bottom: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStaggered(index: 1, child: _buildAvatarSection()),
                        const SizedBox(height: 40),
                        _buildStaggered(
                          index: 2,
                          child: _buildField(
                            label: 'Full Name',
                            controller: _nameController,
                            keyboardType: TextInputType.name,
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildStaggered(
                          index: 3,
                          child: _buildField(
                            label: 'Phone Number',
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildStaggered(
                          index: 4,
                          child: _buildField(
                            label: 'Email Address',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Bottom Button placed below ScrollView to prevent truncating overlap
                _buildStaggered(
                  index: 5,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: _buildBottomBar(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return _buildStaggered(
      index: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Row(
          children: [
            GestureDetector(
              onTap: widget.onBack,
              behavior: HitTestBehavior.opaque,
              child:
                  const Icon(Icons.arrow_back, size: 28, color: Colors.black),
            ),
            const SizedBox(width: 16),
            const Text(
              'Edit Profile',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Avatar ─────────────────────────────────────────────────────────────────

  Widget _buildAvatarSection() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                // Avatar Image
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE5E7EB),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 20),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _selectedImage != null
                        ? Image.file(
                            _selectedImage!,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          )
                        : _buildAvatarWidget(
                            AppSession.displayAvatar,
                          ),
                  ),
                ),

                // Upload Badge matching the PDF
                Positioned(
                  bottom: 2,
                  right: 4,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981), // Solid Emerald Green
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.upload_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Change Photo Text
          GestureDetector(
            onTap: _pickImage,
            behavior: HitTestBehavior.opaque,
            child: const Text(
              'Change Photo',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Form Field ─────────────────────────────────────────────────────────────

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Bottom Bar ─────────────────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context) {
    return ElevatedButton(
      onPressed: _isSaving ? null : _handleSaveProfile,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: _isSaving
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2.5,
              ),
            )
          : const Text(
              'Save Changes',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }

  Future<void> _handleSaveProfile() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name and email are required.'),
          behavior: SnackBarBehavior.floating,
        ),
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

      // Sync the global AppSession with the new data from backend
      AppSession.updateCurrentUser(updatedUser);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onSave();
    } catch (err) {
      if (!mounted) return;
      final message = ApiResult.mapError(err);

      debugPrint('Profile update failed: $err');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
