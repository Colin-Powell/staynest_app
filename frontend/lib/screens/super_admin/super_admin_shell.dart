import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/app_theme.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/theme.dart';
import 'package:property_app/utils/responsive_layout.dart';

import 'super_admin_dashboard.dart';
import 'super_admin_users.dart';
import 'super_admin_properties.dart';
import 'super_admin_kyc.dart';
import 'super_admin_settings.dart';

class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({super.key});

  @override
  State<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends State<SuperAdminShell> {
  int _selectedIndex = 0;

  static final List<_NavItem> _navItems = [
    _NavItem(
        label: 'Dashboard', icon: PhosphorIcons.house(PhosphorIconsStyle.fill)),
    _NavItem(
        label: 'KYC Reviews', icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill)),
    _NavItem(
        label: 'Properties',
        icon: PhosphorIcons.buildingApartment(PhosphorIconsStyle.fill)),
    _NavItem(
        label: 'Users', icon: PhosphorIcons.users(PhosphorIconsStyle.fill)),
    _NavItem(
        label: 'Settings',
        icon: PhosphorIcons.gearSix(PhosphorIconsStyle.fill)),
  ];

  final List<Widget> _pages = const [
    SuperAdminDashboard(),
    SuperAdminKycPage(),
    SuperAdminPropertiesPage(),
    SuperAdminUsersPage(),
    SuperAdminSettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final isAdmin = AppSession.currentRole.toLowerCase() == 'admin';
    if (!isAdmin) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PhosphorIcons.shieldSlash(PhosphorIconsStyle.fill),
                    size: 64, color: AppColors.primary),
                const SizedBox(height: 16),
                Text('Access Restricted',
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Only super admins can access this area.',
                    style: GoogleFonts.poppins(color: AppColors.gray500)),
              ],
            ),
          ),
        ),
      );
    }

    final isDesktop = ResponsiveLayout.isDesktopOrLarger(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: isDesktop ? null : AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text('Super Admin',
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.gray900)),
      ),
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              backgroundColor: AppColors.white,
              extended: ResponsiveLayout.isLargeDesktop(context),
              minExtendedWidth: 240,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill), color: AppColors.primary, size: 28),
                    if (ResponsiveLayout.isLargeDesktop(context)) ...[
                      const SizedBox(width: 12),
                      Text('Admin',
                          style: GoogleFonts.poppins(
                              fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.gray900)),
                    ]
                  ],
                ),
              ),
              destinations: _navItems.map((item) {
                return NavigationRailDestination(
                  icon: Icon(item.icon),
                  label: Text(item.label, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                );
              }).toList(),
            ),
          
          if (isDesktop) const VerticalDivider(thickness: 1, width: 1, color: AppColors.outlineLight),
          
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
      bottomNavigationBar: isDesktop ? null : NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: _navItems
            .map((item) =>
                NavigationDestination(icon: Icon(item.icon), label: item.label))
            .toList(),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem({required this.label, required this.icon});
}
