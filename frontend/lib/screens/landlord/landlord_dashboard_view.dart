import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/verification_api.dart';

// ─── Landlord Design System Constants ─────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981); // Emerald Green for Landlord Theme

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
  bool _isLoading = true;

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
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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
        return 'Verified';
      case 'rejected':
        return 'Action Required';
      default:
        return 'Pending';
    }
  }

  Color get _verificationStatusColor {
    if (_verificationStatus == null) return _grey;
    final status = _verificationStatus!['status']?.toString().toLowerCase() ?? 'submitted';
    switch (status) {
      case 'approved':
        return _green;
      case 'rejected':
        return const Color(0xFFEF4444); // Red
      case 'submitted':
        return const Color(0xFFF59E0B); // Amber
      default:
        return _grey;
    }
  }
  
  IconData get _verificationStatusIcon {
    if (_verificationStatus == null) return PhosphorIconsRegular.fileDashed;
    final status = _verificationStatus!['status']?.toString().toLowerCase() ?? 'submitted';
    switch (status) {
      case 'approved':
        return PhosphorIconsFill.sealCheck;
      case 'rejected':
        return PhosphorIconsFill.warningCircle;
      case 'submitted':
        return PhosphorIconsFill.hourglassHigh;
      default:
        return PhosphorIconsRegular.fileDashed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            'Dashboard',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _dark,
              letterSpacing: -0.5,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(PhosphorIconsRegular.signOut, color: _dark, size: 24),
              onPressed: widget.onLogout,
              tooltip: 'Logout',
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _green,
        backgroundColor: _surface,
        onRefresh: _loadVerificationStatus,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Welcome Header ───
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${AppSession.displayName.split(' ')[0]}',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your properties and inquiries',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: _grey,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ─── Verification Status Card ───
              _buildVerificationCard(),
              const SizedBox(height: 32),

              // ─── Quick Actions ───
              Text(
                'Quick Actions',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 16),
              _buildActionButton(
                icon: PhosphorIconsRegular.houseLine,
                title: 'Add New Property',
                subtitle: 'List a property for rent',
                onTap: widget.onAddProperty,
              ),
              _buildActionButton(
                icon: PhosphorIconsRegular.chatTeardropText,
                title: 'Messages',
                subtitle: 'Chat with tenants',
                onTap: () => Navigator.pushNamed(context, '/messages'),
              ),
              _buildActionButton(
                icon: PhosphorIconsRegular.listChecks,
                title: 'My Properties',
                subtitle: 'View and manage listings',
                onTap: () => Navigator.pushNamed(context, '/landlord_properties'),
              ),
              _buildActionButton(
                icon: PhosphorIconsRegular.bellRinging,
                title: 'Inquiries',
                subtitle: 'Tenant booking requests',
                onTap: () => Navigator.pushNamed(context, '/landlord_tenants'),
              ),
              const SizedBox(height: 32),

              // ─── Stats Section ───
              Text(
                'Overview',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildStatCard('Properties', '0', PhosphorIconsRegular.buildings)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('Inquiries', '0', PhosphorIconsRegular.users)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildStatCard('Bookings', '0', PhosphorIconsRegular.calendarCheck)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('Messages', '0', PhosphorIconsRegular.chats)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── UI BUILDERS ─────────────────────────────────────────────────────────────

  Widget _buildVerificationCard() {
    final isVerified = _verificationStatus?['status']?.toString().toLowerCase() == 'approved';
    final isRejected = _verificationStatus?['status']?.toString().toLowerCase() == 'rejected';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _isLoading ? _grey.withOpacity(0.1) : _verificationStatusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: _isLoading
                    ? Shimmer.fromColors(
                        baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
                        child: Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                      )
                    : Icon(_verificationStatusIcon, color: _verificationStatusColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification Status',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _isLoading
                        ? Shimmer.fromColors(
                            baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
                            child: Container(height: 14, width: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                          )
                        : Text(
                            _verificationStatusText,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: _verificationStatusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ],
                ),
              ),
              const Icon(PhosphorIconsRegular.caretRight, size: 20, color: _grey),
            ],
          ),
          
          if (!_isLoading && isRejected) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(PhosphorIconsRegular.info, color: Color(0xFFEF4444), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _verificationStatus?['admin_notes'] ?? 'Your verification was rejected. Please review your documents and resubmit.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF991B1B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          if (_isLoading)
            Shimmer.fromColors(
              baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
              child: Container(height: 14, width: 150, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
            )
          else if (!isVerified)
            GestureDetector(
              onTap: widget.onViewVerification,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text(
                    isRejected ? 'Fix & Resubmit' : 'Complete Verification',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _green,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(PhosphorIconsRegular.arrowRight, size: 14, color: _green),
                ],
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
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _grey.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _green, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: _grey,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(PhosphorIconsRegular.caretRight, size: 20, color: _grey),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _green, size: 24),
          const SizedBox(height: 16),
          _isLoading
              ? Shimmer.fromColors(
                  baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
                  child: Container(height: 24, width: 40, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                )
              : Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                    letterSpacing: -0.5,
                  ),
                ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: _grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}