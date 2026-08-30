import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:property_app/screens/dashboard/landlord_notifications_page.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/services/properties_api.dart';
import 'package:property_app/utils/api_result.dart';
import 'package:property_app/utils/property_mapper.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/analytics/analytics_service.dart';
import 'package:property_app/widgets/onboarding_bottom_sheet.dart';
import 'package:property_app/session/onboarding_prefs.dart';
import 'landlord_dashboard_service.dart';
import 'landlord_analytics_page.dart';

// ─── Landlord Design System Constants ─────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981); // Emerald Green for Landlord Theme

class LandlordOverviewPage extends StatefulWidget {
  final VoidCallback? onViewAllProperties;
  const LandlordOverviewPage({super.key, this.onViewAllProperties});

  @override
  State<LandlordOverviewPage> createState() => _LandlordOverviewPageState();
}

class _LandlordOverviewPageState extends State<LandlordOverviewPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _properties = [];
  Map<String, String> _metrics = {
    'totalViews': '0',
    'viewsGrowth': '+0%',
    'totalBookings': '0',
    'bookingsGrowth': '+0%',
    'occupancyRate': '0%',
    'occupancyGrowth': '+0%',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!OnboardingPrefs.hasSeen('landlordOverviewSeen')) {
        OnboardingBottomSheet.show(
          context: context,
          imagePath: 'assets/images/home_onboarding.png',
          title: 'Welcome to your Dashboard',
          subtitle: 'Track your total views, manage properties, and monitor your occupancy rate all in one place.',
          ctaText: 'Get Started',
        ).then((_) => OnboardingPrefs.markAsSeen('landlordOverviewSeen'));
      }
    });
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final results = await Future.wait([
        PropertiesApi.getLandlordProperties(),
        LandlordDashboardService.getLandlordOverview('This Week'),
      ]);
      
      if (!mounted) return;
      
      setState(() {
        _properties = results[0] as List<Map<String, dynamic>>;
        final analyticsData = results[1] as Map<String, dynamic>?;

        if (analyticsData != null) {
          _metrics = {
            'totalViews': analyticsData['overview']?['totalViews']?.toString() ?? '0',
            'viewsGrowth': analyticsData['overview']?['growth']?.toString() ?? '0%',
            'totalBookings': analyticsData['metrics']?['totalBookings']?.toString() ?? '0',
            'bookingsGrowth': analyticsData['metrics']?['bookingsGrowth']?.toString() ?? '+0%',
            'occupancyRate': analyticsData['metrics']?['occupancyRate']?.toString() ?? '0%',
            'occupancyGrowth': analyticsData['metrics']?['occupancyGrowth']?.toString() ?? '+0%',
          };
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ApiResult.mapError(e);
        _isLoading = false;
      });
    }
  }

  // ─── UI BUILDERS ─────────────────────────────────────────────────────────────

  Widget _buildShimmerStats() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.25,
      children: List.generate(4, (index) => Shimmer.fromColors(
        baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
        child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
      )),
    );
  }

  Widget _buildShimmerProperties() {
    return Column(
      children: List.generate(2, (index) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
          child: Container(height: 88, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _green,
          backgroundColor: _surface,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 130),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── HEADER ───
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good Morning,',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _grey,
                            ),
                          ),
                          Text(
                            '${AppSession.displayName.split(' ')[0]} 👋',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: _dark,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LandlordNotificationsPage())),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: _grey.withOpacity(0.1)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Stack(
                          children: [
                            const Icon(PhosphorIconsRegular.bell, color: _dark, size: 24),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444), // Red notification dot
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ─── ERROR STATE ───
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.5))),
                    child: Column(
                      children: [
                        const Icon(PhosphorIconsRegular.warningCircle, color: Color(0xFFEF4444), size: 48),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: const Color(0xFF991B1B), fontWeight: FontWeight.w500)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), elevation: 0),
                          child: Text('Retry', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // ─── INTRO TEXT ───
                Text(
                  'Here\'s what\'s happening\nwith your properties',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                    height: 1.3,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 24),

                // ─── STATS GRID ───
                _isLoading
                    ? _buildShimmerStats()
                    : GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.25,
                        children: [
                          _buildStatCard('Properties', _properties.length.toString(), '+0', true),
                          _buildStatCard('Bookings', _metrics['totalBookings']!, _metrics['bookingsGrowth']!, !_metrics['bookingsGrowth']!.startsWith('-')),
                          _buildStatCard('Views', _metrics['totalViews']!, _metrics['viewsGrowth']!, !_metrics['viewsGrowth']!.startsWith('-')),
                          _buildStatCard('Occupancy', _metrics['occupancyRate']!, _metrics['occupancyGrowth']!, !_metrics['occupancyGrowth']!.startsWith('-')),
                        ],
                      ),
                const SizedBox(height: 24),

                // ─── VIEW ANALYTICS BUTTON ───
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LandlordAnalyticsPage())),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _surface,
                      foregroundColor: _dark,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: _grey.withOpacity(0.2)),
                      ),
                    ),
                    child: Text(
                      'View Analytics',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _dark,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // ─── RECENT PROPERTIES ───
                Text(
                  _isLoading ? 'Your Properties' : (_properties.isEmpty ? 'No Properties Yet' : 'Your Properties'),
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                
                if (_isLoading)
                  _buildShimmerProperties()
                else if (_properties.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32.0),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(color: _grey.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(PhosphorIconsRegular.houseLine, size: 48, color: _grey),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No properties listed yet',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _dark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add your first property to start earning.',
                            style: GoogleFonts.poppins(fontSize: 14, color: _grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._properties.take(3).map((property) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _buildPropertyCard(property),
                    );
                  }),
                  
                const SizedBox(height: 16),

                // ─── VIEW ALL PROPERTIES BUTTON ───
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: widget.onViewAllProperties,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _dark, // High contrast primary CTA
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(
                      'View All Properties',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String change, bool isPositive) {
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _grey,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPositive ? _green.withOpacity(0.1) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  change,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isPositive ? _green : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> property) {
    final imageUrl = mapApiProperty(property).image;
    final title = property['title'] as String? ?? 'Untitled';
    final city = property['city'] as String? ?? 'Unknown';
    final priceValue = property['price'];
    final price = priceValue is String ? double.tryParse(priceValue) ?? 0 : (priceValue as num? ?? 0);
    final rating = (double.tryParse(property['average_rating']?.toString() ?? '0') ?? 0.0).toDouble();
    final reviews = int.tryParse(property['review_count']?.toString() ?? '0') ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: buildPropertyImage(
              imageUrl,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorPlaceholder: Container(
                width: 64,
                height: 64,
                color: _grey.withOpacity(0.1),
                child: const Icon(PhosphorIconsRegular.image, color: _grey),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  city,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _grey,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Ksh. ${price.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const Spacer(),
                    if (reviews > 0) ...[
                      const Icon(PhosphorIconsFill.star, size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($reviews)',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(PhosphorIconsRegular.caretRight, color: _grey, size: 20),
        ],
      ),
    );
  }
}