// lib/screens/dashboard/landlord_analytics_page.dart
import 'package:flutter/material.dart';
import 'package:property_app/widgets/onboarding_bottom_sheet.dart';
import 'package:property_app/session/onboarding_prefs.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/widgets/property_image.dart';
import 'landlord_dashboard_service.dart';
import 'package:property_app/services/analytics/analytics_service.dart';

import 'dashboard_widgets.dart';

class LandlordAnalyticsPage extends StatefulWidget {
  const LandlordAnalyticsPage({super.key});

  @override
  State<LandlordAnalyticsPage> createState() => _LandlordAnalyticsPageState();
}

class _LandlordAnalyticsPageState extends State<LandlordAnalyticsPage> {
  String _selectedFilter = 'This Week';
  final List<String> _filters = ['This Week', 'Last 28 Days'];
  bool _isLoading = true;

  // State variables for analytics
  Map<String, dynamic> _overview = {
    'totalViews': '0',
    'growth': '0%',
    'chartData': <double>[],
  };

  Map<String, String> _metrics = {
    'uniqueViewers': '0',
    'saves': '0',
    'shares': '0',
    'avgCtr': '0%',
  };

  List<Map<String, dynamic>> _topProperties = [];
  List<Map<String, dynamic>> _funnelSteps = [];
  List<Map<String, dynamic>> _photoPerformance = [];
  Map<String, dynamic>? _insight;

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!OnboardingPrefs.hasSeen('landlordAnalyticsSeen')) {
        OnboardingBottomSheet.show(
          context: context,
          imagePath: 'assets/images/home_onboarding.png',
          title: 'Insights & Analytics',
          subtitle: 'Dive deep into your portfolio performance, see engagement rates, and track conversion funnel metrics.',
          ctaText: 'View Insights',
          ).then((_) => OnboardingPrefs.markAsSeen('landlordAnalyticsSeen'));
      }
    });
  }

  Future<void> _fetchAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final data = await LandlordDashboardService.getLandlordOverview(_selectedFilter);

      if (!mounted) return;

      setState(() {
        if (data != null) {
          if (data['overview'] != null) {
            _overview = {
              ..._overview,
              ...Map<String, dynamic>.from(data['overview']),
            };
            // Ensure chartData is a valid list to prevent crashes in build()
            _overview['chartData'] ??= <double>[];
          }
          _metrics = data['metrics'] != null
              ? Map<String, String>.from(data['metrics'])
              : _metrics;
          _topProperties =
              List<Map<String, dynamic>>.from(data['topProperties'] ?? []);
          _funnelSteps = List<Map<String, dynamic>>.from(data['funnel'] ?? []);
          _photoPerformance =
              List<Map<String, dynamic>>.from(data['photoPerformance'] ?? []);
          _insight = data['insight'];
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load analytics: ${e.toString()}'),
        ),
      );
    }
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Gradient matching the portal
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF7FDF9),
                  Color(0xFFFFFFFF),
                  Color(0xFFD4EFE1)
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Custom AppBar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.arrow_back,
                              color: Color(0xFF111827), size: 28),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Analytics',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF111827),
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    children: [
                      // --- HEADER & FILTER ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Profile Views',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          GlassContainer(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            borderRadius: BorderRadius.circular(12),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedFilter,
                                icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Color(0xFF6B7280)),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF111827),
                                ),
                                dropdownColor: Colors.white,
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedFilter = newValue;
                                      _fetchAnalytics();
                                    });
                                  }
                                },
                                items: _filters.map<DropdownMenuItem<String>>(
                                    (String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      if (_isLoading)
                        const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF059669)))
                      else ...[
                        // --- CUSTOM LINE CHART USING GLASS CONTAINER ---
                        GlassContainer(
                          padding: const EdgeInsets.all(24),
                          borderRadius: BorderRadius.circular(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _overview['totalViews'],
                                style: GoogleFonts.poppins(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF111827),
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                      PhosphorIcons.trendUp(
                                          PhosphorIconsStyle.bold),
                                      color: const Color(0xFF059669),
                                      size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_overview['growth']} vs previous period',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              // The Line Graph
                              SizedBox(
                                height: 160,
                                width: double.infinity,
                                child: _overview['chartData'].isEmpty
                                    ? Center(
                                        child: Text(
                                            'No traffic data for this period',
                                            style: GoogleFonts.poppins(
                                                color: const Color(0xFF6B7280),
                                                fontSize: 13)))
                                    : CustomPaint(
                                        painter: _SmoothLineChartPainter(
                                          data: (_overview['chartData'] as List)
                                              .map((e) => (e as num).toDouble())
                                              .toList(),
                                          lineColor: const Color(0xFF059669),
                                          gradientColor: const Color(0xFF059669)
                                              .withOpacity(0.25),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        // --- 2. ENGAGEMENT METRICS GRID ---
                        Text(
                          'Engagement Metrics',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.3,
                          children: [
                            _buildStatCard(
                                'Unique Viewers',
                                _metrics['uniqueViewers']!,
                                PhosphorIcons.users(),
                                const Color(0xFF3B82F6)),
                            _buildStatCard('Saves', _metrics['saves']!,
                                PhosphorIcons.heart(), const Color(0xFFEC4899)),
                            _buildStatCard(
                                'Shares',
                                _metrics['shares']!,
                                PhosphorIcons.shareNetwork(),
                                const Color(0xFF8B5CF6)),
                            _buildStatCard(
                                'Avg. CTR',
                                _metrics['avgCtr']!,
                                PhosphorIcons.cursorClick(),
                                const Color(0xFF10B981)),
                          ],
                        ),
                        const SizedBox(height: 40),

                        if (_insight != null) ...[
                          // --- 3. MONETIZATION INSIGHTS (Boost) ---
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: const Color(0xFFFCA5A5), width: 1),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                        PhosphorIcons.warningCircle(
                                            PhosphorIconsStyle.fill),
                                        color: const Color(0xFFEF4444)),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Monetization Insight',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF991B1B),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _insight!['message'],
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: const Color(0xFF991B1B)),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF4444),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    child: Text(
                                      'Boost Listing',
                                      style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],

                        // --- 4. PRODUCT INTELLIGENCE (Photos) ---
                        Text(
                          'Product Intelligence',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 16),
                        GlassContainer(
                          padding: const EdgeInsets.all(20),
                          borderRadius: BorderRadius.circular(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Photo Performance',
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF111827)),
                              ),
                              const SizedBox(height: 12),
                              if (_photoPerformance.isEmpty)
                                Center(
                                    child: Text('No photo data',
                                        style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: const Color(0xFF6B7280))))
                              else
                                ..._photoPerformance.map((p) =>
                                    _buildPhotoMetricRow(
                                        p['label'],
                                        p['engagement'],
                                        p['image'],
                                        Color(p['color'] ?? 0xFF10B981))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        // --- 5. CONVERSION FUNNEL ---
                        Text(
                          'Conversion Funnel',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827)),
                        ),
                        const SizedBox(height: 16),
                        GlassContainer(
                          padding: const EdgeInsets.all(24),
                          borderRadius: BorderRadius.circular(24),
                          child: _funnelSteps.isEmpty
                              ? Center(
                                  child: Text('Insufficient funnel data',
                                      style: GoogleFonts.poppins(
                                          color: const Color(0xFF6B7280))))
                              : Column(
                                  children: _funnelSteps.map((step) {
                                    final pctRaw = step['percentage'];
                                    final double pct =
                                        pctRaw is num ? pctRaw.toDouble() : 0.0;
                                    return _buildFunnelStep(
                                      step['label'].toString(),
                                      step['value'].toString(),
                                      pct,
                                    );
                                  }).toList(),
                                ),
                        ),
                        const SizedBox(height: 40),

                        // --- TOP PROPERTIES LIST ---
                        Text(
                          'Top Performing Properties',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 16),

                        ..._topProperties.map((prop) => _buildTopPropertyCard(
                              prop['name'],
                              prop['location'],
                              prop['image'],
                              prop['views'],
                            )),
                      ], // End of loading check

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoMetricRow(
      String label, String value, String? imageUrl, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: buildPropertyImage(
                imageUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF4B5563))),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelStep(String label, String value, double percentage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4B5563))),
              Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827))),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPropertyCard(
      String name, String location, String image, String views) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        padding: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: buildPropertyImage(
                image,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorPlaceholder: Container(
                  width: 72,
                  height: 72,
                  color: const Color(0xFFE5E7EB),
                  child: Icon(PhosphorIcons.image(),
                      color: const Color(0xFF9CA3AF)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_rounded,
                      size: 16, color: Color(0xFF059669)),
                  const SizedBox(width: 6),
                  Text(
                    views,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Custom Cubic Bezier Line Chart Painter (Dependency Free) ──────────────
class _SmoothLineChartPainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final Color gradientColor;

  _SmoothLineChartPainter({
    required this.data,
    required this.lineColor,
    required this.gradientColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return; // Prevent division by zero crash if data is sparse

    final double maxData = data.reduce((a, b) => a > b ? a : b);
    final double minData = data.reduce((a, b) => a < b ? a : b);

    final List<Offset> points = [];
    final double widthStep = size.width / (data.length - 1);
    final double heightRange = maxData - minData == 0 ? 1 : maxData - minData;

    for (int i = 0; i < data.length; i++) {
      final double x = i * widthStep;
      // Invert Y axis because canvas draws from top to bottom
      final double normalizedY = (data[i] - minData) / heightRange;
      final double y = size.height -
          (normalizedY * (size.height * 0.8)) -
          (size.height * 0.1);
      points.add(Offset(x, y));
    }

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    // Draw Smooth Cubic Bezier Curves
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p2.dx,
        p2.dy,
      );
    }

    // 1. Draw the gradient fill under the line
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [gradientColor, gradientColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // 2. Draw the actual line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // 3. Draw dots on the points
    final dotPaint = Paint()..color = Colors.white;
    final dotBorderPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (var point in points) {
      canvas.drawCircle(point, 4.5, dotPaint);
      canvas.drawCircle(point, 4.5, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}