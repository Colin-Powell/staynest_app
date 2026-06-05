import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/widgets/property_image.dart';

class LandlordPropertyManagementPage extends StatefulWidget {
  final Map<String, dynamic> property;

  const LandlordPropertyManagementPage({super.key, required this.property});

  @override
  State<LandlordPropertyManagementPage> createState() =>
      _LandlordPropertyManagementPageState();
}

class _LandlordPropertyManagementPageState
    extends State<LandlordPropertyManagementPage> {
  static const Color primaryGreen = Color(0xFF059669);
  static const Color textDark = Color(0xFF111827);
  static const Color textLight = Color(0xFF6B7280);

  late Map<String, dynamic> _property;

  @override
  void initState() {
    super.initState();
    _property = Map<String, dynamic>.from(widget.property);
  }

  // --- Success Modal Engine ---
  void _showActionSuccess(String message) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFD1FAE5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: primaryGreen, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                'Success!',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: textLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: textDark,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Continue',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            // 1. Immersive Header Image (Fills viewport top)
            SizedBox(
              width: double.infinity,
              height: 440, // Increased height for better viewport fill
              child: Stack(
                fit: StackFit.expand,
                children: [
                  buildPropertyImage(
                    (_property['image_url'] ?? _property['image'] ?? '') as String,
                    fit: BoxFit.cover,
                  ),
                  // Top Gradient for Navigation Legibility
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [Colors.black38, Colors.transparent],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Floating Content Detail Sheet (Overlaps the image)
            Container(
              margin: const EdgeInsets.only(top: 400), // Overlap offset
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -10),
                  )
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderSection(),
                    const SizedBox(height: 32),
                    
                    // Simple Stats Row (No containers)
                    _buildStatsRow(),
                    const Divider(height: 60, color: Color(0xFFF3F4F6)),
                    
                    // Management Action Links (No containers)
                    _buildManagementLinks(),
                    const SizedBox(height: 48),
                    
                    _buildSupportMenu(),
                    const SizedBox(height: 60),
                    
                    // Primary Action
                    ElevatedButton(
                      onPressed: () => _showActionSuccess(
                          'Property status has been successfully updated to Rented.'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        minimumSize: const Size(double.infinity, 64),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Confirm Rented Status',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Danger Zone
                    Center(
                      child: TextButton(
                        onPressed: () {},
                        child: Text(
                          'Remove Property from Portfolio',
                          style: GoogleFonts.poppins(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Navigation Controls (No background circles)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                    IconButton(
                      icon: Icon(PhosphorIcons.shareNetwork(), color: Colors.white, size: 26),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _property['title'] ?? 'Property Name',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: textDark,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _StatusBadge(status: (_property['status'] ?? 'Available') as String),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(PhosphorIcons.mapPin(), size: 18, color: textLight),
            const SizedBox(width: 6),
            Text(
              (_property['city'] ?? _property['location'] ?? 'Location').toString(),
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _SimpleStat(
          label: 'Total Views',
          value: (_property['views'] ?? '0').toString(),
          icon: PhosphorIcons.eye(),
        ),
        const SizedBox(width: 48),
        _SimpleStat(
          label: 'Engagement',
          value: (_property['likes'] ?? '0').toString(),
          icon: PhosphorIcons.heart(),
        ),
      ],
    );
  }

  Widget _buildManagementLinks() {
    return Row(
      children: [
        _ActionLink(
          label: 'Edit Listing',
          icon: PhosphorIcons.pencilLine(),
          onTap: () => Navigator.pushNamed(context, '/list_property'),
        ),
        const SizedBox(width: 40),
        _ActionLink(
          label: 'Tenants List',
          icon: PhosphorIcons.usersThree(),
          onTap: () => Navigator.pushNamed(context, '/landlord_tenants'),
        ),
      ],
    );
  }

  Widget _buildSupportMenu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Management Support',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textDark,
          ),
        ),
        const SizedBox(height: 24),
        _SupportRow(
          title: 'Boost Visibility',
          subtitle: 'Promote this listing to top results',
          icon: PhosphorIcons.megaphone(),
        ),
        _SupportRow(
          title: 'Management FAQs',
          subtitle: 'Help with legal and tenant issues',
          icon: PhosphorIcons.bookOpenText(),
        ),
        _SupportRow(
          title: 'Direct Support',
          subtitle: 'Talk to our portfolio experts',
          icon: PhosphorIcons.headset(),
        ),
      ],
    );
  }
}

// ─── INTERNAL COMPONENTS ─────────────────────────────────────────────────────

class _SimpleStat extends StatelessWidget {
  final String label, value;
  final IconData icon;

  const _SimpleStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _LandlordPropertyManagementPageState.primaryGreen, size: 26),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _LandlordPropertyManagementPageState.textDark,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _LandlordPropertyManagementPageState.textLight,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionLink extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionLink({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 22, color: _LandlordPropertyManagementPageState.textDark),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _LandlordPropertyManagementPageState.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportRow extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;

  const _SupportRow({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Row(
        children: [
          Icon(icon, color: _LandlordPropertyManagementPageState.textDark, size: 26),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _LandlordPropertyManagementPageState.textDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: _LandlordPropertyManagementPageState.textLight,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20, color: _LandlordPropertyManagementPageState.textLight),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _LandlordPropertyManagementPageState.primaryGreen,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}