import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:property_app/screens/dashboard/landlord_notifications_page.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/services/properties_api.dart';
import 'package:property_app/utils/api_result.dart';
import 'package:property_app/utils/property_mapper.dart';
import 'package:property_app/session/app_session.dart';
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
  final VoidCallback? onAddProperty;
  final VoidCallback? onViewVerification;
  final VoidCallback? onLogout;

  const LandlordOverviewPage({
    super.key,
    this.onViewAllProperties,
    this.onAddProperty,
    this.onViewVerification,
    this.onLogout,
  });

  @override
  State<LandlordOverviewPage> createState() => _LandlordOverviewPageState();
}

class _LandlordOverviewPageState extends State<LandlordOverviewPage> {
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedAnalyticsPeriod = 'This Week';
  List<Map<String, dynamic>> _properties = [];
  Map<String, dynamic> _analyticsData = {};
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
          imagePath: 'assets/images/dashboard.webp',
          title: 'Welcome to your Dashboard',
          subtitle:
              'Track your total views, manage properties, and monitor your occupancy rate all in one place.',
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
        LandlordDashboardService.getLandlordOverview(_selectedAnalyticsPeriod),
      ]);

      if (!mounted) return;

      setState(() {
        _properties = results[0] as List<Map<String, dynamic>>;
        final analyticsData = results[1] as Map<String, dynamic>?;
        _analyticsData = analyticsData ?? {};

        if (analyticsData != null) {
          _metrics = {
            'totalViews':
                analyticsData['overview']?['totalViews']?.toString() ?? '0',
            'viewsGrowth':
                analyticsData['overview']?['growth']?.toString() ?? '0%',
            'totalBookings':
                analyticsData['metrics']?['totalBookings']?.toString() ?? '0',
            'bookingsGrowth':
                analyticsData['metrics']?['bookingsGrowth']?.toString() ??
                    '+0%',
            'occupancyRate':
                analyticsData['metrics']?['occupancyRate']?.toString() ?? '0%',
            'occupancyGrowth':
                analyticsData['metrics']?['occupancyGrowth']?.toString() ??
                    '+0%',
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

  Map<String, dynamic> _analyticsSection(String key) {
    final value = _analyticsData[key];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  List<Map<String, dynamic>> _analyticsRows(String key) {
    final value = _analyticsData[key];
    if (value is! List) return const [];
    return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  List<double> get _viewTrend {
    final raw = _analyticsSection('overview')['chartData'];
    if (raw is! List) return const [];
    return raw.map((value) => value is num ? value.toDouble() : 0.0).toList();
  }

  String _trendLabel(int index, int length) {
    final date = DateTime.now().subtract(Duration(days: length - index - 1));
    if (length <= 7) return DateFormat('E').format(date);
    if (index == 0 || index == length - 1 || index % 7 == 0) {
      return DateFormat('MMM d').format(date);
    }
    return '';
  }

  // ─── UI BUILDERS ─────────────────────────────────────────────────────────────

  Widget _buildShimmerStats() {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1100;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isDesktop ? 4 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isDesktop ? 1.45 : 1.25,
      children: List.generate(
          4,
          (index) => Shimmer.fromColors(
                baseColor: Colors.grey.shade200,
                highlightColor: Colors.grey.shade100,
                child: Container(
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24))),
              )),
    );
  }

  Widget _buildShimmerProperties() {
    return Column(
      children: List.generate(
          2,
          (index) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Shimmer.fromColors(
                  baseColor: Colors.grey.shade200,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                      height: 88,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20))),
                ),
              )),
    );
  }

  // ─── DESKTOP SPECIFIC BUILDERS (UPDATED TO SOFT CARD DESIGN) ───────────────

  Widget _buildDesktopPanel({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(24),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24), // Softer, rounder corners
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), // Very soft shadow
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDesktopMetricCard(
    String label,
    String value,
    String change,
    IconData icon,
  ) {
    final positive = !change.startsWith('-');
    return _buildDesktopPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: _green),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: positive
                      ? const Color(0xFFE8F4F1)
                      : const Color(0xFFFFF1F0),
                  borderRadius: BorderRadius.circular(20), // Pill shape
                ),
                child: Text(
                  change,
                  style: GoogleFonts.poppins(
                    color: positive ? _green : const Color(0xFFB42318),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: _dark,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopViewsPanel() {
    final overview = _analyticsSection('overview');
    final values = _viewTrend;
    final maxValue = values.isEmpty ? 1.0 : values.reduce(math.max).toDouble();
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.2;
    final yInterval = maxY / 4;

    return _buildDesktopPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Profile views',
                        style: GoogleFonts.poppins(
                            color: _dark,
                            fontWeight: FontWeight.w600,
                            fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      overview['totalViews']?.toString() ??
                          _metrics['totalViews'] ??
                          '0',
                      style: GoogleFonts.poppins(
                        color: _dark,
                        fontWeight: FontWeight.w700,
                        fontSize: 32,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4F1),
                  borderRadius: BorderRadius.circular(20), // Pill shape
                ),
                child: Text(
                  overview['growth']?.toString() ??
                      _metrics['viewsGrowth'] ??
                      '0%',
                  style: GoogleFonts.poppins(
                      color: _green, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _green))
                : values.length < 2
                    ? Center(
                        child: Text('Not enough view history for a trend yet.',
                            style: GoogleFonts.poppins(
                                color: _grey, fontSize: 13)))
                    : LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: (values.length - 1).toDouble(),
                          minY: 0,
                          maxY: maxY,
                          lineTouchData: const LineTouchData(
                            handleBuiltInTouches: true,
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: yInterval,
                            getDrawingHorizontalLine: (_) => const FlLine(
                              color: Color(0xFFE9ECEA),
                              strokeWidth: 1,
                              dashArray: [4, 4], // Softened grid with dashes
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
                                reservedSize: 38,
                                interval: yInterval,
                                getTitlesWidget: (value, meta) => Text(
                                  value.toInt().toString(),
                                  style: GoogleFonts.poppins(
                                      color: _grey, fontSize: 10),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: values.length <= 7
                                    ? 1
                                    : (values.length / 4).ceilToDouble(),
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index < 0 || index >= values.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final label =
                                      _trendLabel(index, values.length);
                                  if (label.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(label,
                                        style: GoogleFonts.poppins(
                                            color: _grey, fontSize: 10)),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(
                                values.length,
                                (index) =>
                                    FlSpot(index.toDouble(), values[index]),
                              ),
                              isCurved: true,
                              curveSmoothness: 0.35,
                              color: _green,
                              barWidth: 4, // Slightly thicker line
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: _green.withValues(alpha: 0.08),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFunnelPanel() {
    final steps = _analyticsRows('funnel');
    return _buildDesktopPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Conversion funnel',
              style: GoogleFonts.poppins(
                  color: _dark, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 22),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: _green))
          else if (steps.isEmpty)
            Text('Funnel data will appear as people discover your listings.',
                style: GoogleFonts.poppins(color: _grey, fontSize: 13))
          else
            ...steps.map((step) {
              final rawPercentage = step['percentage'];
              final percentage = rawPercentage is num
                  ? rawPercentage.toDouble().clamp(0.0, 1.0)
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(step['label']?.toString() ?? 'Activity',
                              style: GoogleFonts.poppins(
                                  color: _grey, fontSize: 13)),
                        ),
                        Text(step['value']?.toString() ?? '0',
                            style: GoogleFonts.poppins(
                                color: _dark,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10), // Pill progress
                      child: LinearProgressIndicator(
                        value: percentage,
                        minHeight: 8,
                        color: _green,
                        backgroundColor: const Color(0xFFE9ECEA),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDesktopEngagementPanel() {
    final metrics = _analyticsSection('metrics');
    final items = <(String, String, IconData)>[
      (
        'Unique viewers',
        metrics['uniqueViewers']?.toString() ?? '0',
        PhosphorIconsRegular.users,
      ),
      (
        'Saves',
        metrics['saves']?.toString() ?? '0',
        PhosphorIconsRegular.heart
      ),
      (
        'Shares',
        metrics['shares']?.toString() ?? '0',
        PhosphorIconsRegular.shareNetwork,
      ),
      (
        'Average CTR',
        metrics['avgCtr']?.toString() ?? '0%',
        PhosphorIconsRegular.cursorClick,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 42) / 4;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _buildDesktopPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _green.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item.$3, color: _green, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    color: _dark,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                            Text(item.$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    color: _grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopTopPropertiesPanel() {
    final properties = _analyticsRows('topProperties');
    return _buildDesktopPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Top performing properties',
                    style: GoogleFonts.poppins(
                        color: _dark,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: widget.onViewAllProperties,
                style: TextButton.styleFrom(
                  foregroundColor: _green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: Text('View all',
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: _green))
          else if (properties.isEmpty)
            Text('Your listings will appear here as they receive views.',
                style: GoogleFonts.poppins(color: _grey, fontSize: 13))
          else
            ...properties.map((property) {
              final image = property['image']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: buildPropertyImage(
                        image,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorPlaceholder: Container(
                          width: 56,
                          height: 56,
                          color: const Color(0xFFF0F2F1),
                          child: const Icon(PhosphorIconsRegular.house,
                              color: _grey, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            property['name']?.toString() ?? 'Property',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                color: _dark,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            property['location']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                GoogleFonts.poppins(color: _grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${property['views'] ?? '0'} views',
                        style: GoogleFonts.poppins(
                            color: _dark,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDesktopPhotoPanel() {
    final photos = _analyticsRows('photoPerformance');
    return _buildDesktopPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Photo performance',
              style: GoogleFonts.poppins(
                  color: _dark, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: _green))
          else if (photos.isEmpty)
            Text('Photo engagement will appear as visitors browse listings.',
                style: GoogleFonts.poppins(color: _grey, fontSize: 13))
          else
            ...photos.map((photo) {
              final image = photo['image']?.toString() ?? '';
              final rawColor = photo['color'];
              final color = rawColor is int ? Color(rawColor) : _green;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: buildPropertyImage(
                        image,
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        photo['label']?.toString() ?? 'Listing photo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            color: _dark,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      photo['engagement']?.toString() ?? '0 views',
                      style: GoogleFonts.poppins(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDesktopDashboard() {
    final overview = _analyticsSection('overview');
    final metrics = _analyticsSection('metrics');
    final insight = _analyticsData['insight'];
    return Scaffold(
      backgroundColor: _bg, // Keeps background canvas visually separate from cards
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _green,
          backgroundColor: _surface,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(30, 26, 30, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back, ${AppSession.displayName.split(' ').first}',
                                style: GoogleFonts.poppins(
                                  color: _dark,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Portfolio performance at a glance',
                                style: GoogleFonts.poppins(
                                    color: _grey, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(30), // Pill shape
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedAnalyticsPeriod,
                              isDense: true,
                              borderRadius: BorderRadius.circular(16),
                              icon: const Icon(PhosphorIconsRegular.caretDown,
                                  size: 16, color: _grey),
                              style: GoogleFonts.poppins(
                                  color: _dark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                              items: const [
                                DropdownMenuItem(
                                    value: 'This Week',
                                    child: Text('This week')),
                                DropdownMenuItem(
                                    value: 'Last 28 Days',
                                    child: Text('Last 28 days')),
                              ],
                              onChanged: (period) {
                                if (period == null) return;
                                setState(
                                    () => _selectedAnalyticsPeriod = period);
                                _loadData();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        FilledButton.icon(
                          onPressed: widget.onAddProperty,
                          icon: const Icon(PhosphorIconsRegular.plus, size: 16),
                          label: Text('Add property',
                              style: GoogleFonts.poppins(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          style: FilledButton.styleFrom(
                            backgroundColor: _green,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)), // Pill button
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = (constraints.maxWidth - 42) / 4;
                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: _buildDesktopMetricCard(
                                'Properties',
                                _properties.length.toString(),
                                '+0',
                                PhosphorIconsRegular.buildings,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _buildDesktopMetricCard(
                                'Profile views',
                                overview['totalViews']?.toString() ?? '0',
                                overview['growth']?.toString() ?? '0%',
                                PhosphorIconsRegular.eye,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _buildDesktopMetricCard(
                                'Bookings',
                                metrics['totalBookings']?.toString() ?? '0',
                                metrics['bookingsGrowth']?.toString() ?? '0%',
                                PhosphorIconsRegular.calendarCheck,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _buildDesktopMetricCard(
                                'Occupancy',
                                metrics['occupancyRate']?.toString() ?? '0%',
                                metrics['occupancyGrowth']?.toString() ?? '0%',
                                PhosphorIconsRegular.chartLineUp,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final chartWidth = (constraints.maxWidth - 14) * 0.62;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: chartWidth,
                              child: _buildDesktopViewsPanel(),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: _buildDesktopFunnelPanel()),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildDesktopEngagementPanel(),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final propertiesWidth =
                            (constraints.maxWidth - 14) * 0.56;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: propertiesWidth,
                              child: _buildDesktopTopPropertiesPanel(),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: _buildDesktopPhotoPanel()),
                          ],
                        );
                      },
                    ),
                    if (insight is Map &&
                        insight['message']?.toString().isNotEmpty == true) ...[
                      const SizedBox(height: 14),
                      _buildDesktopPanel(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _green.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(PhosphorIconsRegular.lightbulb,
                                  color: _green, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Portfolio insight',
                                      style: GoogleFonts.poppins(
                                          color: _dark,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(
                                    insight['message'].toString(),
                                    style: GoogleFonts.poppins(
                                        color: _grey, fontSize: 13, height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      _buildDesktopPanel(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFEF2F2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(PhosphorIconsRegular.warningCircle,
                                  color: Color(0xFFB42318)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(_errorMessage!,
                                  style: GoogleFonts.poppins(
                                      color: const Color(0xFFB42318),
                                      fontSize: 13)),
                            ),
                            TextButton(
                                onPressed: _loadData,
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFFFEF2F2),
                                  foregroundColor: const Color(0xFFB42318),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                ),
                                child: const Text('Retry')),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 1100) {
      return _buildDesktopDashboard();
    }
    return _buildMobileDashboard();
  }

  // ─── MOBILE SPECIFIC BUILDER (KEPT INTACT) ──────────────────────────────────

  Widget _buildMobileDashboard() {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _green,
          backgroundColor: _surface,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.fromLTRB(
                24, 16, 24, MediaQuery.of(context).padding.bottom + 130),
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
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const LandlordNotificationsPage())),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: _grey.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Stack(
                          children: [
                            const Icon(PhosphorIconsRegular.bell,
                                color: _dark, size: 24),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color:
                                      Color(0xFFEF4444), // Red notification dot
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
                    decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: const Color(0xFFFCA5A5).withOpacity(0.5))),
                    child: Column(
                      children: [
                        const Icon(PhosphorIconsRegular.warningCircle,
                            color: Color(0xFFEF4444), size: 48),
                        const SizedBox(height: 12),
                        Text(_errorMessage!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                                color: const Color(0xFF991B1B),
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              elevation: 0),
                          child: Text('Retry',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
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
                          _buildStatCard('Properties',
                              _properties.length.toString(), '+0', true),
                          _buildStatCard(
                              'Bookings',
                              _metrics['totalBookings']!,
                              _metrics['bookingsGrowth']!,
                              !_metrics['bookingsGrowth']!.startsWith('-')),
                          _buildStatCard(
                              'Views',
                              _metrics['totalViews']!,
                              _metrics['viewsGrowth']!,
                              !_metrics['viewsGrowth']!.startsWith('-')),
                          _buildStatCard(
                              'Occupancy',
                              _metrics['occupancyRate']!,
                              _metrics['occupancyGrowth']!,
                              !_metrics['occupancyGrowth']!.startsWith('-')),
                        ],
                      ),
                const SizedBox(height: 24),

                // ─── VIEW ANALYTICS BUTTON ───
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const LandlordAnalyticsPage())),
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
                  _isLoading
                      ? 'Your Properties'
                      : (_properties.isEmpty
                          ? 'No Properties Yet'
                          : 'Your Properties'),
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
                            decoration: BoxDecoration(
                                color: _grey.withOpacity(0.1),
                                shape: BoxShape.circle),
                            child: const Icon(PhosphorIconsRegular.houseLine,
                                size: 48, color: _grey),
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
                            style:
                                GoogleFonts.poppins(fontSize: 14, color: _grey),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
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

  Widget _buildStatCard(
      String title, String value, String change, bool isPositive) {
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
                  color: isPositive
                      ? _green.withOpacity(0.1)
                      : const Color(0xFFFEF2F2),
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
    final price = priceValue is String
        ? double.tryParse(priceValue) ?? 0
        : (priceValue as num? ?? 0);
    final rating =
        (double.tryParse(property['average_rating']?.toString() ?? '0') ?? 0.0)
            .toDouble();
    final reviews =
        int.tryParse(property['review_count']?.toString() ?? '0') ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
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
                      const Icon(PhosphorIconsFill.star,
                          size: 14, color: Color(0xFFF59E0B)),
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