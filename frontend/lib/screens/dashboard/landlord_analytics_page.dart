import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection; // <--- Fixed Import
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:property_app/widgets/onboarding_bottom_sheet.dart';
import 'package:property_app/session/onboarding_prefs.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/services/analytics/analytics_service.dart';
import 'landlord_dashboard_service.dart';

// ─── Landlord Design System Constants ─────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981); // Emerald Green for Landlord Theme

class LandlordAnalyticsPage extends StatefulWidget {
  const LandlordAnalyticsPage({super.key});

  @override
  State<LandlordAnalyticsPage> createState() => _LandlordAnalyticsPageState();
}

class _LandlordAnalyticsPageState extends State<LandlordAnalyticsPage> {
  String _selectedFilter = 'This Week';
  final List<String> _filters = ['This Week', 'Last 28 Days'];
  bool _isLoading = true;

  Offset? _chartTouchPosition; // Tracks user interaction on the graph

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
            _overview['chartData'] ??= <double>[];
          }
          _metrics = data['metrics'] != null ? Map<String, String>.from(data['metrics']) : _metrics;
          _topProperties = List<Map<String, dynamic>>.from(data['topProperties'] ?? []);
          _funnelSteps = List<Map<String, dynamic>>.from(data['funnel'] ?? []);
          _photoPerformance = List<Map<String, dynamic>>.from(data['photoPerformance'] ?? []);
          _insight = data['insight'];
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load analytics: ${e.toString()}')),
      );
    }
  }

  // Generates X-axis date labels based on the data length
  List<String> _generateXLabels(int dataLength) {
    List<String> labels = [];
    final now = DateTime.now();
    for (int i = 0; i < dataLength; i++) {
      final date = now.subtract(Duration(days: dataLength - 1 - i));
      if (dataLength <= 7) {
        labels.add(DateFormat('E').format(date)); // Mon, Tue, etc.
      } else {
        // For larger ranges, show label periodically
        if (i == 0 || i == dataLength - 1 || i % 7 == 0) {
          labels.add(DateFormat('MMM d').format(date)); // Aug 10, Aug 17, etc.
        } else {
          labels.add('');
        }
      }
    }
    return labels;
  }

  // ─── UI BUILDERS ─────────────────────────────────────────────────────────────

  Widget _buildCardWrapper({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildShimmerChart() {
    return _buildCardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
            child: Container(height: 36, width: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
          ),
          const SizedBox(height: 8),
          Shimmer.fromColors(
            baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
            child: Container(height: 16, width: 180, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
          ),
          const SizedBox(height: 32),
          Shimmer.fromColors(
            baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
            child: Container(height: 200, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: List.generate(4, (index) => Shimmer.fromColors(
        baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
        child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
      )),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _dark,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─── Custom Header ───
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: const Icon(PhosphorIconsRegular.caretLeft, color: _dark, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Analytics',
                    style: GoogleFonts.poppins(
                      color: _dark,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                color: _green,
                backgroundColor: _surface,
                onRefresh: _fetchAnalytics,
                child: ListView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).padding.bottom + 48),
                  children: [
                    // ─── Header & Filter ───
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Profile Views',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _grey.withOpacity(0.2)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedFilter,
                              icon: const Icon(PhosphorIconsRegular.caretDown, color: _dark, size: 16),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _dark,
                              ),
                              dropdownColor: _surface,
                              borderRadius: BorderRadius.circular(16),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedFilter = newValue;
                                    _fetchAnalytics();
                                  });
                                }
                              },
                              items: _filters.map<DropdownMenuItem<String>>((String value) {
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

                    // ─── Line Chart Section ───
                    if (_isLoading)
                      _buildShimmerChart()
                    else
                      _buildCardWrapper(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _overview['totalViews'],
                              style: GoogleFonts.poppins(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: _dark,
                                height: 1.1,
                                letterSpacing: -1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(color: _green.withOpacity(0.1), shape: BoxShape.circle),
                                  child: const Icon(PhosphorIconsBold.trendUp, color: _green, size: 12),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_overview['growth']} vs previous period',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            
                            // ─── INTERACTIVE CHART ───
                            SizedBox(
                              height: 200, // Increased height to fit axes comfortably
                              width: double.infinity,
                              child: _overview['chartData'].isEmpty
                                  ? Center(
                                      child: Text(
                                        'No traffic data for this period',
                                        style: GoogleFonts.poppins(color: _grey, fontSize: 13),
                                      ),
                                    )
                                  : GestureDetector(
                                      onPanDown: (details) => setState(() => _chartTouchPosition = details.localPosition),
                                      onPanUpdate: (details) => setState(() => _chartTouchPosition = details.localPosition),
                                      onPanEnd: (_) => setState(() => _chartTouchPosition = null),
                                      onPanCancel: () => setState(() => _chartTouchPosition = null),
                                      child: CustomPaint(
                                        painter: _InteractiveLineChartPainter(
                                          data: (_overview['chartData'] as List).map((e) => (e as num).toDouble()).toList(),
                                          xLabels: _generateXLabels((_overview['chartData'] as List).length),
                                          lineColor: _green,
                                          gradientColor: _green.withOpacity(0.15),
                                          touchPosition: _chartTouchPosition,
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 40),

                    // ─── Engagement Metrics Grid ───
                    Text(
                      'Engagement Metrics',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      _buildShimmerGrid()
                    else
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.3,
                        children: [
                          _buildStatCard('Unique Viewers', _metrics['uniqueViewers']!, PhosphorIconsFill.users, const Color(0xFF3B82F6)),
                          _buildStatCard('Saves', _metrics['saves']!, PhosphorIconsFill.heart, const Color(0xFFEC4899)),
                          _buildStatCard('Shares', _metrics['shares']!, PhosphorIconsFill.shareNetwork, const Color(0xFF8B5CF6)),
                          _buildStatCard('Avg. CTR', _metrics['avgCtr']!, PhosphorIconsFill.cursorClick, _green),
                        ],
                      ),
                    const SizedBox(height: 40),

                    // ─── Monetization Insights (Boost) ───
                    if (!_isLoading && _insight != null) ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2), // Soft Red Tint
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.5), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(PhosphorIconsFill.warningCircle, color: Color(0xFFEF4444), size: 24),
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
                                color: const Color(0xFF991B1B),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                                ),
                                child: Text(
                                  'Boost Listing',
                                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],

                    // ─── Product Intelligence (Photos) ───
                    Text(
                      'Product Intelligence',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCardWrapper(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Photo Performance',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _dark,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_isLoading)
                             const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(color: _green)))
                          else if (_photoPerformance.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: Text('No photo data available', style: GoogleFonts.poppins(fontSize: 13, color: _grey))),
                            )
                          else
                            ..._photoPerformance.map((p) => _buildPhotoMetricRow(
                                  p['label'],
                                  p['engagement'],
                                  p['image'],
                                  Color(p['color'] ?? 0xFF10B981),
                                )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ─── Conversion Funnel ───
                    Text(
                      'Conversion Funnel',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCardWrapper(
                      child: _isLoading 
                          ? const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(color: _green)))
                          : _funnelSteps.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: Text('Insufficient funnel data', style: GoogleFonts.poppins(color: _grey))),
                            )
                          : Column(
                              children: _funnelSteps.map((step) {
                                final pctRaw = step['percentage'];
                                final double pct = pctRaw is num ? pctRaw.toDouble() : 0.0;
                                return _buildFunnelStep(step['label'].toString(), step['value'].toString(), pct);
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 40),

                    // ─── Top Properties List ───
                    Text(
                      'Top Performing Properties',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_isLoading)
                      Column(
                        children: List.generate(2, (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Shimmer.fromColors(
                            baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
                            child: Container(height: 88, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
                          ),
                        )),
                      )
                    else if (_topProperties.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text('No properties to display yet.', style: GoogleFonts.poppins(color: _grey)),
                        ),
                      )
                    else
                      ..._topProperties.map((prop) => _buildTopPropertyCard(
                            prop['name'],
                            prop['location'],
                            prop['image'],
                            prop['views'],
                          )),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoMetricRow(String label, String value, String? imageUrl, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: buildPropertyImage(
                imageUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorPlaceholder: Container(width: 48, height: 48, color: _grey.withOpacity(0.1), child: const Icon(PhosphorIconsRegular.image, color: _grey, size: 20)),
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _dark,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
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
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _grey,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: _grey.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(_green),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPropertyCard(String name, String location, String image, String views) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              image,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorPlaceholder: Container(
                width: 72,
                height: 72,
                color: _grey.withOpacity(0.1),
                child: const Icon(PhosphorIconsRegular.house, color: _grey, size: 28),
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
                    color: _dark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  location,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(PhosphorIconsRegular.eye, size: 16, color: _green),
                const SizedBox(width: 6),
                Text(
                  views,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom Interactive Chart Painter ─────────────────────────────────────────

class _InteractiveLineChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> xLabels;
  final Color lineColor;
  final Color gradientColor;
  final Offset? touchPosition;

  _InteractiveLineChartPainter({
    required this.data,
    required this.xLabels,
    required this.lineColor,
    required this.gradientColor,
    this.touchPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return; 

    final double maxData = data.reduce((a, b) => a > b ? a : b);
    final double minData = data.reduce((a, b) => a < b ? a : b);

    // Padding for axes
    final double yAxisWidth = 32.0; 
    final double xAxisHeight = 24.0;
    
    final double chartWidth = size.width - yAxisWidth;
    final double chartHeight = size.height - xAxisHeight;

    // ─── Draw Y-Axis (Values & Grid Lines) ───
    final textStyle = GoogleFonts.poppins(color: _grey, fontSize: 10, fontWeight: FontWeight.w500);
    final gridPaint = Paint()
      ..color = _grey.withOpacity(0.2)
      ..strokeWidth = 1;

    // We draw 3 horizontal lines: Max, Mid, Min
    for (int i = 0; i <= 2; i++) {
      final double val = maxData - (i * ((maxData - minData) / 2));
      final double y = (i * (chartHeight / 2));

      // Draw Grid Line
      canvas.drawLine(Offset(yAxisWidth, y), Offset(size.width, y), gridPaint);

      // Draw Value Text
      final tp = TextPainter(
        text: TextSpan(text: val.toInt().toString(), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(yAxisWidth - tp.width - 8, y - (tp.height / 2)));
    }

    // ─── Calculate Plot Points ───
    final List<Offset> points = [];
    final double widthStep = chartWidth / (data.length - 1);
    final double heightRange = maxData - minData == 0 ? 1 : maxData - minData;

    for (int i = 0; i < data.length; i++) {
      final double x = yAxisWidth + (i * widthStep);
      final double normalizedY = (data[i] - minData) / heightRange;
      
      // Invert Y axis since canvas 0,0 is top-left
      final double y = chartHeight - (normalizedY * chartHeight);
      points.add(Offset(x, y));

      // ─── Draw X-Axis (Dates) ───
      if (xLabels.length > i && xLabels[i].isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(text: xLabels[i], style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - (tp.width / 2), size.height - xAxisHeight + 8));
      }
    }

    // ─── Draw Smooth Cubic Bezier Line ───
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);
      path.cubicTo(
        controlPoint1.dx, controlPoint1.dy,
        controlPoint2.dx, controlPoint2.dy,
        p2.dx, p2.dy,
      );
    }

    // ─── Draw Gradient Fill Underneath ───
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, chartHeight)
      ..lineTo(points.first.dx, chartHeight)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [gradientColor, gradientColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(yAxisWidth, 0, chartWidth, chartHeight));

    canvas.drawPath(fillPath, fillPaint);

    // ─── Draw the Actual Line ───
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // ─── Draw Interactivity (Tooltip & Points) ───
    final dotPaint = Paint()..color = Colors.white;
    final dotBorderPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // Draw static points
    for (var point in points) {
      canvas.drawCircle(point, 4.0, dotPaint);
      canvas.drawCircle(point, 4.0, dotBorderPaint);
    }

    // ─── Draw Tooltip ───
    if (touchPosition != null) {
      // 1. Find closest point on X-axis
      Offset closestPoint = points.first;
      double minDistance = (points.first.dx - touchPosition!.dx).abs();
      int closestIndex = 0;

      for (int i = 1; i < points.length; i++) {
        final double dist = (points[i].dx - touchPosition!.dx).abs();
        if (dist < minDistance) {
          minDistance = dist;
          closestPoint = points[i];
          closestIndex = i;
        }
      }

      // 2. Draw vertical tracking line
      final vLinePaint = Paint()
        ..color = lineColor.withOpacity(0.4)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(closestPoint.dx, 0), Offset(closestPoint.dx, chartHeight), vLinePaint);

      // 3. Highlight the specific circle
      canvas.drawCircle(closestPoint, 6, dotPaint);
      canvas.drawCircle(closestPoint, 6, Paint()..color = lineColor..strokeWidth = 3.5..style = PaintingStyle.stroke);

      // 4. Draw Tooltip Box
      final String tooltipValue = data[closestIndex].toInt().toString();
      final String tooltipLabel = xLabels.length > closestIndex ? xLabels[closestIndex] : '';

      final tooltipTp = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(text: '$tooltipValue Views\n', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13, height: 1.2)),
            if (tooltipLabel.isNotEmpty)
              TextSpan(text: tooltipLabel, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
          ]
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      final double tooltipWidth = tooltipTp.width + 24;
      final double tooltipHeight = tooltipTp.height + 16;

      double tooltipX = closestPoint.dx - (tooltipWidth / 2);
      double tooltipY = closestPoint.dy - tooltipHeight - 16;

      // Keep tooltip inside canvas bounds
      if (tooltipX < yAxisWidth) tooltipX = yAxisWidth;
      if (tooltipX + tooltipWidth > size.width) tooltipX = size.width - tooltipWidth;
      if (tooltipY < 0) tooltipY = closestPoint.dy + 16; // Flip below point if too high

      final RRect tooltipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tooltipX, tooltipY, tooltipWidth, tooltipHeight),
        const Radius.circular(12),
      );

      // Tooltip shadow
      canvas.drawRRect(tooltipRect.shift(const Offset(0, 4)), Paint()..color = Colors.black.withOpacity(0.15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      // Tooltip body
      canvas.drawRRect(tooltipRect, Paint()..color = _dark);
      
      tooltipTp.paint(canvas, Offset(tooltipX + 12, tooltipY + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _InteractiveLineChartPainter oldDelegate) {
    return oldDelegate.touchPosition != touchPosition || oldDelegate.data != data;
  }
}