import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:property_app/widgets/onboarding_bottom_sheet.dart';
import 'package:property_app/session/onboarding_prefs.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/widgets/response_badge_animation.dart';
import 'package:property_app/utils/api_result.dart';
import 'landlord_dashboard_service.dart';
import 'boost_listing_modal.dart';

// ─── Landlord Design System Constants ─────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981);

// ─── CUSTOM PAINTER FOR HATCHED FUNNEL BAR ────────────────────────────────────
class HatchedPainter extends CustomPainter {
  final Color color;
  final double stripeWidth;
  final double gap;

  const HatchedPainter({
    required this.color,
    this.stripeWidth = 2.0,
    this.gap = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stripeWidth
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    for (double i = -size.height; i < size.width; i += (stripeWidth + gap)) {
      canvas.drawLine(
        Offset(i, size.height),
        Offset(i + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LandlordAnalyticsPage extends StatefulWidget {
  final String initialFilter;
  final ValueChanged<String>? onOpenProperty;

  const LandlordAnalyticsPage({
    super.key,
    this.initialFilter = 'This Week',
    this.onOpenProperty,
  });

  @override
  State<LandlordAnalyticsPage> createState() => _LandlordAnalyticsPageState();
}

class _LandlordAnalyticsPageState extends State<LandlordAnalyticsPage> {
  late String _selectedFilter;
  final List<String> _filters = [
    'This Week',
    'Last 28 Days',
    'Last 90 Days',
  ];
  bool _isLoading = true;
  String? _errorMessage;

  // Overview State
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
  Map<String, dynamic> _responseMetrics = const {};

  List<Map<String, dynamic>> _topProperties = [];
  List<Map<String, dynamic>> _funnelSteps = [];
  String _funnelDefinition =
      'Stage counts use the selected period and are not a sequential user journey.';
  List<Map<String, dynamic>> _photoPerformance = [];
  Map<String, dynamic>? _insight;

  // Advanced Deep Dive State
  int _selectedDeepDiveIndex = 0;
  final List<Map<String, dynamic>> _leads = const [];
  final List<Map<String, dynamic>> _schedules = const [];
  final List<Map<String, dynamic>> _documents = const [];

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    _fetchAnalytics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!OnboardingPrefs.hasSeen('landlordAnalyticsSeen')) {
        OnboardingBottomSheet.show(
          context: context,
          imagePath: 'assets/images/graph.webp',
          title: 'Insights & Analytics',
          subtitle:
              'Dive deep into your portfolio performance, see engagement rates, and track conversion funnel metrics.',
          ctaText: 'View Insights',
        ).then((_) => OnboardingPrefs.markAsSeen('landlordAnalyticsSeen'));
      }
    });
  }

  Future<void> _fetchAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final period = switch (_selectedFilter) {
        'Last 28 Days' => '28d',
        'Last 90 Days' => '90d',
        _ => '7d',
      };
      final results = await Future.wait([
        LandlordDashboardService.getLandlordDashboard(period),
        LandlordDashboardService.getLandlordPropertyPerformance(
          period: period,
          limit: 10,
        ),
      ]);
      final data = results[0];
      final performanceData = results[1];
      if (data == null) throw StateError('Analytics data is unavailable.');
      if (performanceData == null) {
        throw StateError('Property analytics are unavailable.');
      }

      if (!mounted) return;

      final kpis = data['kpis'] is Map
          ? Map<String, dynamic>.from(data['kpis'] as Map)
          : <String, dynamic>{};
      final views = kpis['views'] is Map
          ? Map<String, dynamic>.from(kpis['views'] as Map)
          : <String, dynamic>{};
      final metrics = data['metrics'] is Map
          ? Map<String, dynamic>.from(data['metrics'] as Map)
          : <String, dynamic>{};
      final chartData = data['chartData'] is List
          ? (data['chartData'] as List)
              .map((value) => value is num ? value.toDouble() : 0.0)
              .toList()
          : <double>[];
      final responseMetrics = data['responseMetrics'] is Map
          ? Map<String, dynamic>.from(data['responseMetrics'] as Map)
          : <String, dynamic>{};

      setState(() {
        _overview = {
          'totalViews': views['total']?.toString() ?? 'Unavailable',
          'growth': views['growth']?.toString() ?? '—',
          'chartData': chartData,
        };
        _metrics = {
          'uniqueViewers': views['uniqueViewers']?.toString() ?? 'Unavailable',
          'saves': metrics['saves']?.toString() ?? 'Unavailable',
          'shares': metrics['shares']?.toString() ?? 'Unavailable',
          'avgCtr': metrics['avgCtr'] is num
              ? '${(metrics['avgCtr'] as num).toStringAsFixed(1)}%'
              : 'Not enough data',
        };
        _responseMetrics = responseMetrics;
        _topProperties =
            (performanceData['propertyPerformance'] as List? ?? const [])
                .whereType<Map>()
                .map((property) => <String, dynamic>{
                      'id': property['id'],
                      'name': property['title'],
                      'location': property['city'] ?? 'Location Unavailable',
                      'image': property['imageUrl'],
                      'views': property['views'] ?? 0,
                      'conversations': property['enquiries'] ?? 0,
                      'bookings': property['bookings'] ?? 0,
                    })
                .toList();
        _funnelSteps = (data['funnel'] as List? ?? const [])
            .whereType<Map>()
            .map((step) => Map<String, dynamic>.from(step))
            .toList();
        _funnelDefinition = data['funnelDefinition']?.toString() ??
            'Stage counts use the selected period and are not a sequential user journey.';

        // Ensure index is safe
        if (_selectedDeepDiveIndex >= _topProperties.length) {
          _selectedDeepDiveIndex = 0;
        }

        _photoPerformance = [];
        _insight = null;
        _errorMessage = null;
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

  List<String> _generateXLabels(int dataLength) {
    List<String> labels = [];
    final now = DateTime.now();
    for (int i = 0; i < dataLength; i++) {
      final date = now.subtract(Duration(days: dataLength - 1 - i));
      if (dataLength <= 7) {
        labels.add(DateFormat('E').format(date));
      } else {
        if (i == 0 || i == dataLength - 1 || i % 7 == 0) {
          labels.add(DateFormat('MMM d').format(date));
        } else {
          labels.add('');
        }
      }
    }
    return labels;
  }

  Widget _buildResponsePerformanceCard() {
    final average = _responseMetrics['averageFirstResponseMinutes'] is num
        ? (_responseMetrics['averageFirstResponseMinutes'] as num).round()
        : null;
    final responseRate = _responseMetrics['responseRate'] is num
        ? (_responseMetrics['responseRate'] as num).toInt()
        : null;
    final total =
        (_responseMetrics['totalValidInquiries'] as num?)?.toInt() ?? 0;
    final answered =
        (_responseMetrics['answeredInquiries'] as num?)?.toInt() ?? 0;
    final unanswered =
        (_responseMetrics['unansweredInquiries'] as num?)?.toInt() ?? 0;
    final trend = _responseMetrics['trendPercentage'] is num
        ? (_responseMetrics['trendPercentage'] as num).toInt()
        : null;
    final label = _responseMetrics['performanceLabel']?.toString() ??
        'response_activity_building';
    final labelText = switch (label) {
      'lightning_fast' => 'Lightning Fast',
      'quick_responder' => 'Quick Responder',
      'getting_faster' => 'Getting Faster',
      'needs_improvement' => 'Needs Improvement',
      'steady_responder' => 'Steady Responder',
      _ => 'Response Activity Building',
    };
    final accent =
        label == 'needs_improvement' ? const Color(0xFF64748B) : _green;
    final progress = average == null || average <= 0
        ? 0.0
        : (15 / average).clamp(0.0, 1.0).toDouble();
    final conversion = _responseMetrics['bookingConversion'] is Map
        ? Map<String, dynamic>.from(
            _responseMetrics['bookingConversion'] as Map)
        : null;
    final fastConversion = conversion?['fastResponse'] is Map
        ? Map<String, dynamic>.from(conversion!['fastResponse'] as Map)
        : null;
    final slowConversion = conversion?['slowerOrUnanswered'] is Map
        ? Map<String, dynamic>.from(conversion!['slowerOrUnanswered'] as Map)
        : null;

    return _buildCardWrapper(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ResponseBadgeAnimation(
                performanceLabel: label,
                size: 32,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Inquiry response performance',
                  style: GoogleFonts.poppins(
                    color: _dark,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  labelText,
                  style: GoogleFonts.poppins(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              _responseMetricValue(
                'Average first reply',
                average == null ? 'Not enough data' : '$average min',
              ),
              _responseMetricValue(
                'Response rate',
                responseRate == null
                    ? '—'
                    : '$responseRate% ($answered/$total)',
              ),
              _responseMetricValue('Unanswered', '$unanswered'),
              _responseMetricValue(
                '30-day trend',
                trend == null
                    ? 'Not enough data'
                    : trend >= 0
                        ? '+$trend% faster'
                        : '${trend.abs()}% slower',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (average != null) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: const Color(0xFFE5E7EB),
                      color: _green,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '15-minute goal',
                  style: GoogleFonts.poppins(color: _grey, fontSize: 11),
                ),
              ],
            ),
          ] else
            Text(
              'Goal progress will appear when there is enough response data.',
              style: GoogleFonts.poppins(color: _grey, fontSize: 11),
            ),
          const SizedBox(height: 10),
          Text(
            unanswered > 0
                ? 'A prospective tenant is waiting. Reply to their property inquiry when you can.'
                : 'Prompt replies help prospective tenants make informed decisions.',
            style: GoogleFonts.poppins(color: _grey, fontSize: 12, height: 1.4),
          ),
          if (fastConversion != null && slowConversion != null) ...[
            const SizedBox(height: 12),
            Text(
              'Observed confirmed bookings: ${fastConversion['conversionRate']}% after a reply within 15 minutes (${fastConversion['sampleSize']} inquiries), compared with ${slowConversion['conversionRate']}% later or unanswered (${slowConversion['sampleSize']} inquiries). These group results do not establish causation.',
              style:
                  GoogleFonts.poppins(color: _grey, fontSize: 11, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _responseMetricValue(String label, String value) => SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: GoogleFonts.poppins(
                    color: _dark, fontSize: 16, fontWeight: FontWeight.w700)),
            Text(label, style: GoogleFonts.poppins(color: _grey, fontSize: 11)),
          ],
        ),
      );

  // ─── SHARED UI BUILDERS ──────────────────────────────────────────────────────

  Widget _buildCardWrapper(
      {required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24, // Softer shadow
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _dark,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
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

  // ─── FUNNEL BUILDER ─────────────────────────────────────────────────────────

  Widget _buildFunnelCard() {
    if (_isLoading) {
      return _buildCardWrapper(
        child: const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator(color: _green))),
      );
    }

    if (_funnelSteps.isEmpty) {
      return _buildCardWrapper(
        child: const SizedBox(
            height: 200,
            child: Center(child: Text('Insufficient funnel data'))),
      );
    }

    // Mathematically derive maximum for true proportional rendering
    int maxVal = 0;
    for (var step in _funnelSteps) {
      int val = int.tryParse(step['value']?.toString() ?? '0') ?? 0;
      if (val > maxVal) maxVal = val;
    }
    final denominator = maxVal > 0 ? maxVal : 1;

    String formatPct(double val) {
      final pct = val * 100;
      return '${pct % 1 == 0 ? pct.toInt() : pct.toStringAsFixed(1)}%';
    }

    String getDropOff(int current, int prev) {
      if (prev <= 0 || current >= prev) return '';
      final pct = ((prev - current) / prev) * 100;
      return '-${pct % 1 == 0 ? pct.toInt() : pct.toStringAsFixed(1)}%';
    }

    return _buildCardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conversion Funnel',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(_funnelDefinition,
              style: GoogleFonts.poppins(color: _grey, fontSize: 12)),
          const SizedBox(height: 24),
          for (int i = 0; i < _funnelSteps.length; i++) ...[
            Builder(builder: (context) {
              final step = _funnelSteps[i];
              final val = int.tryParse(step['value']?.toString() ?? '0') ?? 0;
              final fraction = (val / denominator).clamp(0.0, 1.0);

              // Calculate drop off relative to previous step
              String dropNote = '';
              if (i > 0) {
                final prevVal = int.tryParse(
                        _funnelSteps[i - 1]['value']?.toString() ?? '0') ??
                    0;
                dropNote = getDropOff(val, prevVal);
                if (dropNote.isNotEmpty) dropNote += ' drop-off';
              }

              // First step is baseline (100% hatched)
              final isBaseline = i == 0;
              final pctLabel = maxVal > 0 ? formatPct(val / maxVal) : '0%';

              return _buildFunnelRow(
                step['label']?.toString() ?? 'Stage',
                pctLabel,
                val.toString(),
                fraction,
                isBaseline: isBaseline,
                dropOff: dropNote,
              );
            }),
            if (i != _funnelSteps.length - 1) const SizedBox(height: 18),
          ]
        ],
      ),
    );
  }

  Widget _buildFunnelRow(
    String label,
    String pctStr,
    String valueStr,
    double fraction, {
    bool isBaseline = false,
    String? dropOff,
  }) {
    final format = NumberFormat("#,###");
    final formattedVal = format.format(int.tryParse(valueStr) ?? 0);

    return Row(
      children: [
        Icon(PhosphorIconsRegular.info,
            size: 16, color: _grey.withOpacity(0.5)),
        const SizedBox(width: 8),
        SizedBox(
          width: 140, // Wider for descriptive labels
          child: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w500, color: _dark)),
        ),
        SizedBox(
          width: 50,
          child: Text(pctStr,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _dark)),
        ),
        SizedBox(
          width: 70,
          child: Text(formattedVal,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _dark)),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 5,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: isBaseline
                        ? Colors.transparent
                        : const Color(0xFFD1D5DB),
                  ),
                  child: isBaseline
                      ? const CustomPaint(
                          painter: HatchedPainter(color: Color(0xFFD1D5DB)),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 3,
          child: Text(
            dropOff ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFEF4444),
            ),
          ),
        ),
      ],
    );
  }

  // ─── ADVANCED PROPERTY DEEP DIVE (NEW FEATURE) ──────────────────────────────

  Widget _buildAdvancedPropertyAnalytics(bool isDesktop) {
    if (_topProperties.isEmpty) return const SizedBox.shrink();

    // Ensure index bounds
    if (_selectedDeepDiveIndex >= _topProperties.length) {
      _selectedDeepDiveIndex = 0;
    }

    final selectedProp = _topProperties[_selectedDeepDiveIndex];

    final content = <Widget>[
      _buildPropertySidebarList(isDesktop),
      if (isDesktop) const SizedBox(width: 24) else const SizedBox(height: 24),
      if (isDesktop)
        Expanded(child: _buildPropertyDeepDiveContent(selectedProp))
      else
        _buildPropertyDeepDiveContent(selectedProp),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Advanced Property Analytics',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
        const SizedBox(height: 24),
        if (isDesktop)
          SizedBox(
              height: 700,
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: content))
        else
          Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: content),
      ],
    );
  }

  Widget _buildPropertySidebarList(bool isDesktop) {
    return Container(
      width: isDesktop ? 340 : double.infinity,
      height: isDesktop ? 700 : null,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Portfolio',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600, color: _dark)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${_topProperties.length} listed',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _grey,
                        fontWeight: FontWeight.w500)),
              )
            ],
          ),
          const SizedBox(height: 16),
          if (isDesktop)
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: _topProperties.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _buildSidebarPropertyTile(index),
              ),
            )
          else
            Column(
              children: List.generate(
                  _topProperties.length,
                  (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _buildSidebarPropertyTile(index),
                      )),
            ),

          // Sidebar Bottom Actions (As requested: Boost & Unread)
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _grey.withOpacity(0.1))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(PhosphorIconsRegular.chatTeardropText,
                        size: 16, color: _dark),
                    const SizedBox(width: 8),
                    Text('Unread messages',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _dark)),
                    const Spacer(),
                    Text('Unavailable',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _grey)), // Dummy zero until wired
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final propId = _topProperties[_selectedDeepDiveIndex]
                              ['id']
                          ?.toString();
                      if (propId != null)
                        BoostListingModal.show(context, propId);
                    },
                    icon:
                        const Icon(PhosphorIconsRegular.rocketLaunch, size: 18),
                    label: Text('Boost Selected Listing',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _dark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarPropertyTile(int index) {
    final property = _topProperties[index];
    final isSelected = index == _selectedDeepDiveIndex;

    return GestureDetector(
      onTap: () => setState(() => _selectedDeepDiveIndex = index),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? _bg : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? _grey.withOpacity(0.2) : Colors.transparent),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: buildPropertyImage(
                property['image'],
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorPlaceholder: Container(
                  width: 48,
                  height: 48,
                  color: _grey.withOpacity(0.1),
                  child: const Icon(PhosphorIconsRegular.image,
                      color: _grey, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property['name'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${property['views']} views',
                    style: GoogleFonts.poppins(fontSize: 11, color: _grey),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(PhosphorIconsRegular.caretRight,
                  color: _dark, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyDeepDiveContent(Map<String, dynamic> property) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover Header
              SizedBox(
                height: 180,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    buildPropertyImage(property['image'], fit: BoxFit.cover),
                    Container(color: Colors.black.withOpacity(0.5)),
                    Positioned(
                      bottom: 24,
                      left: 24,
                      right: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            property['name'],
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            property['location'],
                            style: GoogleFonts.poppins(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Analytical Sections
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Leads & Tenants
                    _buildSectionHeader(
                        'Leads & Tenant Pipeline', PhosphorIconsRegular.users),
                    const SizedBox(height: 16),
                    _buildLeadsTable(),
                    const SizedBox(height: 40),

                    // 2. Viewing Schedule
                    _buildSectionHeader(
                        'Viewing Schedule', PhosphorIconsRegular.calendarCheck),
                    const SizedBox(height: 16),
                    _buildSchedulesList(),
                    const SizedBox(height: 40),

                    // 3. Documents
                    _buildSectionHeader(
                        'Property Documents', PhosphorIconsRegular.fileText),
                    const SizedBox(height: 16),
                    _buildDocumentsGrid(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration:
              BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: _dark),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w600, color: _dark),
        ),
      ],
    );
  }

  Widget _buildLeadsTable() {
    if (_leads.isEmpty) {
      return const Text('Lead activity is unavailable for this report.');
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _grey.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: _leads.asMap().entries.map((entry) {
          final int idx = entry.key;
          final lead = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: idx != _leads.length - 1
                  ? Border(bottom: BorderSide(color: _grey.withOpacity(0.2)))
                  : null,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(lead['avatar']),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lead['name'],
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: _dark)),
                      Text(lead['date'],
                          style:
                              GoogleFonts.poppins(fontSize: 11, color: _grey)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: lead['intent'].contains('High')
                        ? _green.withOpacity(0.1)
                        : _bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    lead['intent'],
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            lead['intent'].contains('High') ? _green : _dark),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(PhosphorIconsRegular.chatTeardropText,
                      size: 20, color: _dark),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSchedulesList() {
    if (_schedules.isEmpty) {
      return const Text('Viewing schedule data is unavailable here.');
    }
    return Column(
      children: _schedules.map((schedule) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _grey.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _grey.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(schedule['date'].split(',')[0],
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _dark)),
                    Text(schedule['time'],
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: _green,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Viewing with ${schedule['viewer']}',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _dark)),
                    const SizedBox(height: 4),
                    Text('Status: ${schedule['status']}',
                        style: GoogleFonts.poppins(fontSize: 12, color: _grey)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDocumentsGrid() {
    if (_documents.isEmpty) {
      return const Text('Property document data is unavailable here.');
    }
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: _documents.map((doc) {
        return Container(
          width: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _grey.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                  doc['type'] == 'pdf'
                      ? PhosphorIconsFill.filePdf
                      : PhosphorIconsFill.fileDoc,
                  size: 32,
                  color: const Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text(doc['name'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600, color: _dark)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(doc['size'],
                      style: GoogleFonts.poppins(fontSize: 11, color: _grey)),
                  const Icon(PhosphorIconsRegular.downloadSimple,
                      size: 16, color: _dark),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── DESKTOP / MOBILE RESPONSIVE WRAPPERS ───────────────────────────────────

  Widget _buildDesktopLayout() {
    return RefreshIndicator(
      color: _green,
      backgroundColor: _surface,
      onRefresh: _fetchAnalytics,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 64),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header & Filter Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Portfolio Performance',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _grey.withOpacity(0.2)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedFilter,
                          icon: const Icon(PhosphorIconsRegular.caretDown,
                              color: _dark, size: 16),
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _dark),
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
                          items: _filters
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                                value: value, child: Text(value));
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // TOP ROW: Chart + Metrics Grid
                SizedBox(
                  height: 440,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 14,
                        child: _buildDesktopChartCard(),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 10,
                        child: _buildDesktopMetricsGrid(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildResponsePerformanceCard(),
                const SizedBox(height: 24),

                // MIDDLE ROW: Funnel + Insights
                SizedBox(
                  height: 420,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 14,
                        child: _buildFunnelCard(),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 10,
                        child: _buildDesktopInsightsSide(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),

                // BOTTOM ROW: Advanced Deep Dive
                _buildAdvancedPropertyAnalytics(true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopChartCard({bool chartTouchEnabled = true}) {
    final chartData = (_overview['chartData'] as List)
        .map((value) => (value as num).toDouble())
        .toList();
    final maxValue =
        chartData.isEmpty ? 0.0 : chartData.reduce((a, b) => a > b ? a : b);
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.2;
    final yInterval = maxY / 4;
    final xLabels = _generateXLabels(chartData.length);

    return _buildCardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Global Property Views',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 12),
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
                decoration: BoxDecoration(
                    color: _green.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(PhosphorIconsBold.trendUp,
                    color: _green, size: 12),
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
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _green))
                  : chartData.isEmpty
                      ? Center(
                          child: Text('No traffic data for this period',
                              style: GoogleFonts.poppins(
                                  color: _grey, fontSize: 13)),
                        )
                      : BarChart(
                          BarChartData(
                            minY: 0,
                            maxY: maxY,
                            barTouchData: BarTouchData(
                              enabled: chartTouchEnabled,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (_) => _dark,
                                getTooltipItem:
                                    (group, groupIndex, rod, rodIndex) {
                                  final label = groupIndex < xLabels.length
                                      ? xLabels[groupIndex]
                                      : '';
                                  return BarTooltipItem(
                                    '${rod.toY.toInt()} Views${label.isEmpty ? '' : '\n$label'}',
                                    GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  );
                                },
                              ),
                            ),
                            barGroups: List.generate(
                              chartData.length,
                              (index) => BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: chartData[index],
                                    color: _green,
                                    width: chartData.length <= 7
                                        ? 38
                                        : chartData.length <= 28
                                            ? 20
                                            : 10,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ],
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: yInterval,
                              getDrawingHorizontalLine: (_) => FlLine(
                                color: _grey.withOpacity(0.2),
                                strokeWidth: 1,
                              ),
                            ),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  interval: yInterval,
                                  getTitlesWidget: (value, meta) => Text(
                                    value.toInt().toString(),
                                    style: GoogleFonts.poppins(
                                      color: _grey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 32,
                                  interval: chartData.length <= 7
                                      ? 1
                                      : (chartData.length / 4).ceilToDouble(),
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index < 0 || index >= xLabels.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final label = xLabels[index];
                                    return label.isEmpty
                                        ? const SizedBox.shrink()
                                        : Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8),
                                            child: Text(
                                              label,
                                              style: GoogleFonts.poppins(
                                                color: _grey,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopMetricsGrid() {
    if (_isLoading) return _buildShimmerGrid();
    return _buildCardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Engagement Metrics',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.4, // Adjusted for desktop
              children: [
                _buildStatCard('Unique Viewers', _metrics['uniqueViewers']!,
                    PhosphorIconsFill.users, const Color(0xFF3B82F6)),
                _buildStatCard('Saves', _metrics['saves']!,
                    PhosphorIconsFill.heart, const Color(0xFFEC4899)),
                _buildStatCard('Shares', _metrics['shares']!,
                    PhosphorIconsFill.shareNetwork, const Color(0xFF8B5CF6)),
                _buildStatCard('Avg. CTR', _metrics['avgCtr']!,
                    PhosphorIconsFill.cursorClick, _green),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopInsightsSide() {
    return _buildCardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product Intelligence',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _green))
                : _photoPerformance.isEmpty
                    ? Center(
                        child: Text('Per-photo engagement is not tracked yet.',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: _grey)))
                    : ListView(
                        children: _photoPerformance
                            .map((p) => _buildPhotoMetricRow(
                                  p['label'],
                                  p['engagement'],
                                  p['image'],
                                  Color(p['color'] ?? 0xFF10B981),
                                ))
                            .toList(),
                      ),
          ),
          if (_insight != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(PhosphorIconsFill.warningCircle,
                          color: Color(0xFFEF4444), size: 20),
                      const SizedBox(width: 8),
                      Text('Monetization Insight',
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF991B1B))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_insight!['message'],
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: const Color(0xFF991B1B))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    // Retain the existing mobile list layout, but inject the new components
    return RefreshIndicator(
      color: _green,
      backgroundColor: _surface,
      onRefresh: _fetchAnalytics,
      child: ListView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.fromLTRB(
            24, 8, 24, MediaQuery.of(context).padding.bottom + 48),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Performance',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _grey.withOpacity(0.2)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    icon: const Icon(PhosphorIconsRegular.caretDown,
                        color: _dark, size: 16),
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _dark),
                    onChanged: (String? newValue) {
                      if (newValue != null)
                        setState(() {
                          _selectedFilter = newValue;
                          _fetchAnalytics();
                        });
                    },
                    items: _filters
                        .map<DropdownMenuItem<String>>((String value) =>
                            DropdownMenuItem<String>(
                                value: value, child: Text(value)))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            _buildShimmerChart()
          else
            _buildDesktopChartCard(chartTouchEnabled: false),
          const SizedBox(height: 32),
          _buildResponsePerformanceCard(),
          const SizedBox(height: 32),
          Text('Engagement Metrics',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 16),
          if (_isLoading) _buildShimmerGrid() else _buildDesktopMetricsGrid(),
          const SizedBox(height: 32),
          _buildFunnelCard(),
          const SizedBox(height: 32),
          _buildDesktopInsightsSide(),
          const SizedBox(height: 32),
          _buildAdvancedPropertyAnalytics(false),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1100;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: const Icon(PhosphorIconsRegular.caretLeft,
                        color: _dark, size: 24),
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
              child: _errorMessage == null
                  ? (isDesktop ? _buildDesktopLayout() : _buildMobileLayout())
                  : _buildErrorState(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(PhosphorIconsRegular.warningCircle,
                color: _grey, size: 36),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: _dark, fontSize: 14),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _fetchAnalytics,
              icon: const Icon(PhosphorIconsRegular.arrowClockwise, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoMetricRow(
    String label,
    String engagement,
    Object? image,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: buildPropertyImage(
              image?.toString() ?? '',
              width: 48,
              height: 48,
              errorPlaceholder: Container(
                width: 48,
                height: 48,
                color: _bg,
                child: const Icon(PhosphorIconsRegular.image,
                    color: _grey, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _dark)),
                const SizedBox(height: 4),
                Text(engagement,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 12, color: _grey)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return _buildCardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Engagement Metrics',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.4,
            children: List.generate(
              4,
              (index) => Shimmer.fromColors(
                baseColor: Colors.grey.shade200,
                highlightColor: Colors.grey.shade100,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 76,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        width: 110,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerChart() {
    return _buildCardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 150,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 150,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Shimmer.fromColors(
            baseColor: Colors.grey.shade200,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
