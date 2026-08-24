import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/services/super_admin_service.dart';
import 'package:property_app/theme.dart';
import 'package:property_app/utils/responsive_layout.dart';

class SuperAdminSettingsPage extends StatefulWidget {
  const SuperAdminSettingsPage({super.key});

  @override
  State<SuperAdminSettingsPage> createState() => _SuperAdminSettingsPageState();
}

class _SuperAdminSettingsPageState extends State<SuperAdminSettingsPage> {
  bool _loading = true;
  bool _saving = false;
  
  // General
  bool _requireManualKyc = true;
  bool _autoApproveListings = false;
  String _globalFee = '10%';
  String _defaultCurrency = 'KES';
  
  // Security
  bool _enforce2FA = true;
  bool _maintenanceMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final settings = await SuperAdminService.fetchSettings();
      if (mounted) {
        setState(() {
          if (settings['general'] != null) {
            _requireManualKyc = settings['general']['requireManualKyc'] ?? true;
            _autoApproveListings = settings['general']['autoApproveListings'] ?? false;
            _globalFee = '${settings['general']['globalFee'] ?? 10}%';
            _defaultCurrency = settings['general']['defaultCurrency'] ?? 'KES';
          }
          if (settings['security'] != null) {
            _enforce2FA = settings['security']['enforce2FA'] ?? true;
            _maintenanceMode = settings['security']['maintenanceMode'] ?? false;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
  
  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      await SuperAdminService.updateSetting('general', {
        'requireManualKyc': _requireManualKyc,
        'autoApproveListings': _autoApproveListings,
        'globalFee': int.tryParse(_globalFee.replaceAll('%', '')) ?? 10,
        'defaultCurrency': _defaultCurrency,
      });
      await SuperAdminService.updateSetting('security', {
        'enforce2FA': _enforce2FA,
        'maintenanceMode': _maintenanceMode,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved successfully.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktopOrLarger(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Platform Settings',
                    style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gray900,
                        letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text(
                    'Manage system configurations, moderation thresholds, and security policies.',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.gray500)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _saving ? null : _saveSettings,
              icon: _saving 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(PhosphorIcons.floppyDisk(), size: 18),
              label: const Text('Save Changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gray900,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            )
          ],
        ),
        const SizedBox(height: 32),
        
        if (isDesktop)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildGeneralSettings()),
                const SizedBox(width: 24),
                Expanded(child: Column(
                  children: [
                    _buildSecuritySettings(),
                    const SizedBox(height: 24),
                    _buildDangerZone(),
                  ],
                )),
              ],
            ),
          )
        else
          Column(
            children: [
              _buildGeneralSettings(),
              const SizedBox(height: 24),
              _buildSecuritySettings(),
              const SizedBox(height: 24),
              _buildDangerZone(),
            ],
          )
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: content,
    );
  }

  Widget _buildGeneralSettings() {
    return _SettingsSection(
      title: 'General & Moderation',
      icon: PhosphorIcons.slidersHorizontal(),
      children: [
        _SettingsToggle(
          title: 'Require manual KYC review', 
          subtitle: 'All new landlords must be manually verified', 
          value: _requireManualKyc,
          onChanged: (v) => setState(() => _requireManualKyc = v),
        ),
        _SettingsToggle(
          title: 'Auto-approve listings', 
          subtitle: 'Listings by verified landlords bypass review', 
          value: _autoApproveListings,
          onChanged: (v) => setState(() => _autoApproveListings = v),
        ),
        _SettingsDropdown(
          title: 'Global platform fee', 
          subtitle: 'Percentage cut from all bookings', 
          value: _globalFee,
          items: const ['5%', '10%', '15%', '20%'],
          onChanged: (v) => setState(() => _globalFee = v!),
        ),
        _SettingsDropdown(
          title: 'Default currency', 
          subtitle: 'Used for reporting and dashboard stats', 
          value: _defaultCurrency,
          items: const ['KES', 'USD', 'EUR'],
          onChanged: (v) => setState(() => _defaultCurrency = v!),
        ),
      ],
    );
  }

  Widget _buildSecuritySettings() {
    return _SettingsSection(
      title: 'Security & Access',
      icon: PhosphorIcons.shieldCheck(),
      children: [
        _SettingsToggle(
          title: 'Enforce 2FA for Admins', 
          subtitle: 'Require multi-factor auth for this dashboard', 
          value: _enforce2FA,
          onChanged: (v) => setState(() => _enforce2FA = v),
        ),
        _SettingsToggle(
          title: 'Enable Maintenance Mode', 
          subtitle: 'Blocks tenant/landlord API access', 
          value: _maintenanceMode,
          onChanged: (v) => setState(() => _maintenanceMode = v),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: Icon(PhosphorIcons.downloadSimple(), size: 16),
            label: const Text('Export Audit Logs (CSV)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: AppColors.gray700,
              side: const BorderSide(color: StayNestColors.outlineLight),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: StayNestColors.error.withValues(alpha: 0.05),
        border: Border.all(color: StayNestColors.error.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.warning(), color: StayNestColors.error, size: 20),
              const SizedBox(width: 12),
              Text('Danger Zone', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: StayNestColors.error)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Actions here can result in permanent data loss or platform downtime.', style: GoogleFonts.inter(fontSize: 13, color: StayNestColors.error)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: StayNestColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Purge Cached Data'),
          )
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: StayNestColors.outlineLight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.gray900),
              const SizedBox(width: 12),
              Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.gray900)),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggle({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.gray900)),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray500)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: AppColors.gray900,
            inactiveTrackColor: StayNestColors.outlineLight,
          ),
        ],
      ),
    );
  }
}

class _SettingsDropdown extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _SettingsDropdown({required this.title, required this.subtitle, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.gray900)),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray500)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            decoration: BoxDecoration(
              border: Border.all(color: StayNestColors.outlineLight),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                icon: Icon(PhosphorIcons.caretDown(), size: 14, color: AppColors.gray500),
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.gray900),
                items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
