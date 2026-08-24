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
                    style: GoogleFonts.poppins(color: StayNestColors.textSecondaryLight)),
              ],
            ),
          ),
        ),
      );
    }

    final isDesktop = ResponsiveLayout.isDesktopOrLarger(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Global Top Header
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(bottom: BorderSide(color: StayNestColors.outlineLight)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                // Logo & Brand
                if (isDesktop) ...[
                  Icon(PhosphorIcons.buildings(PhosphorIconsStyle.fill), color: AppColors.primary, size: 28),
                  const SizedBox(width: 12),
                  Text('StayNest Admin', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: StayNestColors.textPrimaryLight)),
                  const SizedBox(width: 48),
                ],
                
                // Global Search Bar
                Expanded(
                  child: Container(
                    height: 40,
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: StayNestColors.surfaceVariantLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: StayNestColors.outlineLight),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search users, properties, or records...',
                        hintStyle: GoogleFonts.poppins(fontSize: 13, color: StayNestColors.textSecondaryLight),
                        prefixIcon: const Icon(Icons.search, size: 20, color: StayNestColors.textSecondaryLight),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Notification Bell
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    IconButton(
                      icon: Icon(PhosphorIcons.bell(PhosphorIconsStyle.fill), color: StayNestColors.textSecondaryLight),
                      onPressed: () {},
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: StayNestColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(width: 12),
                
                // Admin Profile Dropdown
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text((AppSession.currentUser != null ? AppSession.currentUser!['name'] : 'Admin').substring(0, 1).toUpperCase() ?? 'A',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                    ),
                    if (isDesktop) ...[
                      const SizedBox(width: 8),
                      Text((AppSession.currentUser != null ? AppSession.currentUser!['name'] : 'Admin') ?? 'Admin', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                      const Icon(Icons.keyboard_arrow_down, size: 18, color: StayNestColors.textSecondaryLight),
                    ]
                  ],
                ),
              ],
            ),
          ),
          
          // Main Content
          Expanded(
            child: Row(
              children: [
                if (isDesktop)
                  NavigationRail(
                    backgroundColor: StayNestColors.surfaceLight,
                    extended: ResponsiveLayout.isLargeDesktop(context),
                    minExtendedWidth: 220,
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                    destinations: _navItems.map((item) {
                      return NavigationRailDestination(
                        icon: Icon(item.icon),
                        label: Text(item.label, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                      );
                    }).toList(),
                  ),
                
                if (isDesktop) const VerticalDivider(thickness: 1, width: 1, color: StayNestColors.outlineLight),
                
                Expanded(
                  child: _pages[_selectedIndex],
                ),
              ],
            ),
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
