import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/services/super_admin_service.dart';
import 'package:property_app/theme.dart';

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
    final stats = [
      _StatCard(
          title: 'Users',
          value: _loading ? '…' : '${_overview['users'] ?? 0}',
          icon: PhosphorIcons.users(PhosphorIconsStyle.fill),
          accent: AppColors.primary),
      _StatCard(
          title: 'Bookings',
          value: _loading ? '…' : '${_overview['bookings'] ?? 0}',
          icon: PhosphorIcons.calendarBlank(PhosphorIconsStyle.fill),
          accent: AppColors.green600),
      _StatCard(
          title: 'Properties',
          value: _loading ? '…' : '${_overview['properties'] ?? 0}',
          icon: PhosphorIcons.buildingApartment(PhosphorIconsStyle.fill),
          accent: StayNestColors.warning),
      _StatCard(
          title: 'Pending KYC',
          value: _loading ? '…' : '${_overview['pendingKyc'] ?? 0}',
          icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
          accent: StayNestColors.warning),
    ];

    return RefreshIndicator(
      onRefresh: _loadOverview,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform overview',
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray900)),
            const SizedBox(height: 8),
            Text(
                'Monitor platform health, listings, KYC, and operations from one place.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.gray500)),
            const SizedBox(height: 20),
            GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: stats.map((stat) => stat).toList(),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Live summary'),
            const SizedBox(height: 12),
            _buildActivityTile(
                'Revenue from completed bookings',
                _loading
                    ? 'Loading…'
                    : 'KSh ${(_overview['revenue'] ?? 0).toString()}'),
            _buildActivityTile(
                'Pending KYC submissions',
                _loading
                    ? 'Loading…'
                    : '${_overview['pendingKyc'] ?? 0} waiting review'),
            _buildActivityTile(
                'Registered accounts',
                _loading
                    ? 'Loading…'
                    : '${_overview['users'] ?? 0} total users'),
            const SizedBox(height: 20),
            _buildSectionTitle('Quick actions'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ActionButton(
                    label: 'Verify Listings',
                    icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)),
                _ActionButton(
                    label: 'Review KYC',
                    icon: PhosphorIcons.identificationBadge(
                        PhosphorIconsStyle.fill)),
                _ActionButton(
                    label: 'Moderation Queue',
                    icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(title,
      style: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.gray900));

  Widget _buildActivityTile(String title, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: StayNestColors.outlineLight)),
      child: Row(
        children: [
          CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child:
                  Icon(Icons.auto_awesome, color: AppColors.primary, size: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray900))),
          Text(time,
              style:
                  GoogleFonts.poppins(fontSize: 12, color: AppColors.gray500)),
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

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: StayNestColors.outlineLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: accent),
          ),
          const Spacer(),
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray500)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray900)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;

  const _ActionButton({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: StayNestColors.outlineLight)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray900)),
        ],
      ),
    );
  }
}
