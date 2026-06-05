import 'package:flutter/material.dart';
import 'package:property_app/app_theme.dart';

class SettingView extends StatelessWidget {
  final VoidCallback onBack;
  final void Function(String title)? onItemTap;
  final VoidCallback? onLogout;

  const SettingView({
    super.key,
    required this.onBack,
    this.onItemTap,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Icon(Icons.chevron_left_rounded,
                          color: Color(0xFF374151)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text('Settings',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827))),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  _SettingTile(
                    title: 'Notifications',
                    subtitle: 'Manage notification preferences',
                    onTap: () => onItemTap?.call('Notifications'),
                  ),
                  const SizedBox(height: 12),
                  _SettingTile(
                    title: 'Payment Methods',
                    subtitle: 'Add or remove payment options',
                    onTap: () => onItemTap?.call('Payment Methods'),
                  ),
                  const SizedBox(height: 12),
                  _SettingTile(
                    title: 'Privacy & Security',
                    subtitle: 'Manage your data and privacy settings',
                    onTap: () => onItemTap?.call('Privacy & Security'),
                  ),
                  const SizedBox(height: 12),
                  _SettingTile(
                    title: 'Help & Support',
                    subtitle: 'Contact support or view FAQs',
                    onTap: () => onItemTap?.call('Help & Support'),
                  ),
                  const SizedBox(height: 12),
                  _SettingTile(
                    title: 'About StayNest',
                    subtitle: 'Version, legal and open-source licenses',
                    onTap: () => onItemTap?.call('About StayNest'),
                  ),
                  const SizedBox(height: 24),
                  // Logout Button
                  if (onLogout != null)
                    GestureDetector(
                      onTap: onLogout,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEF4444)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded,
                                color: Color(0xFFEF4444), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Logout',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
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

class _SettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB))),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827))),
                  const SizedBox(height: 6),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}
