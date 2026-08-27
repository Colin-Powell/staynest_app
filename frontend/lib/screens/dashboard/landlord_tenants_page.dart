import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/widgets/property_image.dart';

// --- Theme Constants ---
const Color _landlordPrimary = Color(0xFF059669);
const Color _textDark = Color(0xFF111827);
const Color _textLight = Color(0xFF9CA3AF);

// ─── TENANTS LIST PAGE ───────────────────────────────────────────────────────

class LandlordTenantsPage extends StatefulWidget {
  const LandlordTenantsPage({super.key});

  @override
  State<LandlordTenantsPage> createState() => _LandlordTenantsPageState();
}

class _LandlordTenantsPageState extends State<LandlordTenantsPage> {
  List<Map<String, dynamic>> _tenants = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TODO: Implement API call to fetch tenants
      // For now, show empty state
      setState(() {
        _tenants = [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load tenants: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _buildBackgroundGradient(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                _buildSearchAndFilter(),
                Expanded(
                  child: _buildTenantsList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _landlordPrimary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTenants,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_tenants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 48, color: _textLight),
            const SizedBox(height: 16),
            Text(
              'No tenants yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tenants will appear here once properties are rented',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _textLight,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
      physics: const BouncingScrollPhysics(),
      itemCount: _tenants.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _TenantListTile(tenant: _tenants[index]);
      },
    );
  }

  Widget _buildBackgroundGradient() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFFFFFFFF).withOpacity(0.5), Colors.white],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const _GlassIconButton(icon: Icons.arrow_back),
          ),
          const SizedBox(width: 20),
          Text(
            'My Tenants',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      child: Row(
        children: [
          Expanded(
            child: _GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              borderRadius: BorderRadius.circular(16),
              opacity: 0.4,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search tenants...',
                  hintStyle:
                      GoogleFonts.poppins(color: _textLight, fontSize: 14),
                  border: InputBorder.none,
                  icon: const Icon(Icons.search, size: 20, color: _textDark),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _GlassIconButton(icon: PhosphorIcons.slidersHorizontal()),
        ],
      ),
    );
  }
}

class _TenantListTile extends StatelessWidget {
  final Map<String, dynamic> tenant;
  const _TenantListTile({required this.tenant});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TenantDetailsPage(tenant: tenant)),
      ),
      child: _GlassContainer(
        padding: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(24),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 60,
                height: 60,
                child: buildPropertyImage(tenant['photo'], fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tenant['name'],
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  Text(
                    '${tenant['apartment']} • ${tenant['property']}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _textLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(PhosphorIcons.caretRight(),
                color: _textLight.withOpacity(0.5), size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── TENANT DETAILS PAGE ─────────────────────────────────────────────────────

class TenantDetailsPage extends StatelessWidget {
  final Map<String, dynamic> tenant;
  const TenantDetailsPage({super.key, required this.tenant});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFFFFFF).withOpacity(0.5),
                    Colors.white
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const _GlassIconButton(icon: Icons.arrow_back),
                      ),
                      _GlassIconButton(icon: PhosphorIcons.pencilLine()),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildProfileHeader(),
                  const SizedBox(height: 32),
                  _buildQuickActions(),
                  const SizedBox(height: 40),
                  _buildInfoSection('Lease Information', [
                    const _DetailRow(
                        label: 'Contract Period', value: '12 Months'),
                    const _DetailRow(label: 'Start Date', value: '01 Jan 2024'),
                    const _DetailRow(
                        label: 'Monthly Rent', value: 'Ksh. 45,000'),
                    const _DetailRow(label: 'Security Deposit', value: 'Paid'),
                  ]),
                  const SizedBox(height: 24),
                  _buildInfoSection('Contact Details', [
                    _DetailRow(label: 'Phone', value: tenant['phone']),
                    _DetailRow(label: 'Email', value: tenant['email']),
                  ]),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _landlordPrimary, width: 3),
          ),
          child: ClipOval(
            child: SizedBox(
              width: 120,
              height: 120,
              child: buildPropertyImage(tenant['photo'], fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          tenant['name'],
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _textDark,
          ),
        ),
        Text(
          'Tenant at ${tenant['property']}',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _landlordPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CircleAction(
            icon: PhosphorIcons.phone(PhosphorIconsStyle.fill), label: 'Call'),
        const SizedBox(width: 32),
        _CircleAction(
            icon: PhosphorIcons.chatCircle(PhosphorIconsStyle.fill),
            label: 'Chat'),
        const SizedBox(width: 32),
        _CircleAction(
            icon: PhosphorIcons.envelope(PhosphorIconsStyle.fill),
            label: 'Mail'),
      ],
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w700, color: _textDark),
        ),
        const SizedBox(height: 16),
        _GlassContainer(
          padding: const EdgeInsets.all(24),
          borderRadius: BorderRadius.circular(28),
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ─── REUSABLE UI ENGINE ──────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  color: _textLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, fontSize: 14, color: _textDark)),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final String label;
  const _CircleAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GlassIconButton(
            icon: icon, size: 60, iconSize: 26, color: _landlordPrimary),
        const SizedBox(height: 10),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600, color: _textDark)),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final double size, iconSize;
  final Color? color;
  const _GlassIconButton(
      {required this.icon, this.size = 46, this.iconSize = 22, this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
          ),
          child: Icon(icon, color: color ?? _textDark, size: iconSize),
        ),
      ),
    );
  }
}

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double opacity;

  const _GlassContainer(
      {required this.child,
      required this.padding,
      required this.borderRadius,
      this.opacity = 0.55});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: borderRadius,
            border: Border.all(color: Colors.white.withOpacity(0.7)),
          ),
          child: child,
        ),
      ),
    );
  }
}
