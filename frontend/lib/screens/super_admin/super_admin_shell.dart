import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/app_theme.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/theme.dart';

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
        label: 'Users', icon: PhosphorIcons.users(PhosphorIconsStyle.fill)),
    _NavItem(
        label: 'Properties',
        icon: PhosphorIcons.buildingApartment(PhosphorIconsStyle.fill)),
    _NavItem(
        label: 'KYC', icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill)),
    _NavItem(
        label: 'Settings',
        icon: PhosphorIcons.gearSix(PhosphorIconsStyle.fill)),
  ];

  final List<Widget> _pages = const [
    SuperAdminDashboard(),
    SuperAdminUsersPage(),
    SuperAdminPropertiesPage(),
    SuperAdminKycPage(),
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text('Super Admin',
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.gray900)),
        actions: [
          IconButton(
              onPressed: () {},
              icon: Icon(PhosphorIcons.bell(PhosphorIconsStyle.fill),
                  color: AppColors.gray700)),
          IconButton(
              onPressed: () {},
              icon: Icon(PhosphorIcons.signOut(PhosphorIconsStyle.fill),
                  color: AppColors.gray700)),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('StayNest Admin',
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              ..._navItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final selected = _selectedIndex == index;
                return ListTile(
                  leading: Icon(item.icon,
                      color: selected ? AppColors.primary : AppColors.gray600),
                  title: Text(item.label,
                      style: GoogleFonts.poppins(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500)),
                  selected: selected,
                  selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                  onTap: () {
                    setState(() => _selectedIndex = index);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
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
