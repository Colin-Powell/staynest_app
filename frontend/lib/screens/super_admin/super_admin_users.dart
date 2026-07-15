import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/services/super_admin_service.dart';
import 'package:property_app/theme.dart';

class SuperAdminUsersPage extends StatefulWidget {
  const SuperAdminUsersPage({super.key});

  @override
  State<SuperAdminUsersPage> createState() => _SuperAdminUsersPageState();
}

class _SuperAdminUsersPageState extends State<SuperAdminUsersPage> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final users = await SuperAdminService.fetchUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User management',
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray900)),
            const SizedBox(height: 8),
            Text(
                'Review accounts, permissions, KYC state, and moderation status.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.gray500)),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator()))
            else if (_users.isEmpty)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No users found.')))
            else
              ..._users.map((user) {
                final role = user['role']?.toString() ?? 'tenant';
                final verified = user['verified'] == true;
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
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.12),
                          child: Icon(
                              PhosphorIcons.user(PhosphorIconsStyle.fill),
                              color: AppColors.primary)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['name']?.toString() ?? 'Unknown user',
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.gray900)),
                            Text(role.toUpperCase(),
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: AppColors.gray500)),
                          ],
                        ),
                      ),
                      Chip(
                          label: Text(verified ? 'Verified' : 'Pending',
                              style: GoogleFonts.poppins(fontSize: 11)),
                          backgroundColor: verified
                              ? AppColors.greenBg
                              : AppColors.primary.withValues(alpha: 0.08)),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
