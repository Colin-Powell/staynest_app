import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/theme.dart';
import 'package:property_app/services/verification_api.dart';

class LandlordDashboardView extends StatefulWidget {
  final VoidCallback? onLogout;
  final VoidCallback? onAddProperty;
  final VoidCallback? onViewVerification;

  const LandlordDashboardView({
    super.key,
    this.onLogout,
    this.onAddProperty,
    this.onViewVerification,
  });

  @override
  State<LandlordDashboardView> createState() => _LandlordDashboardViewState();
}

class _LandlordDashboardViewState extends State<LandlordDashboardView> {
  Map<String, dynamic>? _verificationStatus;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
  }

  Future<void> _loadVerificationStatus() async {
    try {
      final status = await VerificationApi.getVerificationStatus();
      if (mounted) {
        setState(() {
          _verificationStatus = status;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String get _verificationStatusText {
    if (_verificationStatus == null) return 'Not Started';
    final status = _verificationStatus!['status']?.toString().toLowerCase() ?? 'submitted';
    switch (status) {
      case 'submitted':
        return 'Under Review';
      case 'approved':
        return 'Verified ✓';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  Color get _verificationStatusColor {
    if (_verificationStatus == null) return AppColors.gray400;
    final status = _verificationStatus!['status']?.toString().toLowerCase() ?? 'submitted';
    switch (status) {
      case 'approved':
        return AppColors.green600;
      case 'rejected':
        return const Color(0xFFE53935);
      case 'submitted':
        return StayNestColors.warning;
      default:
        return AppColors.gray400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Dashboard',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.gray900,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.gray900),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
              onRefresh: _loadVerificationStatus,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${AppSession.displayName}',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.gray900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Manage your properties and inquiries',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppColors.gray500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Verification Status Card
                    _buildVerificationCard(),
                    const SizedBox(height: 24),

                    // Quick Actions
                    Text(
                      'Quick Actions',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gray900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      icon: PhosphorIcons.house(PhosphorIconsStyle.fill),
                      title: 'Add New Property',
                      subtitle: 'List a property for rent',
                      onTap: widget.onAddProperty,
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      icon: PhosphorIcons.chatDots(PhosphorIconsStyle.fill),
                      title: 'Messages',
                      subtitle: 'Chat with tenants',
                      onTap: () {
                        Navigator.pushNamed(context, '/messages');
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      icon: PhosphorIcons.listChecks(PhosphorIconsStyle.fill),
                      title: 'My Properties',
                      subtitle: 'View and manage listings',
                      onTap: () {
                        Navigator.pushNamed(context, '/landlord_properties');
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      icon: PhosphorIcons.bell(PhosphorIconsStyle.fill),
                      title: 'Inquiries',
                      subtitle: 'Tenant booking requests',
                      onTap: () {
                        Navigator.pushNamed(context, '/landlord_tenants');
                      },
                    ),
                    const SizedBox(height: 24),

                    // Stats Section
                    Text(
                      'Stats',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gray900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard('Properties', '0', AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard('Inquiries', '0', AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard('Bookings', '0', AppColors.green600),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard('Messages', '0', StayNestColors.warning),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildVerificationCard() {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4E6EF), width: 1),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final isVerified = _verificationStatus?['status']?.toString().toLowerCase() == 'approved';
    final isRejected = _verificationStatus?['status']?.toString().toLowerCase() == 'rejected';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E6EF), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _verificationStatusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isVerified
                      ? Icons.check_circle
                      : isRejected
                          ? Icons.cancel
                          : Icons.pending,
                  color: _verificationStatusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification Status',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray900,
                      ),
                    ),
                    Text(
                      _verificationStatusText,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _verificationStatusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.gray400,
              ),
            ],
          ),
          if (isRejected) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _verificationStatus?['admin_notes'] ?? 'Your verification was rejected. Please resubmit.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFFE53935),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (!isVerified)
            GestureDetector(
              onTap: widget.onViewVerification,
              child: Text(
                isRejected ? 'Fix & Resubmit' : 'Complete Verification',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4E6EF), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.gray500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.gray400),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E6EF), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.gray500,
            ),
          ),
        ],
      ),
    );
  }
}
