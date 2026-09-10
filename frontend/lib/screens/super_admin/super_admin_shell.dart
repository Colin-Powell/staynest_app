import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/theme.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/utils/responsive_layout.dart';
import 'package:property_app/services/notification_api.dart';
import 'super_admin_dashboard.dart';
import 'super_admin_properties.dart';
import 'super_admin_users.dart';
import 'super_admin_kyc.dart';
import 'super_admin_settings.dart';
import 'super_admin_withdrawals.dart';
import 'super_admin_login.dart';

class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({super.key});

  @override
  State<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends State<SuperAdminShell> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, dynamic>> _notifications = [];

  static final List<_NavItem> _navItems = [
    _NavItem(label: 'Dashboard', icon: PhosphorIcons.house()),
    _NavItem(label: 'KYC Reviews', icon: PhosphorIcons.shieldCheck()),
    _NavItem(label: 'Properties', icon: PhosphorIcons.buildingApartment()),
    _NavItem(label: 'Users', icon: PhosphorIcons.users()),
    _NavItem(label: 'Withdrawals', icon: PhosphorIcons.wallet()),
    _NavItem(label: 'Settings', icon: PhosphorIcons.gearSix()),
  ];

  final List<Widget> _pages = const [
    SuperAdminDashboard(),
    SuperAdminKycPage(),
    SuperAdminPropertiesPage(),
    SuperAdminUsersPage(),
    SuperAdminWithdrawalsPage(),
    SuperAdminSettingsPage(),
  ];

  void _handleLogout() {
    AppSession.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SuperAdminLoginView()),
      (route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final response = await NotificationApi.fetchNotifications(limit: 20);
      if (mounted) {
        setState(() => _notifications =
            (response['data'] as List<dynamic>? ?? [])
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList());
      }
    } catch (_) {
      // The admin shell remains usable if notification history is unavailable.
    }
  }

  String _notificationTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  int get _mobileSelectedIndex {
    if (_selectedIndex == 0) return 0;
    if (_selectedIndex == 1) return 1;
    if (_selectedIndex == 4) return 2;
    return 3;
  }

  void _selectMobileDestination(int index) {
    const pageIndices = [0, 1, 4];
    if (index < pageIndices.length) {
      setState(() => _selectedIndex = pageIndices[index]);
      return;
    }
    _showMoreSheet();
  }

  Future<void> _showMoreSheet() async {
    final pageIndex = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Admin sections')),
            _MoreDestination(
              icon: _navItems[2].icon,
              label: _navItems[2].label,
              selected: _selectedIndex == 2,
              onTap: () => Navigator.pop(sheetContext, 2),
            ),
            _MoreDestination(
              icon: _navItems[3].icon,
              label: _navItems[3].label,
              selected: _selectedIndex == 3,
              onTap: () => Navigator.pop(sheetContext, 3),
            ),
            _MoreDestination(
              icon: _navItems[5].icon,
              label: _navItems[5].label,
              selected: _selectedIndex == 5,
              onTap: () => Navigator.pop(sheetContext, 5),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (pageIndex != null && mounted) {
      setState(() => _selectedIndex = pageIndex);
    }
  }

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
                Icon(PhosphorIcons.shieldSlash(),
                    size: 48, color: AppColors.gray500),
                const SizedBox(height: 24),
                Text('Access Restricted',
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gray900)),
                const SizedBox(height: 8),
                Text('Only super admins can access this area.',
                    style: GoogleFonts.inter(color: AppColors.gray500)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _handleLogout,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gray900,
                      foregroundColor: Colors.white),
                  child: const Text('Logout'),
                )
              ],
            ),
          ),
        ),
      );
    }

    final isDesktop = ResponsiveLayout.isDesktopOrLarger(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Global Top Header
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                  bottom: BorderSide(color: StayNestColors.outlineLight)),
            ),
            child: Row(
              children: [
                if (isDesktop)
                  IconButton(
                    icon: Icon(PhosphorIcons.list(),
                        color: AppColors.gray700, size: 20),
                    onPressed: () {
                      setState(() {
                        _isSidebarExpanded = !_isSidebarExpanded;
                      });
                    },
                  ),
                if (isDesktop) const SizedBox(width: 8),

                // Logo & Brand
                if (isDesktop) ...[
                  Icon(PhosphorIcons.buildings(),
                      color: AppColors.gray700, size: 24),
                  const SizedBox(width: 12),
                  Text('StayNest Admin',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.gray900)),
                ],

                const Spacer(),

                // Notification Bell (Now a Dropdown Popup)
                Theme(
                  data: Theme.of(context).copyWith(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                  child: PopupMenuButton<String>(
                    offset: const Offset(0, 48),
                    color: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    tooltip: 'Notifications',
                    padding: EdgeInsets.zero,
                    shape: Border.all(color: StayNestColors.outlineLight),
                    icon: Badge(
                      backgroundColor: StayNestColors.error,
                      child: Icon(PhosphorIcons.bell(),
                          color: AppColors.gray500, size: 20),
                    ),
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        enabled:
                            false, // Prevents closing when clicking the background
                        padding: EdgeInsets.zero,
                        child: SizedBox(
                          width: 340,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Popup Header
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Notifications',
                                        style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.gray900)),
                                    InkWell(
                                      onTap: () async {
                                        await NotificationApi.markAllAsRead();
                                        if (mounted) {
                                          setState(() {
                                            _notifications = _notifications
                                                .map((item) =>
                                                    {...item, 'is_read': true})
                                                .toList();
                                          });
                                        }
                                      },
                                      child: Text('Mark all read',
                                          style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.gray500)),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(
                                  height: 1,
                                  color: StayNestColors.outlineLight),

                              // Scrollable Notifications List
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxHeight: 380),
                                child: ListView(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  children: _notifications.isEmpty
                                      ? [
                                          const Padding(
                                            padding: EdgeInsets.all(24),
                                            child:
                                                Text('No notifications yet.'),
                                          )
                                        ]
                                      : _notifications.map((item) {
                                          final data = item['data'] is Map
                                              ? Map<String, dynamic>.from(
                                                  item['data'] as Map)
                                              : <String, dynamic>{};
                                          final type =
                                              data['type']?.toString() ?? '';
                                          final isUnread =
                                              item['is_read'] != true;
                                          return _NotificationItem(
                                            title: item['title']?.toString() ??
                                                'Notification',
                                            time: _notificationTime(
                                                item['created_at']),
                                            icon: type.contains('withdrawal')
                                                ? PhosphorIcons.wallet()
                                                : type.contains('property')
                                                    ? PhosphorIcons
                                                        .buildingApartment()
                                                    : PhosphorIcons.bell(),
                                            unread: isUnread,
                                          );
                                        }).toList(),
                                ),
                              ),

                              const Divider(
                                  height: 1,
                                  color: StayNestColors.outlineLight),

                              // Footer Action
                              InkWell(
                                onTap: () {
                                  Navigator.pop(ctx);
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  child: Center(
                                    child: Text('View all notifications',
                                        style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.gray900)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Admin Profile Dropdown
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'logout') _handleLogout();
                  },
                  offset: const Offset(0, 48),
                  color: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'settings',
                      child: Row(children: [
                        Icon(PhosphorIcons.gear(), size: 16),
                        const SizedBox(width: 12),
                        Text('Account Settings',
                            style: GoogleFonts.inter(fontSize: 14))
                      ]),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'logout',
                      child: Row(children: [
                        Icon(PhosphorIcons.signOut(),
                            size: 16, color: StayNestColors.error),
                        const SizedBox(width: 12),
                        Text('Logout',
                            style: GoogleFonts.inter(
                                fontSize: 14, color: StayNestColors.error))
                      ]),
                    ),
                  ],
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.gray100,
                        child: Text(
                          (AppSession.currentUser!['name'])
                              .substring(0, 1)
                              .toUpperCase(),
                          style: GoogleFonts.inter(
                              color: AppColors.gray700,
                              fontWeight: FontWeight.w500,
                              fontSize: 12),
                        ),
                      ),
                      if (isDesktop) ...[
                        const SizedBox(width: 8),
                        Text(
                          (AppSession.currentUser!['name']) ?? 'Admin',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w400,
                              fontSize: 13,
                              color: AppColors.gray700),
                        ),
                        const SizedBox(width: 4),
                        Icon(PhosphorIcons.caretDown(),
                            size: 14, color: AppColors.gray500),
                      ]
                    ],
                  ),
                ),
                if (isDesktop) const SizedBox(width: 16),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Row(
              children: [
                if (isDesktop)
                  NavigationRail(
                    backgroundColor: Colors.white,
                    extended: _isSidebarExpanded,
                    minExtendedWidth: 220,
                    minWidth: 64,
                    selectedIndex: _selectedIndex,
                    indicatorColor: AppColors.gray100,
                    onDestinationSelected: (index) =>
                        setState(() => _selectedIndex = index),
                    unselectedLabelTextStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.gray500,
                        fontWeight: FontWeight.w400),
                    selectedLabelTextStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.gray900,
                        fontWeight: FontWeight.w500),
                    unselectedIconTheme:
                        const IconThemeData(color: AppColors.gray500, size: 20),
                    selectedIconTheme:
                        const IconThemeData(color: AppColors.gray900, size: 20),
                    destinations: _navItems.map((item) {
                      return NavigationRailDestination(
                        icon: Icon(item.icon),
                        label: Text(item.label),
                      );
                    }).toList(),
                  ),
                if (isDesktop)
                  const VerticalDivider(
                      thickness: 1,
                      width: 1,
                      color: StayNestColors.outlineLight),
                Expanded(
                  child: Container(
                    color: AppColors.gray50,
                    child: _pages[_selectedIndex],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: _mobileSelectedIndex,
              height: 68,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              backgroundColor: Colors.white,
              indicatorColor: AppColors.gray100,
              onDestinationSelected: _selectMobileDestination,
              destinations: [
                NavigationDestination(
                    icon: Icon(_navItems[0].icon), label: _navItems[0].label),
                NavigationDestination(
                    icon: Icon(_navItems[1].icon), label: 'KYC'),
                NavigationDestination(
                    icon: Icon(_navItems[4].icon), label: 'Withdrawals'),
                NavigationDestination(
                    icon: Icon(PhosphorIcons.dotsThreeOutline()),
                    label: 'More'),
              ],
            ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final String title;
  final String time;
  final IconData icon;
  final bool unread;
  final Color? iconColor;

  const _NotificationItem(
      {required this.title,
      required this.time,
      required this.icon,
      required this.unread,
      this.iconColor});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Notification action (mark as read / view details)
      },
      child: Container(
        color: unread ? AppColors.gray50 : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color:
                      (iconColor ?? AppColors.gray500).withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child:
                  Icon(icon, size: 16, color: iconColor ?? AppColors.gray700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight:
                              unread ? FontWeight.w600 : FontWeight.w500,
                          color: AppColors.gray900)),
                  const SizedBox(height: 4),
                  Text(time,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.gray500)),
                ],
              ),
            ),
            if (unread)
              Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                      color: AppColors.gray900, shape: BoxShape.circle)),
          ],
        ),
      ),
    );
  }
}

class _MoreDestination extends StatelessWidget {
  const _MoreDestination({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem({required this.label, required this.icon});
}
