import 'package:flutter/material.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/session/app_session.dart';

/// Displays the user's avatar using Cloudinary URLs derived from the API's
/// `users.avatar` field.
///
/// - If [userId] matches the currently authenticated user, we use
///   [AppSession.currentUserAvatar] directly.
/// - Otherwise we fetch the user by id and use their `avatar` value.
class ProfileAvatar extends StatefulWidget {
  final String? userId;
  final double size;
  final BoxFit fit;
  final bool circular;

  const ProfileAvatar({
    super.key,
    required this.userId,
    required this.size,
    this.fit = BoxFit.cover,
    this.circular = true,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  String? _avatarPath;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _avatarPath = _initialAvatar();

    if (_avatarPath == null || _avatarPath!.trim().isEmpty) {
      _loadIfNeeded();
    }
  }

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _avatarPath = _initialAvatar();
      if (_avatarPath == null || _avatarPath!.trim().isEmpty) {
        _loadIfNeeded();
      }
    }
  }

  String? _initialAvatar() {
    final uid = widget.userId?.trim();
    if (uid == null || uid.isEmpty) return null;

    final currentId = AppSession.currentUserId;
    if (currentId != null && currentId.trim() == uid) {
      return AppSession.currentUserAvatar;
    }

    // If userId is unknown, we can't infer avatar. Load from API.
    return null;
  }

  Future<void> _loadIfNeeded() async {
    final uid = widget.userId?.trim();
    if (uid == null || uid.isEmpty) return;

    // If it's current user, we already have it.
    final currentId = AppSession.currentUserId;
    if (currentId != null && currentId.trim() == uid) return;

    if (_loading) return;

    setState(() => _loading = true);
    try {
      final repo = RemoteDatabaseRepository();
      final user = await repo.loadUserById(uid);
      if (!mounted) return;
      setState(() {
        _avatarPath = user['avatar']?.toString();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final radius = widget.circular ? size / 2 : 12.0;

    final avatar = _avatarPath?.trim().isNotEmpty == true
        ? _avatarPath
        : AppSession.displayAvatar;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _loading
          ? Container(
              key: const ValueKey('loading'),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(radius),
              ),
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : ClipRRect(
              key: const ValueKey('avatar'),
              borderRadius: BorderRadius.circular(radius),
              child: AppSession.buildAvatar(
                avatar,
                width: size,
                height: size,
                fit: widget.fit,
              ),
            ),
    );
  }
}
