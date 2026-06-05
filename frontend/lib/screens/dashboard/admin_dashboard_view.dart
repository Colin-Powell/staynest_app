import 'package:flutter/material.dart';
import 'package:property_app/app_theme.dart';
import 'package:property_app/services/verification_api.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String formatPrice(int? amount) {
  if (amount == null) return 'N/A';
  final formatted = amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
  return 'KSh $formatted';
}

// ─── Constants ────────────────────────────────────────────────────────────────

const Color _primary = Color(0xFF6366F1);
Color get _bgColor => AppTheme.background;

// ─── Main Widget ──────────────────────────────────────────────────────────────

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  List<Map<String, dynamic>> _pendingVerifications = [];
  int _totalVerifications = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPendingVerifications();
  }

  Future<void> _loadPendingVerifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final verifications =
          await VerificationApi.getPendingVerifications(limit: 10);
      final allVerifications = await VerificationApi.getAdminVerifications();

      setState(() {
        _pendingVerifications = verifications;
        _totalVerifications = allVerifications['total'] as int;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load verifications: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _approveVerification(String verificationId) async {
    try {
      await VerificationApi.approveVerification(verificationId: verificationId);
      await _loadPendingVerifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification approved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _rejectVerification(String verificationId) async {
    try {
      await VerificationApi.rejectVerification(verificationId: verificationId);
      await _loadPendingVerifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification rejected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: CustomScrollView(
        slivers: [
          _buildStickyHeader(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 112),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildStatCards(),
                const SizedBox(height: 24),
                _buildMiniStats(),
                const SizedBox(height: 32),
                _buildSectionTitle('Pending Verifications'),
                const SizedBox(height: 16),
                _buildPendingVerificationsSection(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sticky Header ──────────────────────────────────────────────────────────

  SliverAppBar _buildStickyHeader(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      floating: false,
      backgroundColor: _bgColor,
      elevation: 0,
      expandedHeight: 0,
      toolbarHeight: 64,
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Admin Dashboard',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.4,
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.10),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.shield_outlined,
                    color: _primary, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Stat Cards Row ─────────────────────────────────────────────────────────

  Widget _buildStatCards() {
    final stats = [
      _StatData(
          icon: Icons.description_outlined,
          label: 'Pending',
          value: _pendingVerifications.length.toString()),
      _StatData(
          icon: Icons.check_circle_outline,
          label: 'Total',
          value: _totalVerifications.toString()),
      _StatData(
          icon: Icons.info_outline,
          label: 'Status',
          value: _isLoading ? '...' : 'Active'),
    ];

    return Row(
      children: stats.map((s) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: s != stats.last ? 12 : 0),
            child: _StatCard(data: s),
          ),
        );
      }).toList(),
    );
  }

  // ─── Mini Stats Grid ────────────────────────────────────────────────────────

  Widget _buildMiniStats() {
    return Row(
      children: [
        _MiniStat(
            value: _pendingVerifications.length.toString(),
            label: 'Awaiting',
            valueColor: Color(0xFF111827)),
        SizedBox(width: 12),
        _MiniStat(
            value: _totalVerifications.toString(),
            label: 'All Time',
            valueColor: Color(0xFF111827)),
        SizedBox(width: 12),
        _MiniStat(
            value: _isLoading ? '-' : 'OK',
            label: 'System',
            valueColor:
                _isLoading ? Color(0xFF9CA3AF) : Color(0xFF22C55E)),
      ],
    );
  }

  // ─── Section Title ──────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: Color(0xFF111827),
        letterSpacing: -0.3,
      ),
    );
  }

  // ─── Pending Verifications Section ──────────────────────────────────────────

  Widget _buildPendingVerificationsSection() {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(color: _primary),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadPendingVerifications,
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pendingVerifications.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.inbox_outlined,
                color: Color(0xFFC4B5FD), size: 64),
            const SizedBox(height: 16),
            const Text(
              'No Pending Verifications',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'All verifications have been reviewed',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ..._pendingVerifications.asMap().entries.map((entry) {
          final index = entry.key;
          final verification = entry.value;
          return Column(
            children: [
              _buildVerificationCard(verification),
              if (index < _pendingVerifications.length - 1)
                const SizedBox(height: 12),
            ],
          );
        }).toList(),
        if (_pendingVerifications.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildViewAllButton(),
        ]
      ],
    );
  }

  // ─── Verification Card ──────────────────────────────────────────────────────

  Widget _buildVerificationCard(Map<String, dynamic> verification) {
    final propertyData = verification['property_data'] as Map<String, dynamic>?;
    final userData = verification['user_name'] as String? ?? 'Unknown';
    final userEmail = verification['user_email'] as String? ?? '';
    final price = propertyData?['price'] as int?;
    final title = propertyData?['title'] as String? ?? 'Unnamed Property';
    final city = propertyData?['city'] as String? ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 28,
            backgroundColor: _primary.withOpacity(0.1),
            child: Icon(Icons.person, color: _primary, size: 28),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$city • $userData',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatPrice(price),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ],
            ),
          ),
          // Action buttons
          Column(
            children: [
              _ActionButton(
                icon: Icons.check,
                bgColor: const Color(0xFFF0FDF4),
                iconColor: const Color(0xFF22C55E),
                borderColor: const Color(0xFFDCFCE7),
                onTap: () => _approveVerification(verification['id']),
              ),
              const SizedBox(height: 8),
              _ActionButton(
                icon: Icons.close,
                bgColor: const Color(0xFFFFF1F2),
                iconColor: const Color(0xFFEF4444),
                borderColor: const Color(0xFFFFE4E6),
                onTap: () => _rejectVerification(verification['id']),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── View All Button ────────────────────────────────────────────────────────

  Widget _buildViewAllButton() {
    return Center(
      child: TextButton(
        onPressed: () {},
        child: const Text(
          'View All Verifications',
          style: TextStyle(
            color: _primary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatData {
  final IconData? icon;
  final String label;
  final String value;
  const _StatData({this.icon, required this.label, required this.value});
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              if (data.icon != null) ...[
                Icon(data.icon, size: 14, color: const Color(0xFF6B7280)),
                const SizedBox(width: 4),
              ],
              Text(
                data.label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  const _MiniStat({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: valueColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 14),
      ),
    );
  }
}
