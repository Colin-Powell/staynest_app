import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/services/super_admin_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// ─── Google Analytics Design System Constants ─────────────────────────────────
const Color _bg = Color(0xFFF1F3F4); // Standard GA background grey
const Color _dark = Color(0xFF202124); // GA Main Text
const Color _greyDark = Color(0xFF3C4043); // GA Secondary Text
const Color _greyLight = Color(0xFF5F6368); // GA Muted Text
const Color _divider = Color(0xFFDADCE0); // GA Border Color
const Color _surface = Colors.white;

// Exact Google Analytics Chart Colors
const Color _gaBlue = Color(0xFF1A73E8);
const Color _gaGreen = Color(0xFF1E8E3E);
const Color _gaPink = Color(0xFFE52592);

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
      if (mounted) setState(() => _loading = false);
    }
  }

  double _number(dynamic value) {
    if (value == null) return 0.0;
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0.0;
  }

  Map<String, int> _analyticsMap(String key) {
    final rows = _overview[key];
    if (rows is! List) return {};
    return {
      for (final row in rows.whereType<Map>())
        row['label']?.toString() ?? 'Unknown': _number(row['value']).toInt(),
    };
  }

  // Helper to wrap horizontally scrolling areas with a fade + indicator
  Widget _buildScrollableWithIndicator(
      {required Widget child, required double height}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, right: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Swipe for more',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _greyLight,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              const Icon(PhosphorIconsRegular.arrowRight,
                  size: 12, color: _greyLight),
            ],
          ),
        ),
        SizedBox(
          height: height,
          child: Stack(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: child,
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 24,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [_bg, _bg.withOpacity(0.0)],
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Firebase overview',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      color: _dark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 1. STATS ROW
                  _buildStatsGrid(context),
                  const SizedBox(height: 16),

                  // 2. MAIN ANALYTICS
                  _buildAnalyticsGrid1(context),
                  const SizedBox(height: 16),

                  // 3. RETENTION & COHORTS
                  _buildAnalyticsGrid2(context),
                  const SizedBox(height: 16),

                  // 4. LISTS
                  _buildListsGrid(context),
                  const SizedBox(height: 16),

                  // 5. MAIN CONTENT AREA
                  _buildMainContentArea(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. RESPONSIVE STATS
  // ---------------------------------------------------------------------------
  Widget _buildStatsGrid(BuildContext context) {
    final monthlyRevenue = _number(_overview['monthlyRevenue']);
    final stats = [
      _StatCard(
          title: 'Total Users',
          value: _loading ? '...' : '${_overview['totalUsers'] ?? 0}',
          trend: 'All registered accounts'),
      _StatCard(
          title: 'Total Properties',
          value: _loading ? '...' : '${_overview['totalProperties'] ?? 0}',
          trend: 'Submitted listings'),
      _StatCard(
          title: 'Pending Operations',
          value: _loading ? '...' : '${_overview['pendingVerifications'] ?? 0}',
          trend: 'KYC reviews waiting'),
      _StatCard(
          title: '30-Day Revenue',
          value: _loading ? '...' : 'KSh ${monthlyRevenue.toStringAsFixed(0)}',
          trend: 'Completed bookings'),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 1024) {
        return Row(
          children: stats
              .map((stat) => Expanded(
                    child: Padding(
                        padding:
                            EdgeInsets.only(right: stat == stats.last ? 0 : 16),
                        child: stat),
                  ))
              .toList(),
        );
      } else {
        return _buildScrollableWithIndicator(
          height: 120,
          child: Row(
            children: stats
                .map((stat) => SizedBox(
                      width: 240,
                      child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: stat),
                    ))
                .toList(),
          ),
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 2. ANALYTICS ROW 1 (Massive Graph + Stacked Side Graphs)
  // ---------------------------------------------------------------------------
  Widget _buildAnalyticsGrid1(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= 1024;
      final isTablet =
          constraints.maxWidth >= 768 && constraints.maxWidth < 1024;

      if (isDesktop) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                flex: 5,
                child: _buildLineChartCard('User activity over time',
                    height: 440)),
            const SizedBox(width: 16),
            Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildRealtimeBarChartCard(height: 212),
                    const SizedBox(height: 16),
                    _buildSingleLineChartCard('Verification Success Rate',
                        height: 212),
                  ],
                )),
          ],
        );
      } else if (isTablet) {
        return Column(
          children: [
            _buildLineChartCard('User activity over time', height: 350),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildRealtimeBarChartCard(height: 280)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildSingleLineChartCard(
                        'Verification Success Rate',
                        height: 280)),
              ],
            ),
          ],
        );
      }
      return _buildScrollableWithIndicator(
        height: 360,
        child: Row(
          children: [
            SizedBox(
                width: 340,
                child: _buildLineChartCard('User activity over time',
                    height: 360)),
            const SizedBox(width: 16),
            SizedBox(
                width: 320, child: _buildRealtimeBarChartCard(height: 360)),
            const SizedBox(width: 16),
            SizedBox(
                width: 320,
                child: _buildSingleLineChartCard('Verification Success Rate',
                    height: 360)),
          ],
        ),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // 3. ANALYTICS ROW 2 (Medium Size)
  // ---------------------------------------------------------------------------
  Widget _buildAnalyticsGrid2(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= 1024;

      if (isDesktop) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildRetentionChartCard(height: 340)),
            const SizedBox(width: 16),
            Expanded(child: _buildCohortTableCard(height: 340)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildEmptyStateCard('Flagged Properties Impact',
                    height: 340)),
          ],
        );
      } else {
        return _buildScrollableWithIndicator(
          height: 320,
          child: Row(
            children: [
              SizedBox(
                  width: 320, child: _buildRetentionChartCard(height: 320)),
              const SizedBox(width: 16),
              SizedBox(width: 320, child: _buildCohortTableCard(height: 320)),
              const SizedBox(width: 16),
              SizedBox(
                  width: 320,
                  child: _buildEmptyStateCard('Flagged Properties Impact',
                      height: 320)),
            ],
          ),
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 4. ANALYTICS ROW 3 (Tall Lists)
  // ---------------------------------------------------------------------------
  Widget _buildListsGrid(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= 1024;

      if (isDesktop) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _buildListCard(
                    'Most Viewed Locations', _analyticsMap('topLocations'),
                    height: 360)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildListCard(
                    'Top KYC Rejections', _analyticsMap('kycRejections'),
                    height: 360)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildListCard(
                    'Key Events by Event Name', _analyticsMap('keyEvents'),
                    height: 360)),
          ],
        );
      } else {
        return _buildScrollableWithIndicator(
          height: 280,
          child: Row(
            children: [
              SizedBox(
                  width: 300,
                  child: _buildListCard(
                      'Most Viewed Locations', _analyticsMap('topLocations'),
                      height: 280)),
              const SizedBox(width: 16),
              SizedBox(
                  width: 300,
                  child: _buildListCard(
                      'Top KYC Rejections', _analyticsMap('kycRejections'),
                      height: 280)),
            ],
          ),
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 5. MAIN CONTENT AREA
  // ---------------------------------------------------------------------------
  Widget _buildMainContentArea(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 850) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildLiveSummarySection()),
            const SizedBox(width: 16),
            Expanded(flex: 1, child: _buildQuickActionsSection()),
          ],
        );
      } else {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLiveSummarySection(),
            const SizedBox(height: 16),
            _buildQuickActionsSection(),
          ],
        );
      }
    });
  }

  Widget _buildLiveSummarySection() {
    return _ChartCardBase(
      title: 'Live Summary',
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActivityTile('Revenue from completed bookings',
              'KSh ${_number(_overview['totalRevenue']).toStringAsFixed(0)}'),
          const Divider(height: 1, color: _divider),
          _buildActivityTile('Pending KYC submissions',
              '${_overview['pendingVerifications'] ?? 0} waiting review'),
          const Divider(height: 1, color: _divider),
          _buildActivityTile('Registered accounts',
              '${_overview['totalUsers'] ?? 0} total users'),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return _ChartCardBase(
      title: 'Quick Actions',
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActionButton(label: 'Verify Listings', onTap: () {}),
          const SizedBox(height: 8),
          _ActionButton(label: 'Review KYC', onTap: () {}),
          const SizedBox(height: 8),
          _ActionButton(label: 'Moderation Queue', onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildActivityTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: _greyDark)),
          ),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _dark)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GA STYLE CHART BUILDERS
  // ---------------------------------------------------------------------------

  Widget _buildEmptyChartState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIconsRegular.chartLineDown,
              size: 32, color: _greyLight.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(message,
              style: GoogleFonts.inter(fontSize: 13, color: _greyLight)),
        ],
      ),
    );
  }

  Widget _buildLineChartCard(String title, {required double height}) {
    final List<dynamic> chartData = _overview['chartData'] ?? [];
    List<FlSpot> usersSpots = [];
    List<FlSpot> bookingsSpots = [];
    double maxY = 5;

    // Latest values for the right-side legend
    int latestUsers = 0;
    int latestBookings = 0;

    if (chartData.isNotEmpty) {
      latestUsers = _number(chartData.last['new_users']).toInt();
      latestBookings = _number(chartData.last['new_bookings']).toInt();

      for (int i = 0; i < chartData.length; i++) {
        final u = _number(chartData[i]['new_users']);
        final b = _number(chartData[i]['new_bookings']);
        usersSpots.add(FlSpot(i.toDouble(), u));
        bookingsSpots.add(FlSpot(i.toDouble(), b));
        if (u > maxY) maxY = u;
        if (b > maxY) maxY = b;
      }
    } else {
      return _ChartCardBase(
          title: title,
          height: height,
          child: _buildEmptyChartState('No activity recorded.'));
    }

    if (maxY == 0) maxY = 5; // Fallback so graph draws empty axes correctly

    // Create clean GA steps (e.g. 0, 20, 40, 60, 80)
    double yInterval = (maxY / 4).ceilToDouble();
    if (yInterval == 0) yInterval = 1;
    maxY = yInterval * 4;

    return _ChartCardBase(
      title: title,
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => Colors.white,
                    tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    tooltipBorder: const BorderSide(
                        color: _divider, width: 1), // GA style tooltip
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        final isFirst = touchedSpots.indexOf(spot) == 0;
                        final index = spot.x.toInt();

                        String dateLabel = '';
                        if (chartData.isNotEmpty &&
                            index >= 0 &&
                            index < chartData.length) {
                          // Format to "Mon 10 Aug"
                          final rawLabel = chartData[index]['label'] ??
                              ''; // e.g. "2026-09-07"
                          try {
                            final dt = DateTime.parse(rawLabel);
                            dateLabel = DateFormat('EEE d MMM').format(dt);
                          } catch (_) {
                            dateLabel = rawLabel;
                          }
                        }

                        final isUsers = spot.barIndex == 0;
                        final color = isUsers ? _gaBlue : _gaGreen;

                        return LineTooltipItem(
                          isFirst ? '$dateLabel\n' : '',
                          GoogleFonts.inter(
                              color: _greyLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                          children: [
                            TextSpan(
                                text: '●  ${spot.y.toInt()}',
                                style: GoogleFonts.inter(
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13))
                          ],
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (value) =>
                      const FlLine(color: _divider, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          interval: yInterval,
                          getTitlesWidget: (val, meta) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Text(val.toInt().toString(),
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: _greyLight,
                                      fontWeight: FontWeight.w400)),
                            );
                          })),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          interval:
                              1, // Draw for every spot, but conditionally render
                          getTitlesWidget: (val, meta) {
                            final index = val.toInt();
                            if (chartData.isNotEmpty &&
                                index >= 0 &&
                                index < chartData.length) {
                              // Show approx 4-5 labels evenly spaced
                              final step = (chartData.length / 4).ceil();
                              if (index == 0 ||
                                  index == chartData.length - 1 ||
                                  index % step == 0) {
                                final rawLabel =
                                    chartData[index]['label'] ?? '';
                                try {
                                  final dt = DateTime.parse(rawLabel);
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                        '${dt.day}\n${DateFormat('MMM').format(dt)}',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: _greyLight,
                                            fontWeight: FontWeight.w400,
                                            height: 1.2)),
                                  );
                                } catch (_) {
                                  return const SizedBox.shrink();
                                }
                              }
                            }
                            return const SizedBox.shrink();
                          })),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: usersSpots,
                    isCurved: false, // GA lines are straight
                    color: _gaBlue,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    // GA Style prominent dots with white borders
                    dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                                radius: 3.5,
                                color: _gaBlue,
                                strokeWidth: 1.5,
                                strokeColor: Colors.white)),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    spots: bookingsSpots,
                    isCurved: false,
                    color: _gaGreen,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                                radius: 3.5,
                                color: _gaGreen,
                                strokeWidth: 1.5,
                                strokeColor: Colors.white)),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),

          // GA Right-side legend
          Container(
            width: 80,
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGALegendItem('TENANTS', latestUsers, _gaBlue),
                const SizedBox(height: 24),
                _buildGALegendItem('LANDLORDS', latestBookings, _gaGreen),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGALegendItem(String label, int value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _greyDark,
                    letterSpacing: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(value.toString(),
            style: GoogleFonts.inter(
                fontSize: 24, fontWeight: FontWeight.w400, color: _dark)),
      ],
    );
  }

  Widget _buildRealtimeBarChartCard({required double height}) {
    final backlogData = (_overview['backlogData'] as List?) ?? const [];

    if (backlogData.isEmpty) {
      return _ChartCardBase(
        title: 'ACTIVE USERS IN LAST 30 MINUTES',
        height: height,
        child: _buildEmptyChartState('No real-time data.'),
      );
    }

    return _ChartCardBase(
      title: 'ACTIVE USERS IN LAST 30 MINUTES',
      titleStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _greyDark,
          letterSpacing: 0.5),
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_overview['pendingVerifications'] ?? 0}', // Mocking data for visual
            style: GoogleFonts.inter(
                fontSize: 36,
                fontWeight: FontWeight.w400,
                color: _dark,
                letterSpacing: -1.0,
                height: 1.0),
          ),
          const SizedBox(height: 4),
          Text('ACTIVE USERS PER MINUTE',
              style: GoogleFonts.inter(
                  fontSize: 10,
                  color: _greyLight,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 10,
                titlesData: const FlTitlesData(show: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(
                    show: true,
                    border:
                        const Border(bottom: BorderSide(color: _divider, width: 1))),
                barGroups: List.generate(
                  backlogData.length,
                  (i) => BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                        toY: _number(backlogData[i]['value']),
                        color: _gaBlue,
                        width: 8,
                        borderRadius: BorderRadius.zero // Flat tops
                        )
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleLineChartCard(String title, {required double height}) {
    final List<dynamic> data = _overview['verificationData'] ?? [];
    if (data.isEmpty) {
      return _ChartCardBase(
          title: title,
          height: height,
          child: _buildEmptyChartState('No trends available.'));
    }

    bool allZero = true;
    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      final val = _number(data[i]['success_rate']);
      if (val > 0) allZero = false;
      spots.add(FlSpot(i.toDouble(), val));
    }

    if (allZero || spots.length < 2) {
      return _ChartCardBase(
          title: title,
          height: height,
          child: _buildEmptyChartState('Not enough data recorded.'));
    }

    return _ChartCardBase(
      title: title,
      height: height,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => Colors.white,
              tooltipPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              tooltipBorder: const BorderSide(color: _divider, width: 1),
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  final dateLabel = (index >= 0 && index < data.length)
                      ? (data[index]['label'] ?? '')
                      : '';
                  return LineTooltipItem(
                    '$dateLabel\n',
                    GoogleFonts.inter(
                        color: _greyLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                    children: [
                      TextSpan(
                          text: '• Success: ${spot.y.toInt()}%',
                          style: GoogleFonts.inter(
                              color: _gaBlue,
                              fontWeight: FontWeight.w600,
                              fontSize: 13))
                    ],
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
          gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (value) =>
                  const FlLine(color: _divider, strokeWidth: 1)),
          titlesData: FlTitlesData(
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 25,
                getTitlesWidget: (val, meta) => Text("${val.toInt()}%",
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _greyLight,
                        fontWeight: FontWeight.w400)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final index = val.toInt();
                  if (index >= 0 && index < data.length) {
                    if (data.length > 5 && index % 2 != 0) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(data[index]['label'] ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: _greyLight,
                              fontWeight: FontWeight.w400)),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: _gaBlue,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                          radius: 3.5,
                          color: _gaBlue,
                          strokeWidth: 1.5,
                          strokeColor: Colors.white)),
              belowBarData: BarAreaData(show: false),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRetentionChartCard({required double height}) {
    final List<dynamic> data = _overview['retentionData'] ?? [];
    if (data.isEmpty) {
      return _ChartCardBase(
          title: 'User retention',
          height: height,
          child: _buildEmptyChartState('Insufficient data for retention.'));
    }

    bool allZero = true;
    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      final val = _number(data[i]['retention_rate']);
      if (val > 0) allZero = false;
      spots.add(FlSpot(i.toDouble(), val));
    }

    if (allZero || spots.length < 2) {
      return _ChartCardBase(
          title: 'User retention',
          height: height,
          child: _buildEmptyChartState('Not enough returning users yet.'));
    }

    return _ChartCardBase(
      title: 'User retention',
      height: height,
      child: Column(
        children: [
          Expanded(
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => Colors.white,
                    tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    tooltipBorder: const BorderSide(color: _divider, width: 1),
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        final day = (index >= 0 && index < data.length)
                            ? (data[index]['label_day'] ?? '')
                            : '';
                        return LineTooltipItem(
                          'Day $day\n',
                          GoogleFonts.inter(
                              color: _greyLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                          children: [
                            TextSpan(
                                text: '• Retention: ${spot.y.toInt()}%',
                                style: GoogleFonts.inter(
                                    color: _gaBlue,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13))
                          ],
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                ),
                gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (value) =>
                        const FlLine(color: _divider, strokeWidth: 1)),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 25,
                      getTitlesWidget: (val, meta) => Text("${val.toInt()}%",
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: _greyLight,
                              fontWeight: FontWeight.w400)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final index = val.toInt();
                        if (index >= 0 && index < data.length) {
                          if (data.length > 5 && index % 2 != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text('Day\n${data[index]['label_day']}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    color: _greyLight,
                                    fontWeight: FontWeight.w400,
                                    height: 1.2)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: _gaBlue,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                                radius: 3.5,
                                color: _gaBlue,
                                strokeWidth: 1.5,
                                strokeColor: Colors.white)),
                    belowBarData: BarAreaData(show: false),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCohortTableCard({required double height}) {
    final cohortData = (_overview['cohortData'] as List?) ?? const [];

    if (cohortData.isEmpty) {
      return _ChartCardBase(
          title: 'Landlord Activity by Cohort',
          height: height,
          child: _buildEmptyChartState('No cohort data available.'));
    }

    return _ChartCardBase(
      title: 'Landlord Activity by Cohort',
      height: height,
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 80),
              Expanded(
                  child: Center(
                      child: Text('Active landlords',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              color: _greyLight,
                              fontWeight: FontWeight.w500)))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                  width: 80,
                  child: Text('All Users',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _dark))),
              ...List.generate(
                  6,
                  (i) => Expanded(
                      child: Center(
                          child: Text('0.0%',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: _dark,
                                  fontWeight: FontWeight.w500))))),
            ],
          ),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: _divider)),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: cohortData.length,
              itemBuilder: (context, index) {
                final cohort = cohortData[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 80,
                          child: Text(cohort['cohort']?.toString() ?? 'Unknown',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: _greyLight,
                                  fontWeight: FontWeight.w500))),
                      Expanded(
                          child: Center(
                              child: Text('${cohort['active_landlords'] ?? 0}',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _dark)))),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard(String title, {required double height}) {
    return _ChartCardBase(
      title: title,
      height: height,
      child: _buildEmptyChartState('No data available'),
    );
  }

  Widget _buildListCard(String title, Map<String, int> data,
      {String? emptyMessage, required double height}) {
    int maxVal = data.isEmpty ? 1 : data.values.reduce((a, b) => a > b ? a : b);

    return _ChartCardBase(
      title: title,
      height: height,
      child: data.isEmpty
          ? _buildEmptyChartState(emptyMessage ?? 'No data recorded yet.')
          : Column(
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ITEM NAME',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _greyLight)),
                      Text('COUNT',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _greyLight)),
                    ]),
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: _divider)),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: data.entries
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(e.key,
                                          style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: _dark,
                                              fontWeight: FontWeight.w400)),
                                      Text(e.value.toString(),
                                          style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: _dark)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  FractionallySizedBox(
                                    widthFactor:
                                        (e.value / maxVal).clamp(0.0, 1.0),
                                    child: Container(
                                      height: 4,
                                      decoration: BoxDecoration(
                                          color: _gaBlue,
                                          borderRadius:
                                              BorderRadius.circular(2)),
                                    ),
                                  )
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// HELPER CLASSES
// ---------------------------------------------------------------------------

class _ChartCardBase extends StatelessWidget {
  final String title;
  final Widget child;
  final TextStyle? titleStyle;
  final double height;

  const _ChartCardBase(
      {required this.title,
      required this.child,
      this.titleStyle,
      required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: titleStyle ??
                    GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: _dark,
                    ),
              ),
              const Icon(PhosphorIconsRegular.checkCircle,
                  color: _gaGreen, size: 20),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String trend;

  const _StatCard({
    required this.title,
    required this.value,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w500, color: _greyDark)),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  color: _dark,
                  letterSpacing: -0.5)),
          Text(trend,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _greyLight)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Row(
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w500, color: _gaBlue)),
            const Spacer(),
            const Icon(PhosphorIconsRegular.arrowRight, color: _gaBlue, size: 16),
          ],
        ),
      ),
    );
  }
}
