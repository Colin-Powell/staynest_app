import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/theme.dart';
import 'package:property_app/services/super_admin_service.dart';
import 'package:fl_chart/fl_chart.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  Map<String, dynamic> _overview = {};
  bool _loading = true;

  // Google Analytics Style Blues
  static const Color _primaryBlue = Color(0xFF1A73E8);
  static const Color _secondaryBlue = Color(0xFF8AB4F8);

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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Property Platform Analytics',
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray900,
                        letterSpacing: -0.5)),
                const SizedBox(height: 24),

                // 1. STATS ROW (Auto-height, small footprint)
                _buildStatsGrid(context),
                const SizedBox(height: 24),

                // 2. MAIN ANALYTICS (Asymmetric layout, large main chart)
                _buildAnalyticsGrid1(context),
                const SizedBox(height: 24),

                // 3. RETENTION & COHORTS (Medium height)
                _buildAnalyticsGrid2(context),
                const SizedBox(height: 24),

                // 4. LISTS (Tall height to accommodate data rows)
                _buildListsGrid(context),
                const SizedBox(height: 24),

                // 5. MAIN CONTENT AREA (Summary & Actions)
                _buildMainContentArea(context),
              ],
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
          value: _loading ? '…' : '${_overview['totalUsers'] ?? 0}',
          icon: PhosphorIcons.users(),
          trend: 'All registered accounts',
          trendPositive: true),
      _StatCard(
          title: 'Total Properties',
          value: _loading ? '…' : '${_overview['totalProperties'] ?? 0}',
          icon: PhosphorIcons.buildingApartment(),
          trend: 'All submitted listings',
          trendPositive: true),
      _StatCard(
          title: 'Pending Operations',
          value: _loading ? '…' : '${_overview['pendingVerifications'] ?? 0}',
          icon: PhosphorIcons.shieldCheck(),
          trend: 'KYC reviews waiting',
          trendPositive: false),
      _StatCard(
          title: '30-Day Revenue',
          value: _loading ? '…' : 'KSh ${monthlyRevenue.toStringAsFixed(0)}',
          icon: PhosphorIcons.wallet(),
          trend: 'Confirmed and completed',
          trendPositive: true),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 1024) {
        return Row(
            children: stats
                .map((stat) => Expanded(
                    child: Padding(
                        padding:
                            EdgeInsets.only(right: stat == stats.last ? 0 : 16),
                        child: stat)))
                .toList());
      } else if (constraints.maxWidth >= 600) {
        return GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.5,
            children: stats);
      } else {
        return Column(
            children: stats
                .map((stat) => Padding(
                    padding: const EdgeInsets.only(bottom: 16), child: stat))
                .toList());
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
                child: _buildLineChartCard(
                    'Platform Growth (Tenants vs Landlords)',
                    height: 420)),
            const SizedBox(width: 16),
            Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildRealtimeBarChartCard(height: 202),
                    const SizedBox(height: 16),
                    _buildSingleLineChartCard('Verification Success Rate',
                        height: 202),
                  ],
                )),
          ],
        );
      } else if (isTablet) {
        return Column(
          children: [
            _buildLineChartCard('Platform Growth (Tenants vs Landlords)',
                height: 350),
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
      return Column(
        children: [
          _buildLineChartCard('Platform Growth', height: 320),
          const SizedBox(height: 16),
          _buildRealtimeBarChartCard(height: 280),
          const SizedBox(height: 16),
          _buildSingleLineChartCard('Verification Success Rate', height: 280),
        ],
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
        return Column(
          children: [
            _buildRetentionChartCard(height: 320),
            const SizedBox(height: 16),
            _buildCohortTableCard(height: 320),
            const SizedBox(height: 16),
            _buildEmptyStateCard('Flagged Properties Impact', height: 200),
          ],
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
        return Column(
          children: [
            _buildListCard(
                'Most Viewed Locations', _analyticsMap('topLocations'),
                height: 280),
            const SizedBox(height: 16),
            _buildListCard('Top KYC Rejections', _analyticsMap('kycRejections'),
                height: 280),
          ],
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
            const SizedBox(width: 24),
            Expanded(flex: 1, child: _buildQuickActionsSection()),
          ],
        );
      } else {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLiveSummarySection(),
            const SizedBox(height: 24),
            _buildQuickActionsSection(),
          ],
        );
      }
    });
  }

  Widget _buildLiveSummarySection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: StayNestColors.outlineLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live Summary',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray900)),
          const SizedBox(height: 24),
          _buildActivityTile(
              'Revenue from completed bookings',
              'KSh ${_number(_overview['totalRevenue']).toStringAsFixed(0)}',
              PhosphorIcons.wallet()),
          const Divider(height: 1, color: AppColors.gray100),
          _buildActivityTile(
              'Pending KYC submissions',
              '${_overview['pendingVerifications'] ?? 0} waiting review',
              PhosphorIcons.shieldCheck()),
          const Divider(height: 1, color: AppColors.gray100),
          _buildActivityTile(
              'Registered accounts',
              '${_overview['totalUsers'] ?? 0} total users',
              PhosphorIcons.users()),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: StayNestColors.outlineLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray900)),
          const SizedBox(height: 24),
          _ActionButton(
              label: 'Verify Listings',
              icon: PhosphorIcons.checkCircle(),
              onTap: () {}),
          const SizedBox(height: 8),
          _ActionButton(
              label: 'Review KYC',
              icon: PhosphorIcons.identificationBadge(),
              onTap: () {}),
          const SizedBox(height: 8),
          _ActionButton(
              label: 'Moderation Queue',
              icon: PhosphorIcons.warningCircle(),
              onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildActivityTile(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gray500, size: 20),
          const SizedBox(width: 16),
          Expanded(
              child: Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.gray700))),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray900)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GA STYLE CHART BUILDERS (Blue Themes & Clean White Tooltips)
  // ---------------------------------------------------------------------------

  Widget _buildEmptyChartState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray500)),
        ],
      ),
    );
  }

  Widget _buildLineChartCard(String title, {required double height}) {
    final List<dynamic> chartData = _overview['chartData'] ?? [];
    List<FlSpot> usersSpots = [];
    List<FlSpot> bookingsSpots = [];
    double maxY = 5;

    if (chartData.isNotEmpty) {
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
          child: _buildEmptyChartState(
              'No activity recorded in the last 7 days.'));
    }
    if (maxY == 0)
      return _ChartCardBase(
          title: title,
          height: height,
          child: _buildEmptyChartState(
              'No activity recorded in the last 7 days.'));

    maxY = maxY + (maxY * 0.2);

    return _ChartCardBase(
      title: title,
      height: height,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => Colors.white,
              tooltipPadding: const EdgeInsets.all(12),
              tooltipBorder: BorderSide(
                  color: AppColors.gray400, width: 1), // Soft GA tooltip border
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((spot) {
                  final isFirst = touchedSpots.indexOf(spot) == 0;
                  final index = spot.x.toInt();
                  final dateLabel = (chartData.isNotEmpty &&
                          index >= 0 &&
                          index < chartData.length)
                      ? (chartData[index]['label'] ?? '')
                      : '';

                  final isUsers = spot.barIndex == 0;
                  final label = isUsers ? 'Tenants' : 'Landlords';
                  final color =
                      isUsers ? _primaryBlue : _secondaryBlue; // GA Blues

                  return LineTooltipItem(
                    isFirst ? '$dateLabel\n' : '',
                    GoogleFonts.inter(
                        color: AppColors.gray500,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                    children: [
                      TextSpan(
                          text: '• $label: ${spot.y.toInt()}',
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
              getDrawingHorizontalLine: (value) =>
                  FlLine(color: AppColors.gray100, strokeWidth: 1)),
          titlesData: FlTitlesData(
            rightTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (val, meta) {
                      if (val == maxY) return const SizedBox.shrink();
                      return Text(val.toInt().toString(),
                          style: GoogleFonts.inter(
                              fontSize: 10, color: AppColors.gray500));
                    })),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      final index = val.toInt();
                      if (chartData.isNotEmpty &&
                          index >= 0 &&
                          index < chartData.length) {
                        if (chartData.length > 5 && index % 2 != 0)
                          return const SizedBox.shrink();
                        return Text(chartData[index]['label'] ?? '',
                            style: GoogleFonts.inter(
                                fontSize: 10, color: AppColors.gray500));
                      }
                      const titles = {0: '02 Aug', 2: '09', 4: '16', 6: '23'};
                      return Text(titles[index] ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: AppColors.gray500));
                    })),
          ),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
                spots: usersSpots,
                isCurved: true,
                color: _primaryBlue,
                barWidth: 2,
                dotData: const FlDotData(show: false)),
            LineChartBarData(
                spots: bookingsSpots,
                isCurved: true,
                color: _secondaryBlue,
                barWidth: 2,
                dotData: const FlDotData(show: false)),
          ],
        ),
      ),
    );
  }

  Widget _buildRealtimeBarChartCard({required double height}) {
    final backlogData = (_overview['backlogData'] as List?) ?? const [];
    return _ChartCardBase(
      title: 'ADMIN BACKLOG (24 HRS)',
      height: height,
      titleStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.gray500,
          letterSpacing: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_overview['pendingVerifications'] ?? 0}',
              style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray900)),
          const SizedBox(height: 8),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 10,
                titlesData: const FlTitlesData(show: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(
                    show: true,
                    border: Border(
                        bottom: BorderSide(
                            color: AppColors.gray400,
                            width: 1))), // Soft bottom border
                barGroups: List.generate(
                    backlogData.length,
                    (i) => BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                              toY: _number(backlogData[i]['value']),
                              color: _primaryBlue, // GA Blue bars
                              width: 10,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(2)) // Slight rounding
                              )
                        ])),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (backlogData.isNotEmpty)
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('OLDEST PENDING',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray500)),
              Text('7-DAY TREND',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray500))
            ]),
        ],
      ),
    );
  }

  Widget _buildSingleLineChartCard(String title, {required double height}) {
    final List<dynamic> data = _overview['verificationData'] ?? [];
    if (data.isEmpty)
      return _ChartCardBase(
          title: title,
          height: height,
          child: _buildEmptyChartState('No verification trends.'));

    bool allZero = true;
    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      final val = _number(data[i]['success_rate']);
      if (val > 0) allZero = false;
      spots.add(FlSpot(i.toDouble(), val));
    }

    if (allZero)
      return _ChartCardBase(
          title: title,
          height: height,
          child: _buildEmptyChartState('No activity recorded.'));

    return _ChartCardBase(
      title: title,
      height: height,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => Colors.white,
              tooltipPadding: const EdgeInsets.all(12),
              tooltipBorder: BorderSide(
                  color: AppColors.gray400, width: 1), // Soft GA tooltip border
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  final dateLabel = (index >= 0 && index < data.length)
                      ? (data[index]['label'] ?? '')
                      : '';
                  return LineTooltipItem(
                      '$dateLabel\n',
                      GoogleFonts.inter(
                          color: AppColors.gray500,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                      children: [
                        TextSpan(
                            text: '• Success: ${spot.y.toInt()}%',
                            style: GoogleFonts.inter(
                                color: _primaryBlue,
                                fontWeight: FontWeight.w600,
                                fontSize: 13))
                      ]);
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
          gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) =>
                  FlLine(color: AppColors.gray100, strokeWidth: 1)),
          titlesData: FlTitlesData(
            rightTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (val, meta) => Text("${val.toInt()}%",
                        style: GoogleFonts.inter(
                            fontSize: 10, color: AppColors.gray500)))),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      final index = val.toInt();
                      if (index >= 0 && index < data.length)
                        return Text(data[index]['label'] ?? '',
                            style: GoogleFonts.inter(
                                fontSize: 10, color: AppColors.gray500));
                      return const SizedBox.shrink();
                    })),
          ),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
                spots: spots,
                isCurved: true,
                color: _primaryBlue,
                barWidth: 2,
                belowBarData: BarAreaData(
                    show: true,
                    color:
                        _primaryBlue.withOpacity(0.1)), // Subtle GA area fill
                dotData: const FlDotData(show: false))
          ],
        ),
      ),
    );
  }

  Widget _buildRetentionChartCard({required double height}) {
    final List<dynamic> data = _overview['retentionData'] ?? [];
    if (data.isEmpty)
      return _ChartCardBase(
          title: 'User retention',
          height: height,
          child: _buildEmptyChartState('Insufficient data for retention.'));

    bool allZero = true;
    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      final val = _number(data[i]['retention_rate']);
      if (val > 0) allZero = false;
      spots.add(FlSpot(i.toDouble(), val));
    }
    if (allZero)
      return _ChartCardBase(
          title: 'User retention',
          height: height,
          child: _buildEmptyChartState('Not enough returning users yet.'));

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
                    tooltipPadding: const EdgeInsets.all(12),
                    tooltipBorder: BorderSide(
                        color: AppColors.gray400,
                        width: 1), // Soft GA tooltip border
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        final day = (index >= 0 && index < data.length)
                            ? (data[index]['label_day'] ?? '')
                            : '';
                        return LineTooltipItem(
                            'Day $day\n',
                            GoogleFonts.inter(
                                color: AppColors.gray500,
                                fontSize: 11,
                                fontWeight: FontWeight.w500),
                            children: [
                              TextSpan(
                                  text: '• Retention: ${spot.y.toInt()}%',
                                  style: GoogleFonts.inter(
                                      color: _primaryBlue,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13))
                            ]);
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                ),
                gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) =>
                        FlLine(color: AppColors.gray100, strokeWidth: 1)),
                titlesData: FlTitlesData(
                  rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (val, meta) => Text(
                              "${val.toInt()}%",
                              style: GoogleFonts.inter(
                                  fontSize: 10, color: AppColors.gray500)))),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            final index = val.toInt();
                            if (index >= 0 && index < data.length)
                              return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                      'Day\n${data[index]['label_day']}',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                          fontSize: 9,
                                          color: AppColors.gray500)));
                            return const SizedBox.shrink();
                          })),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: _primaryBlue,
                      barWidth: 2,
                      belowBarData: BarAreaData(
                          show: true,
                          color: _primaryBlue
                              .withOpacity(0.1)), // Subtle GA area fill
                      dotData: const FlDotData(show: false))
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Text('Last 35 days tracking',
                style:
                    GoogleFonts.inter(fontSize: 11, color: AppColors.gray500))
          ])
        ],
      ),
    );
  }

  Widget _buildCohortTableCard({required double height}) {
    final cohortData = (_overview['cohortData'] as List?) ?? const [];
    return _ChartCardBase(
      title: 'Landlord activity by cohort',
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
                              fontSize: 10, color: AppColors.gray600))))
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
                          color: AppColors.gray900))),
              ...List.generate(
                  6,
                  (i) => Expanded(
                      child: Center(
                          child: Text('0.0%',
                              style: GoogleFonts.inter(
                                  fontSize: 10, color: AppColors.gray900)))))
            ],
          ),
          const Divider(height: 16, color: AppColors.gray100),
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cohortData.length,
              itemBuilder: (context, index) {
                final cohort = cohortData[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 80,
                          child: Text(cohort['cohort']?.toString() ?? 'Unknown',
                              style: GoogleFonts.inter(
                                  fontSize: 10, color: AppColors.gray700))),
                      Expanded(
                          child: Center(
                              child: Text('${cohort['active_landlords'] ?? 0}',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.gray900)))),
                    ],
                  ),
                );
              },
            ),
          ),
          Align(
              alignment: Alignment.centerRight,
              child: Text('View retention →',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.gray900,
                      fontWeight: FontWeight.w600)))
        ],
      ),
    );
  }

  Map<String, int> _analyticsMap(String key) {
    final rows = _overview[key];
    if (rows is! List) return {};
    return {
      for (final row in rows.whereType<Map>())
        row['label']?.toString() ?? 'Unknown': _number(row['value']).toInt(),
    };
  }

  double _number(dynamic value) {
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  }

  Widget _buildEmptyStateCard(String title, {required double height}) {
    return _ChartCardBase(
      title: title,
      height: height,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('No data available',
                style:
                    GoogleFonts.inter(fontSize: 12, color: AppColors.gray500)),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['\$0.00', '\$0.20', '\$0.40', '\$0.60', '\$0.80']
                  .map((e) => Text(e,
                      style: GoogleFonts.inter(
                          fontSize: 10, color: AppColors.gray400)))
                  .toList(),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(String title, Map<String, int> data,
      {String? emptyMessage, required double height}) {
    int maxVal = data.isEmpty ? 1 : data.values.reduce((a, b) => a > b ? a : b);

    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: StayNestColors.outlineLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray900)),
              Icon(PhosphorIcons.listBullets(),
                  color: AppColors.gray500, size: 18),
            ],
          ),
          const SizedBox(height: 24),
          if (data.isEmpty)
            Expanded(
                child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(emptyMessage ?? 'No data',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.gray500)),
            ])))
          else
            Expanded(
              child: Column(
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ITEM NAME',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.gray500)),
                        Text('COUNT',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.gray500))
                      ]),
                  const Divider(height: 16),
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
                                                color: AppColors.gray900)),
                                        Text(e.value.toString(),
                                            style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.gray900)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    FractionallySizedBox(
                                      widthFactor:
                                          (e.value / maxVal).clamp(0.0, 1.0),
                                      child: Container(
                                          height: 4,
                                          decoration: BoxDecoration(
                                              color: _primaryBlue,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      2))), // GA Blue Value Bars
                                    )
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            )
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: StayNestColors.outlineLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: titleStyle ??
                      GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray900)),
              Icon(PhosphorIcons.chartBar(),
                  color: AppColors.gray400, size: 18),
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
  final IconData icon;
  final String trend;
  final bool? trendPositive;

  const _StatCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.trend,
      this.trendPositive});

  @override
  Widget build(BuildContext context) {
    Color trendColor = AppColors.gray500;
    if (trendPositive == true) trendColor = AppColors.green600;
    if (trendPositive == false) trendColor = StayNestColors.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: StayNestColors.outlineLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray600)),
              Icon(icon, color: AppColors.gray400, size: 20)
            ],
          ),
          const SizedBox(height: 16),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: AppColors.gray900,
                  letterSpacing: -0.5)),
          const SizedBox(height: 16),
          Text(trend,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: trendColor)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration:
            BoxDecoration(border: Border.all(color: Colors.transparent)),
        child: Row(
          children: [
            Icon(icon, color: AppColors.gray700, size: 18),
            const SizedBox(width: 16),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.gray900)),
          ],
        ),
      ),
    );
  }
}
