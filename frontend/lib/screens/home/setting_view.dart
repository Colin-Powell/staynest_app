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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  _SettingTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Manage notification preferences',
                    onTap: () {
                      onItemTap?.call('Notifications');
                      Navigator.pushNamed(context, '/notification_settings');
                    },
                  ),
                  const SizedBox(height: 12),
                  _SettingTile(
                    icon: Icons.credit_card_outlined,
                    title: 'Payment Methods',
                    subtitle: 'Add or remove payment options',
                    onTap: () {
                      onItemTap?.call('Payment Methods');
                      Navigator.pushNamed(context, '/payment_methods');
                    },
                  ),
                  const SizedBox(height: 12),
                  _SettingTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Privacy & Security',
                    subtitle: 'Manage your data and privacy settings',
                    onTap: () {
                      onItemTap?.call('Privacy & Security');
                      Navigator.pushNamed(context, '/privacy');
                    },
                  ),
                  const SizedBox(height: 12),
                  _SettingTile(
                    icon: Icons.headset_mic_outlined,
                    title: 'Help & Support',
                    subtitle: 'Contact support or view FAQs',
                    onTap: () {
                      onItemTap?.call('Help & Support');
                      Navigator.pushNamed(context, '/help_support');
                    },
                  ),
                  const SizedBox(height: 12),
                  _SettingTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About StayNest',
                    subtitle: 'Version 1.0.0 — Legal & licenses',
                    onTap: () => _showAboutSheet(context),
                  ),
                  const SizedBox(height: 32),
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
                            Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                            SizedBox(width: 8),
                            Text('Logout',
                                style: TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16)),
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

  void _showAboutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('About StayNest',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
            const SizedBox(height: 20),
            const _AboutRow(label: 'Version', value: '1.0.0'),
            const Divider(height: 24, color: Color(0xFFE5E7EB)),
            const _AboutRow(label: 'Developer', value: 'StayNest Team'),
            const Divider(height: 24, color: Color(0xFFE5E7EB)),
            const _AboutRow(label: 'Contact', value: 'support@staynest.top'),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/privacy');
              },
              child: const Text('Privacy Policy & Terms',
                  style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  const _AboutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500, fontSize: 14)),
        Text(value, style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w700, fontSize: 14)),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingTile({required this.icon, required this.title, required this.subtitle, this.onTap});

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
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF374151), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
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
