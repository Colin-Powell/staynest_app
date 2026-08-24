
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/theme.dart';
import 'package:property_app/services/super_admin_service.dart';
import 'package:property_app/utils/responsive_layout.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  Map<String, dynamic> _overview = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    setState(() => _loading = true);
    try {
      final data = await SuperAdminService.fetchOverview();
      if (mounted) {
        setState(() {
          _overview = data;
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
    final isDesktop = ResponsiveLayout.isDesktopOrLarger(context);

    final stats = [
      _StatCard(
        title: 'Total Users',
        value: _loading ? '…' : '${_overview['users'] ?? 0}',
        icon: PhosphorIcons.users(PhosphorIconsStyle.fill),
        accent: AppColors.primary,
        trend: '+12% this month',
      ),
      _StatCard(
        title: 'Active Bookings',
        value: _loading ? '…' : '${_overview['bookings'] ?? 0}',
        icon: PhosphorIcons.calendarBlank(PhosphorIconsStyle.fill),
        accent: AppColors.green600,
        trend: '+4% this week',
      ),
      _StatCard(
        title: 'Properties Listed',
        value: _loading ? '…' : '${_overview['properties'] ?? 0}',
        icon: PhosphorIcons.buildingApartment(PhosphorIconsStyle.fill),
        accent: const Color(0xFF6366F1), // Indigo
        trend: 'Steady',
      ),
      _StatCard(
        title: 'Pending KYC',
        value: _loading ? '…' : '${_overview['pendingKyc'] ?? 0}',
        icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
        accent: StayNestColors.warning,
        trend: 'Needs review',
        isWarning: (_overview['pendingKyc'] ?? 0) > 0,
      ),
    ];

    return RefreshIndicator(
      onRefresh: _loadOverview,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard Overview',
                style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray900)),
            const SizedBox(height: 6),
            Text(
                'Monitor platform health, listings, KYC, and operations from one place.',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: AppColors.gray500)),
            const SizedBox(height: 24),
            
            // STATS ROW
            if (isDesktop)
              Row(
                children: stats.map((stat) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: stat == stats.last ? 0 : 16),
                    child: stat,
                  ),
                )).toList(),
              )
            else
              GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                crossAxisCount: ResponsiveLayout.isCompact(context) ? 1 : 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: ResponsiveLayout.isCompact(context) ? 2.5 : 1.5,
                children: stats,
              ),

            const SizedBox(height: 32),

            // MAIN CONTENT AREA
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildLiveSummarySection(),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: _buildQuickActionsSection(),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLiveSummarySection(),
                  const SizedBox(height: 32),
                  _buildQuickActionsSection(),
                ],
              )
          ],
        ),
      ),
    );
  }

  Widget _buildLiveSummarySection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StayNestColors.outlineLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live Summary',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray900)),
          const SizedBox(height: 20),
          _buildActivityTile(
              'Revenue from completed bookings',
              _loading
                  ? 'Loading...'
                  : 'KSh ${(_overview['revenue'] ?? 0).toString()}',
              PhosphorIcons.wallet(PhosphorIconsStyle.fill),
              AppColors.green600),
          _buildActivityTile(
              'Pending KYC submissions',
              _loading
                  ? 'Loading...'
                  : '${_overview['pendingKyc'] ?? 0} waiting review',
              PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
              StayNestColors.warning),
          _buildActivityTile(
              'Registered accounts',
              _loading
                  ? 'Loading...'
                  : '${_overview['users'] ?? 0} total users',
              PhosphorIcons.users(PhosphorIconsStyle.fill),
              AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StayNestColors.outlineLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray900)),
          const SizedBox(height: 20),
          _ActionButton(
              label: 'Verify Listings',
              icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
              onTap: () {}),
          const SizedBox(height: 12),
          _ActionButton(
              label: 'Review KYC',
              icon: PhosphorIcons.identificationBadge(PhosphorIconsStyle.fill),
              onTap: () {}),
          const SizedBox(height: 12),
          _ActionButton(
              label: 'Moderation Queue',
              icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
              onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildActivityTile(String title, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.1))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gray900)),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  final String trend;
  final bool isWarning;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    required this.trend,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isWarning ? StayNestColors.warning.withOpacity(0.5) : StayNestColors.outlineLight,
              width: isWarning ? 1.5 : 1.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: accent, size: 22),
              ),
              if (isWarning)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: StayNestColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Action Req.',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: StayNestColors.warning,
                    ),
                  ),
                )
            ],
          ),
          const SizedBox(height: 20),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: AppColors.gray900)),
          const SizedBox(height: 8),
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.gray500)),
          const SizedBox(height: 12),
          Text(trend,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isWarning ? StayNestColors.warning : AppColors.green600)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: StayNestColors.outlineLight)),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray900)),
            const Spacer(),
            Icon(PhosphorIcons.caretRight(), color: AppColors.gray500, size: 16),
          ],
        ),
      ),
    );
  }
}
