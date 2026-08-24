import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  final Set<String> _processingIds = <String>{};
  List<Map<String, dynamic>> _users = [];
  String _searchQuery = '';
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

  Future<void> _handleUserAction(String userId, String action, dynamic value) async {
    setState(() => _processingIds.add(userId));
    try {
      // Simulating a successful network delay and local state update
      await Future.delayed(const Duration(milliseconds: 800)); 
      
      if (mounted) {
        setState(() {
          final index = _users.indexWhere((u) => u['id'] == userId);
          if (index != -1) {
            _users[index] = { ..._users[index], action: value };
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.gray900,
            content: Text(
              'User updated successfully.',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.gray900,
            content: Text(
              'Failed to update user: $error',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(userId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _users.where((user) {
      final name = (user['name']?.toString() ?? '').toLowerCase();
      final email = (user['email']?.toString() ?? '').toLowerCase();
      final role = (user['role']?.toString() ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query) || role.contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('User Management',
                      style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray900,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Text('Review accounts, manage KYC, and enforce platform policies.',
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppColors.gray500)),
                ],
              ),
              Container(
                width: 320,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(color: StayNestColors.outlineLight),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray900),
                  decoration: InputDecoration(
                    hintText: 'Search name, email, or role...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.gray400),
                    prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), size: 16, color: AppColors.gray500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _loading 
            ? const Center(child: CircularProgressIndicator(color: AppColors.gray900))
            : filteredUsers.isEmpty 
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset('assets/illustrations/empty.svg', height: 120),
                      const SizedBox(height: 16),
                      Text('No users found', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.gray900)),
                      const SizedBox(height: 4),
                      Text('No accounts match your current search filters.', style: GoogleFonts.inter(fontSize: 14, color: AppColors.gray500)),
                    ],
                  ),
                )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: filteredUsers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return _buildUserCard(filteredUsers[index]);
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final id = user['id']?.toString() ?? '';
    final name = user['name']?.toString() ?? 'Unknown User';
    final email = user['email']?.toString() ?? 'No email provided';
    final phone = user['phone']?.toString() ?? 'No phone provided';
    final role = (user['role']?.toString() ?? 'tenant').toUpperCase();
    final joinDate = user['created_at']?.toString() ?? 'N/A';
    
    final isVerified = user['verified'] == true;
    final isSuspended = user['status'] == 'suspended';
    
    final isProcessing = _processingIds.contains(id);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: StayNestColors.outlineLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Avatar Placeholder
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.gray100,
                border: Border.all(color: StayNestColors.outlineLight),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(
                    fontSize: 24, 
                    fontWeight: FontWeight.w600, 
                    color: AppColors.gray500
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            
            // User Information & Metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(name,
                                  style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.gray900)),
                              const SizedBox(width: 12),
                              _buildRoleBadge(role),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(email,
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: AppColors.gray500)),
                        ],
                      ),
                      
                      // Status Badges
                      Row(
                        children: [
                          _buildStateBadge(
                            isVerified ? 'VERIFIED KYC' : 'UNVERIFIED', 
                            isVerified
                          ),
                          const SizedBox(width: 8),
                          if (isSuspended)
                            _buildStateBadge('SUSPENDED', false),
                        ],
                      )
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: StayNestColors.outlineLight),
                  const SizedBox(height: 16),
                  
                  // Metadata Grid
                  Row(
                    children: [
                      Expanded(child: _buildMetaItem('Phone Number', phone, PhosphorIcons.phone())),
                      Expanded(child: _buildMetaItem('Registered On', joinDate, PhosphorIcons.calendarBlank())),
                      Expanded(child: _buildMetaItem('Properties', role == 'LANDLORD' ? '${user['property_count'] ?? 0} Listed' : 'N/A', PhosphorIcons.buildingApartment())),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Suspend / Reactivate Action
                      OutlinedButton(
                        onPressed: isProcessing ? null : () => _handleUserAction(id, 'status', isSuspended ? 'active' : 'suspended'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.gray900,
                          side: BorderSide(color: AppColors.gray400),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                        child: Text(isSuspended ? 'Reactivate User' : 'Suspend Account'),
                      ),
                      const SizedBox(width: 12),
                      
                      // Verify / Revoke KYC Action
                      ElevatedButton(
                        onPressed: isProcessing ? null : () => _handleUserAction(id, 'verified', !isVerified),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gray900,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                        child: isProcessing 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(isVerified ? 'Revoke Verification' : 'Verify KYC Documents'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.gray400),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray500,
                    letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.gray900)),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        border: Border.all(color: AppColors.gray400),
      ),
      child: Text(role,
          style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.gray700)),
    );
  }

  Widget _buildStateBadge(String label, bool isPositive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPositive ? Colors.white : AppColors.gray50,
        border: Border.all(color: isPositive ? AppColors.gray900 : AppColors.gray400),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11, 
              fontWeight: FontWeight.w600, 
              color: isPositive ? AppColors.gray900 : AppColors.gray500)),
    );
  }
}