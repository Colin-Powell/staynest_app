import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/theme.dart';

class SuperAdminSettingsPage extends StatelessWidget {
  const SuperAdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Platform settings',
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray900)),
          const SizedBox(height: 8),
          Text(
              'Adjust moderation defaults, feature toggles, and operational policies.',
              style:
                  GoogleFonts.poppins(fontSize: 13, color: AppColors.gray500)),
          const SizedBox(height: 16),
          _SettingTile(
              title: 'Enable auto-approval for verified landlords',
              icon: PhosphorIcons.toggleRight(PhosphorIconsStyle.fill)),
          _SettingTile(
              title: 'Require manual review for high-value properties',
              icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill)),
          _SettingTile(
              title: 'Send weekly compliance digest',
              icon: PhosphorIcons.envelope(PhosphorIconsStyle.fill)),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SettingTile({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: StayNestColors.outlineLight)),
      child: Row(
        children: [
          CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Icon(icon, color: AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray900))),
          Switch(value: true, onChanged: (_) {}),
        ],
      ),
    );
  }
}
