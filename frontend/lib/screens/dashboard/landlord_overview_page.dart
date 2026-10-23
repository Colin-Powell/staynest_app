import 'dart:async';

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
import 'package:property_app/services/message_service.dart';
import 'package:property_app/utils/api_result.dart';
import 'package:property_app/utils/property_mapper.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/widgets/onboarding_bottom_sheet.dart';
import 'package:property_app/session/onboarding_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'landlord_dashboard_service.dart';
import 'landlord_analytics_page.dart';
import 'boost_listing_modal.dart';

// ─── Landlord Design System Constants ─────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981); // Emerald Green for Landlord Theme

class HatchedPainter extends CustomPainter {
  final Color color;
  final double stripeWidth;
  final double gap;

  const HatchedPainter({
    required this.color,
    this.stripeWidth = 2,
    this.gap = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stripeWidth
      ..style = PaintingStyle.stroke;
    for (double x = -size.height; x < size.width; x += stripeWidth + gap) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HatchedPainter oldDelegate) =>
      color != oldDelegate.color ||
      stripeWidth != oldDelegate.stripeWidth ||
      gap != oldDelegate.gap;
}

class LandlordOverviewPage extends StatefulWidget {
  final VoidCallback? onViewAllProperties;
  final VoidCallback? onViewBookings;
  final VoidCallback? onViewMessages;
  final VoidCallback? onViewUnansweredMessages;
  final void Function(String conversationId)? onOpenConversation;
  final void Function(String bookingId)? onOpenBooking;
  final void Function(String propertyId)? onEditProperty;
  final void Function(String propertyId)? onOpenProperty;
  final VoidCallback? onAddProperty;
  final VoidCallback? onViewVerification;
  final VoidCallback? onLogout;

  const LandlordOverviewPage({
    super.key,
    this.onViewAllProperties,
    this.onViewBookings,
    this.onViewMessages,
    this.onViewUnansweredMessages,
    this.onOpenConversation,
    this.onOpenBooking,
    this.onEditProperty,
    this.onOpenProperty,
    this.onAddProperty,
    this.onViewVerification,
    this.onLogout,
  });

  @override
  State<LandlordOverviewPage> createState() => _LandlordOverviewPageState();
}

class _LandlordOverviewPageState extends State<LandlordOverviewPage> {
  bool _isLoading = true;
  bool _dashboardAvailable = false;
  String? _errorMessage;
  String _selectedAnalyticsPeriod = 'This Week';
  List<Map<String, dynamic>> _properties = [];
  List<Map<String, dynamic>> _propertyPerformance = [];
  int _propertyPerformanceTotal = 0;
  bool _propertyPerformanceHasMore = false;
  bool _loadingPropertyPerformance = false;
  bool _loadingMorePropertyPerformance = false;
  int _propertyPerformanceRequestId = 0;
  Timer? _propertySearchDebounce;
  Map<String, dynamic> _analyticsData = {};

  // Performance UI State
  int _selectedPerformancePropertyIndex = 0;
  String? _performanceLeadsPropertyId;
  List<Map<String, dynamic>> _performanceLeads = const [];
  bool _loadingPerformanceLeads = false;
  int _performanceLeadsRequestId = 0;
  List<ConversationModel> _pendingInquiries = const [];

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final Set<String> _dismissedRecommendationIds = {};
  String get _dismissedRecommendationKey =>
      'staynest.landlord.dismissed_recommendations.${AppSession.currentUserId ?? 'anonymous'}';

  @override
  void initState() {
    super.initState();
    _loadData();
    unawaited(_loadPendingInquiries());
    _loadDismissedRecommendations();
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

  @override
  void dispose() {
    _searchController.dispose();
    _propertySearchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadDismissedRecommendations() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _dismissedRecommendationIds.addAll(
          preferences.getStringList(_dismissedRecommendationKey) ?? const [],
        );
      });
    } catch (_) {}
  }

  Future<void> _loadPendingInquiries() async {
    try {
      final conversations = await MessageService.instance.fetchConversations();
      if (!mounted) return;
      setState(() {
        _pendingInquiries = conversations
            .where((conversation) =>
                conversation.contextType == 'property' &&
                conversation.lastMessageFromUserId != null &&
                conversation.lastMessageFromUserId !=
                    AppSession.currentUserId &&
                conversation.conversationId?.isNotEmpty == true)
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _dismissRecommendation(String id) async {
    setState(() => _dismissedRecommendationIds.add(id));
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(
        _dismissedRecommendationKey,
        _dismissedRecommendationIds.toList(),
      );
    } catch (_) {}
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final periodParam = switch (_selectedAnalyticsPeriod) {
        'Last 28 Days' => '28d',
        'Last 90 Days' => '90d',
        _ => '7d',
      };
      final results = await Future.wait<Object?>([
        PropertiesApi.getLandlordPropertiesPage(limit: 3)
            .then<Object?>((page) => page)
            .catchError((_) => null),
        LandlordDashboardService.getLandlordDashboard(periodParam),
      ]);

      if (!mounted) return;

      final dashboardData = results[1] as Map<String, dynamic>?;
      setState(() {
        final propertyPage = results[0];
        _properties =
            propertyPage is ({List<Map<String, dynamic>> items, bool hasMore})
                ? propertyPage.items
                : const [];
        _analyticsData = dashboardData ?? {};
        if (dashboardData != null) {
          _dashboardAvailable = true;
        } else {
          _dashboardAvailable = false;
          _errorMessage = 'Performance data is currently unavailable.';
        }

        _isLoading = false;
        // Reset property selection if data reloads
        _selectedPerformancePropertyIndex = 0;
        _performanceLeadsPropertyId = null;
        _performanceLeads = const [];
        _performanceLeadsRequestId++;
      });
      unawaited(_loadPropertyPerformance());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ApiResult.mapError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPropertyPerformance({
    String? search,
    bool loadMore = false,
  }) async {
    final requestId = ++_propertyPerformanceRequestId;
    final query = (search ?? _searchQuery).trim();
    final offset = loadMore ? _propertyPerformance.length : 0;
    setState(() {
      if (loadMore) {
        _loadingMorePropertyPerformance = true;
      } else {
        _loadingPropertyPerformance = true;
      }
    });

    final period = switch (_selectedAnalyticsPeriod) {
      'Last 28 Days' => '28d',
      'Last 90 Days' => '90d',
      _ => '7d',
    };
    final response =
        await LandlordDashboardService.getLandlordPropertyPerformance(
      period: period,
      search: query,
      offset: offset,
    );
    if (!mounted || requestId != _propertyPerformanceRequestId) return;

    final rows = (response?['propertyPerformance'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final firstPropertyId =
        !loadMore && rows.isNotEmpty ? rows.first['id']?.toString() : null;
    setState(() {
      _propertyPerformance =
          loadMore ? [..._propertyPerformance, ...rows] : rows;
      _propertyPerformanceTotal =
          int.tryParse(response?['total']?.toString() ?? '') ?? rows.length;
      _propertyPerformanceHasMore = response?['hasMore'] == true;
      _loadingPropertyPerformance = false;
      _loadingMorePropertyPerformance = false;
      if (!loadMore) _selectedPerformancePropertyIndex = 0;
    });
    if (firstPropertyId != null && firstPropertyId.isNotEmpty) {
      unawaited(_loadPerformanceLeads(firstPropertyId));
    }
  }

  Map<String, dynamic> _analyticsSection(String key) {
    final value = _analyticsData[key];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  List<double> get _viewTrend {
    final raw = _analyticsData['chartData'] ??
        _analyticsSection('overview')['chartData'];
    if (raw is! List) return const [];
    return raw.map((value) => value is num ? value.toDouble() : 0.0).toList();
  }

  Map<String, dynamic> _kpi(String key) => _dashboardAvailable
      ? _analyticsSection('kpis')[key] is Map
          ? Map<String, dynamic>.from(_analyticsSection('kpis')[key] as Map)
          : <String, dynamic>{}
      : <String, dynamic>{};

  String _displayRate(Object? value) =>
      value is num ? '${value.toStringAsFixed(1)}%' : 'Not enough data';

  void _openAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LandlordAnalyticsPage(
          initialFilter: _selectedAnalyticsPeriod,
          onOpenProperty: widget.onOpenProperty,
        ),
      ),
    );
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

  Widget _buildKpiGrid({required bool compact}) {
    final properties = _kpi('properties');
    final views = _kpi('views');
    final enquiries = _kpi('enquiries');
    final response = _kpi('responseRate');
    final conversion = _kpi('conversion');
    final pendingBookings = _kpi('pendingBookings');
    final periodLabel = _selectedAnalyticsPeriod == 'This Week'
        ? 'Selected 7-day period'
        : _selectedAnalyticsPeriod == 'Last 28 Days'
            ? 'Selected 28-day period'
            : 'Selected 90-day period';
    final cards = <Widget>[
      _DashboardKpiCard(
        title: 'Properties',
        value: _dashboardAvailable
            ? (properties['total'] ?? 0).toString()
            : 'Unavailable',
        detail: _dashboardAvailable
            ? '${properties['published'] ?? 0} published · ${properties['pending'] ?? 0} pending · ${properties['draft'] ?? 0} drafts · ${properties['rented'] ?? 0} rented · ${properties['unavailable'] ?? 0} unavailable'
            : 'Property counts could not be loaded.',
        icon: PhosphorIconsRegular.buildings,
        onTap: widget.onViewAllProperties,
        loading: _isLoading,
      ),
      _DashboardKpiCard(
        title: 'Property views',
        value: _dashboardAvailable ? '${views['total'] ?? 0}' : 'Unavailable',
        detail: _dashboardAvailable
            ? '${views['uniqueViewers'] ?? 0} unique property viewers · ${views['growth'] ?? '—'} vs previous period'
            : 'View data could not be loaded.',
        icon: PhosphorIconsRegular.eye,
        onTap: _openAnalytics,
        loading: _isLoading,
      ),
      _DashboardKpiCard(
        title: 'Property-linked conversations',
        value:
            _dashboardAvailable ? '${enquiries['total'] ?? 0}' : 'Unavailable',
        detail: _dashboardAvailable
            ? '${enquiries['uniqueTenants'] ?? 0} distinct tenants · not a qualification count'
            : 'Conversation data could not be loaded.',
        icon: PhosphorIconsRegular.chatTeardropText,
        onTap: widget.onViewMessages,
        loading: _isLoading,
      ),
      _DashboardKpiCard(
        title: 'Pending booking requests',
        value: _dashboardAvailable
            ? '${pendingBookings['count'] ?? 0}'
            : 'Unavailable',
        detail: 'Current requests requiring landlord action.',
        icon: PhosphorIconsRegular.calendarCheck,
        onTap: widget.onViewBookings,
        loading: _isLoading,
      ),
      _DashboardKpiCard(
        title: 'Response rate',
        value: _dashboardAvailable
            ? _displayRate(response['percentage'])
            : 'Unavailable',
        detail: _dashboardAvailable
            ? '${response['responded'] ?? 0} replied of ${response['total'] ?? 0} tenant-started conversations older than 12 hours · $periodLabel'
            : 'Response data could not be loaded.',
        icon: PhosphorIconsRegular.paperPlaneTilt,
        onTap: widget.onViewUnansweredMessages ?? widget.onViewMessages,
        loading: _isLoading,
      ),
      _DashboardKpiCard(
        title: 'View-to-conversation rate',
        value: _dashboardAvailable
            ? _displayRate(conversion['percentage'])
            : 'Unavailable',
        detail: _dashboardAvailable
            ? '${conversion['convertedPairs'] ?? 0} of ${conversion['eligibleViewers'] ?? 0} viewed property/tenant pairs · $periodLabel'
            : 'Conversion data could not be loaded.',
        icon: PhosphorIconsRegular.chartLineUp,
        onTap: _openAnalytics,
        loading: _isLoading,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = compact
            ? 2
            : constraints.maxWidth >= 1100
                ? 3
                : 2;
        final gap = 14.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children:
              cards.map((card) => SizedBox(width: width, child: card)).toList(),
        );
      },
    );
  }

  Widget _buildRecommendations() {
    final recommendations = _analyticsData['recommendations'];
    if (!_dashboardAvailable || recommendations is! List) {
      return const SizedBox.shrink();
    }
    final rows = recommendations
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) =>
            !_dismissedRecommendationIds.contains(item['id']?.toString()))
        .toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    return _buildDashboardSection(
      title: 'Recommended actions',
      child: Column(
        children: rows.map((recommendation) {
          final priority = recommendation['priority']?.toString() ?? 'low';
          final property = recommendation['property'];
          final propertyMap = property is Map
              ? Map<String, dynamic>.from(property)
              : <String, dynamic>{};
          return Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  priority == 'high'
                      ? PhosphorIconsRegular.warningCircle
                      : PhosphorIconsRegular.lightbulb,
                  color: priority == 'high' ? const Color(0xFFB42318) : _green,
                ),
                title:
                    Text(recommendation['title']?.toString() ?? 'Review item'),
                subtitle: Text(
                  '${recommendation['body'] ?? ''}${propertyMap['title'] == null ? '' : '\n${propertyMap['title']}'}',
                ),
                trailing: IconButton(
                  tooltip: 'Dismiss recommendation',
                  onPressed: () => _dismissRecommendation(
                    recommendation['id']?.toString() ?? '',
                  ),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _handleRecommendation(recommendation),
                  child:
                      Text(recommendation['actionText']?.toString() ?? 'Open'),
                ),
              ),
              if (recommendation != rows.last) const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _handleRecommendation(Map<String, dynamic> recommendation) {
    switch (recommendation['type']) {
      case 'unanswered_enquiry':
        final conversationId = recommendation['conversationId']?.toString();
        if (conversationId != null && widget.onOpenConversation != null) {
          widget.onOpenConversation!(conversationId);
        } else {
          widget.onViewMessages?.call();
        }
        break;
      case 'pending_booking':
        final bookingId = recommendation['bookingId']?.toString();
        if (bookingId != null && widget.onOpenBooking != null) {
          widget.onOpenBooking!(bookingId);
        } else {
          widget.onViewBookings?.call();
        }
        break;
      case 'promising_listing':
        final property = recommendation['property'];
        final propertyId = property is Map ? property['id']?.toString() : null;
        if (propertyId != null) widget.onOpenProperty?.call(propertyId);
        break;
      default:
        final property = recommendation['property'];
        final propertyId = property is Map ? property['id']?.toString() : null;
        if (propertyId != null) widget.onEditProperty?.call(propertyId);
    }
  }

  Widget _buildDashboardSection({
    required String title,
    required Widget child,
  }) {
    return _buildDesktopPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  color: _dark, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ─── SPLIT PROPERTY PERFORMANCE UI (UPDATED TO MATCH SCREENSHOT) ─────────────

  Widget _buildPropertyPerformancePanel() {
    if (!_dashboardAvailable) {
      return const SizedBox.shrink();
    }
    final properties = _propertyPerformance;

    // Reset index if out of bounds after filtering
    if (_selectedPerformancePropertyIndex >= properties.length &&
        properties.isNotEmpty) {
      _selectedPerformancePropertyIndex = 0;
    }

    final Map<String, dynamic>? selectedProperty = properties.isNotEmpty
        ? Map<String, dynamic>.from(
            properties[_selectedPerformancePropertyIndex])
        : null;

    final isDesktop = MediaQuery.sizeOf(context).width >= 1100;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (isDesktop || constraints.maxWidth >= 900) {
          return SizedBox(
            height: 760, // Fixed height for desktop to prevent overflow
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPerformanceLeftSidebar(properties),
                const SizedBox(width: 16),
                Expanded(
                  child: selectedProperty != null
                      ? _buildPerformanceMainDetail(selectedProperty)
                      : Container(
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
                          child: Center(
                            child: Text(_searchQuery.isEmpty
                                ? 'No properties to display yet.'
                                : 'No properties match this search.'),
                          ),
                        ),
                ),
              ],
            ),
          );
        } else {
          // Mobile responsive layout
          return Column(
            children: [
              _buildPerformanceLeftSidebar(properties, isMobile: true),
              const SizedBox(height: 16),
              if (selectedProperty != null)
                _buildPerformanceMainDetail(selectedProperty, isMobile: true),
              if (selectedProperty == null && !_loadingPropertyPerformance)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_searchQuery.isEmpty
                      ? 'No properties to display yet.'
                      : 'No properties match this search.'),
                ),
            ],
          );
        }
      },
    );
  }

  Widget _buildPerformanceLeftSidebar(List<dynamic> properties,
      {bool isMobile = false}) {
    return Container(
      width: isMobile ? double.infinity : 320,
      height: isMobile ? null : 760,
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
          if (!isMobile) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Properties',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _dark)),
              ],
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _searchController,
            onChanged: (value) {
              _propertyPerformanceRequestId++;
              setState(() => _searchQuery = value.trim());
              _propertySearchDebounce?.cancel();
              _propertySearchDebounce = Timer(
                const Duration(milliseconds: 300),
                () => _loadPropertyPerformance(search: value),
              );
            },
            style: GoogleFonts.poppins(fontSize: 13, color: _dark),
            decoration: InputDecoration(
              hintText: 'Search Properties',
              hintStyle: GoogleFonts.poppins(color: _grey, fontSize: 13),
              suffixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass,
                  color: _grey, size: 16),
              filled: true,
              fillColor: _surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _grey.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _grey.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _green),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (isMobile)
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = (constraints.maxWidth - 8) / 2;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var index = 0; index < properties.length; index++)
                          SizedBox(
                            width: tileWidth,
                            child: _buildPerformancePropertyTile(
                              properties,
                              index,
                              isMobile: true,
                            ),
                          ),
                      ],
                    ),
                    if (_loadingPropertyPerformance)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                            child: CircularProgressIndicator(color: _green)),
                      ),
                    if (_propertyPerformanceHasMore)
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: _loadingMorePropertyPerformance
                              ? null
                              : () => _loadPropertyPerformance(loadMore: true),
                          child: Text(_loadingMorePropertyPerformance
                              ? 'Loading…'
                              : 'Load more properties'),
                        ),
                      ),
                  ],
                );
              },
            )
          else
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Properties',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _dark)),
                      Text('$_propertyPerformanceTotal',
                          style:
                              GoogleFonts.poppins(fontSize: 12, color: _grey)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (var index = 0; index < properties.length; index++)
                    _buildPerformancePropertyTile(properties, index),
                  if (_loadingPropertyPerformance)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                          child: CircularProgressIndicator(color: _green)),
                    ),
                  if (_propertyPerformanceHasMore)
                    Center(
                      child: TextButton(
                        onPressed: _loadingMorePropertyPerformance
                            ? null
                            : () => _loadPropertyPerformance(loadMore: true),
                        child: Text(_loadingMorePropertyPerformance
                            ? 'Loading…'
                            : 'Load more properties'),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Pending inquiries',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _dark)),
                      Text('${_pendingInquiries.length}',
                          style:
                              GoogleFonts.poppins(fontSize: 12, color: _grey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_pendingInquiries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('No pending property inquiries.',
                          style:
                              GoogleFonts.poppins(fontSize: 12, color: _grey)),
                    )
                  else
                    for (final inquiry in _pendingInquiries.take(4))
                      _buildPendingInquiryTile(inquiry),
                ],
              ),
            ),

          const SizedBox(height: 16),
          // Bottom Actions Split Section
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _grey.withOpacity(0.1))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPendingReplies(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (properties.isEmpty) return;
                      final property = Map<String, dynamic>.from(
                        properties[_selectedPerformancePropertyIndex],
                      );
                      final propertyId = property['id']?.toString();
                      if (propertyId != null && propertyId.isNotEmpty) {
                        BoostListingModal.show(context, propertyId);
                      }
                    },
                    icon:
                        const Icon(PhosphorIconsRegular.rocketLaunch, size: 18),
                    label: Text('Boost listing',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _dark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  Widget _buildPendingInquiryTile(ConversationModel inquiry) {
    final name = inquiry.userName;
    final avatar = inquiry.userAvatar;
    final subtitle = [inquiry.property?.title, inquiry.lastMessage]
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .join(' · ');
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: ClipOval(
        child: avatar == null || avatar.isEmpty
            ? Container(
                width: 36,
                height: 36,
                color: const Color(0xFFF3F4F6),
                alignment: Alignment.center,
                child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _dark)),
              )
            : buildPropertyImage(avatar, width: 36, height: 36),
      ),
      title: Text(name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w600, color: _dark)),
      subtitle: Text(subtitle.isEmpty ? 'New property inquiry' : subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(fontSize: 11, color: _grey)),
      onTap: () => widget.onOpenConversation?.call(inquiry.conversationId!),
    );
  }

  Widget _buildPerformancePropertyTile(
    List<dynamic> properties,
    int index, {
    bool isMobile = false,
  }) {
    final property = Map<String, dynamic>.from(properties[index]);
    final isSelected = index == _selectedPerformancePropertyIndex;
    final city = property['location']?.toString() ??
        property['city']?.toString() ??
        'Location unavailable';

    return Column(
      children: [
        GestureDetector(
          onTap: () => _selectPerformanceProperty(index, properties),
          child: Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: isMobile ? 0 : 4, right: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF9FAFB) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isSelected ? _grey.withOpacity(0.15) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: buildPropertyImage(
                    _propertyPerformanceImage(property),
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorPlaceholder: Container(
                      width: 40,
                      height: 40,
                      color: _grey.withOpacity(0.1),
                      child: const Icon(PhosphorIconsRegular.image,
                          color: _grey, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property['title']?.toString() ?? 'Untitled',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: _dark,
                        ),
                      ),
                      Text(
                        city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 11, color: _grey),
                      ),
                    ],
                  ),
                ),
                if (isSelected && !isMobile)
                  const Icon(PhosphorIconsRegular.caretDown,
                      color: _dark, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceMainDetail(Map<String, dynamic> property,
      {bool isMobile = false}) {
    return SizedBox(
      height: isMobile ? null : 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPerformanceHeroCard(property, isMobile: isMobile),
          const SizedBox(height: 12),
          _buildPerformanceMetricsCard(property, isMobile: isMobile),
          const SizedBox(height: 12),
          if (isMobile)
            _buildPerformanceFunnelCard(property, isMobile: true)
          else
            Expanded(
              child: _buildPerformanceFunnelCard(property, isMobile: false),
            ),
        ],
      ),
    );
  }

  Widget _buildPerformanceHeroCard(Map<String, dynamic> property,
      {required bool isMobile}) {
    final imageUrl = _propertyPerformanceImage(property);
    final title = property['title']?.toString() ?? 'Untitled property';
    final location = property['location']?.toString() ??
        property['city']?.toString() ??
        'Location unavailable';
    return Container(
      height: isMobile ? 220 : 320,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: _bg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          buildPropertyImage(
            imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorPlaceholder: Container(
              color: _bg,
              child: const Icon(PhosphorIconsRegular.image,
                  color: _grey, size: 48),
            ),
          ),
          // Soft Gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: 24,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: isMobile ? 24 : 32,
                      fontWeight: FontWeight.w600,
                      height: 1.2),
                ),
                Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: _buildSelectedPropertyLeads(
                      isMobile: isMobile, property: property),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    final propertyId = property['id']?.toString();
                    if (propertyId == null || propertyId.isEmpty) return;
                    if (widget.onOpenProperty != null) {
                      widget.onOpenProperty!(propertyId);
                    } else {
                      Navigator.of(context).pushNamed(
                        '/landlord_property_management',
                        arguments: property,
                      );
                    }
                  },
                  icon: const Icon(PhosphorIconsRegular.buildings, size: 16),
                  label: Text('Manage',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.75)),
                    backgroundColor: Colors.black.withOpacity(0.25),
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPropertyLeads(
      {required bool isMobile, required Map<String, dynamic> property}) {
    final displayedLeads = _performanceLeads.take(3).toList();
    final stackWidth = displayedLeads.isEmpty
        ? 0.0
        : 32.0 + (displayedLeads.length - 1) * 20.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: stackWidth,
          height: 32,
          child: Stack(
            children: [
              for (var index = 0; index < displayedLeads.length; index++)
                Positioned(
                  left: index * 20.0,
                  child: _buildLeadAvatar(displayedLeads[index]),
                ),
            ],
          ),
        ),
        if (displayedLeads.isNotEmpty) const SizedBox(width: 12),
        Flexible(
          child: Text(
            _loadingPerformanceLeads
                ? 'Loading leads…'
                : '${_performanceLeads.length} high-intent leads',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildLeadAvatar(Map<String, dynamic> lead) {
    final name = lead['name']?.toString() ?? 'Lead';
    final avatar = lead['avatar']?.toString() ?? '';
    return Tooltip(
      message: name,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: ClipOval(
          child: avatar.isEmpty
              ? Container(
                  color: const Color(0xFFF3F4F6),
                  alignment: Alignment.center,
                  child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _dark)),
                )
              : buildPropertyImage(avatar, width: 32, height: 32),
        ),
      ),
    );
  }

  Widget _buildPerformanceMetricsCard(Map<String, dynamic> property,
      {required bool isMobile}) {
    int metric(String key) =>
        int.tryParse(property[key]?.toString() ?? '') ?? 0;

    final views = metric('views');
    final saves = metric('saves');
    final enquiries = metric('enquiries');
    final bookings = metric('bookings');
    double? change(String key) => property[key] is num
        ? (property[key] as num).toDouble()
        : double.tryParse(property[key]?.toString() ?? '');
    final format = NumberFormat.compact();

    final metricsWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildMetricItem(
              'Total Views', format.format(views), change('viewsChangePercent'),
              hasTrendData: property.containsKey('viewsChangePercent'),
              hasActivity: views > 0),
          _buildMetricItem('Saved / Favorites', format.format(saves),
              change('savesChangePercent'),
              hasTrendData: property.containsKey('savesChangePercent'),
              hasActivity: saves > 0),
          _buildMetricItem('Inquiries', format.format(enquiries),
              change('enquiriesChangePercent'),
              hasTrendData: property.containsKey('enquiriesChangePercent'),
              hasActivity: enquiries > 0),
          _buildMetricItem('Scheduled Viewings', format.format(bookings),
              change('bookingsChangePercent'),
              hasTrendData: property.containsKey('bookingsChangePercent'),
              hasActivity: bookings > 0),
        ],
      ),
    );

    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(width: 600, child: metricsWidget),
      );
    }
    return metricsWidget;
  }

  Widget _buildMetricItem(
    String label,
    String value,
    double? changePercent, {
    required bool hasTrendData,
    required bool hasActivity,
  }) {
    final hasComparablePeriod = hasTrendData && changePercent != null;
    final isPositive = changePercent != null && changePercent >= 0;
    final color = !hasTrendData || (changePercent == null && !hasActivity)
        ? _grey
        : isPositive
            ? _green
            : const Color(0xFFEF4444);
    final bgColor = color.withOpacity(0.12);
    final arrowIcon = isPositive
        ? PhosphorIconsRegular.arrowUp
        : PhosphorIconsRegular.arrowDown;
    final trendLabel = hasComparablePeriod
        ? '${changePercent > 0 ? '+' : ''}${changePercent.toStringAsFixed(1)}%'
        : !hasTrendData
            ? 'Unavailable'
            : hasActivity
                ? 'New'
                : 'No baseline';

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 13, color: _grey)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 32, // Large metric font size
                  fontWeight: FontWeight.w600,
                  color: _dark,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasComparablePeriod) ...[
                      Icon(arrowIcon, size: 10, color: color),
                      const SizedBox(width: 2),
                    ],
                    Text(trendLabel,
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceFunnelCard(Map<String, dynamic> property,
      {required bool isMobile}) {
    int metric(String key) =>
        int.tryParse(property[key]?.toString() ?? '') ?? 0;

    final views = metric('views');
    final clicks = metric('clicks');
    final inquiries = metric('enquiries');
    final viewings = metric('bookings');
    double rate(int count, int denominator) =>
        denominator > 0 ? count / denominator : 0.0;
    String percentage(double value) {
      final percent = double.parse((value * 100).toStringAsFixed(1));
      return '${percent == percent.roundToDouble() ? percent.toInt() : percent}%';
    }

    String? dropOff(int current, int previous, String action) {
      if (previous <= 0 || current >= previous) return null;
      final percent = double.parse(
          (((previous - current) / previous) * 100).toStringAsFixed(1));
      final displayPercent =
          percent == percent.roundToDouble() ? percent.toInt() : percent;
      return '-$displayPercent% $action';
    }

    final format = NumberFormat("#,###");

    if (views == 0) {
      final propertyId = property['id']?.toString();
      final emptyState = Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(PhosphorIconsRegular.chartBar, color: _grey, size: 28),
            const SizedBox(height: 10),
            Text('Not enough data yet',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600, color: _dark)),
            const SizedBox(height: 4),
            Text('This listing has no views in the selected period.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 12, color: _grey)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: propertyId == null || propertyId.isEmpty
                  ? null
                  : () => BoostListingModal.show(context, propertyId),
              icon: const Icon(PhosphorIconsRegular.rocketLaunch, size: 16),
              label: const Text('Boost listing'),
              style: FilledButton.styleFrom(
                backgroundColor: _dark,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
      return isMobile ? SizedBox(height: 300, child: emptyState) : emptyState;
    }

    final funnelWidget = Container(
      padding: const EdgeInsets.all(32),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Funnel Header
          Text('Conversion Funnel',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600, color: _dark)),
          const SizedBox(height: 4),
          Text('Stage counts and drop-off for the selected period.',
              style: GoogleFonts.poppins(fontSize: 13, color: _grey)),
          const SizedBox(height: 32),

          // Funnel Rows
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildFunnelRow(
                    'Views',
                    '100%',
                    format.format(views),
                    1,
                    isBaseline: true,
                  ),
                  const SizedBox(height: 18),
                  _buildFunnelRow(
                    'Clicks',
                    percentage(rate(clicks, views)),
                    format.format(clicks),
                    rate(clicks, views),
                    dropOff: dropOff(clicks, views, 'did not click'),
                  ),
                  const SizedBox(height: 18),
                  _buildFunnelRow(
                    'Inquiries',
                    percentage(rate(inquiries, views)),
                    format.format(inquiries),
                    rate(inquiries, views),
                    dropOff: dropOff(inquiries, clicks, 'did not inquire'),
                  ),
                  const SizedBox(height: 18),
                  _buildFunnelRow(
                    'Viewings',
                    percentage(rate(viewings, views)),
                    format.format(viewings),
                    rate(viewings, views),
                    dropOff: dropOff(viewings, inquiries, 'did not schedule'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (isMobile) {
      return SizedBox(
        height: 420,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: 650, child: funnelWidget),
        ),
      );
    }

    return funnelWidget;
  }

  Widget _buildFunnelRow(
    String label,
    String pctStr,
    String valueStr,
    double fraction, {
    bool isBaseline = false,
    String? dropOff,
  }) {
    return Row(
      children: [
        Icon(PhosphorIconsRegular.info,
            size: 16, color: _grey.withOpacity(0.5)),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w500, color: _dark)),
        ),
        SizedBox(
          width: 60,
          child: Text(pctStr,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _dark)),
        ),
        SizedBox(
          width: 70,
          child: Text(valueStr,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _dark)),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 12,
              child: isBaseline
                  ? CustomPaint(
                      painter: const HatchedPainter(color: Color(0xFFD1D5DB)),
                    )
                  : Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: fraction.clamp(0.0, 1.0),
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF9CA3AF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 4,
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

  Future<void> _loadPerformanceLeads(String propertyId) async {
    if (propertyId.isEmpty || _performanceLeadsPropertyId == propertyId) return;
    final requestId = ++_performanceLeadsRequestId;
    setState(() {
      _performanceLeadsPropertyId = propertyId;
      _performanceLeads = const [];
      _loadingPerformanceLeads = true;
    });
    final response =
        await LandlordDashboardService.getPropertyManagementData(propertyId);
    if (!mounted || requestId != _performanceLeadsRequestId) return;
    final rawLeads = response?['leads'];
    setState(() {
      _performanceLeads = rawLeads is List
          ? rawLeads
              .whereType<Map>()
              .map((lead) => Map<String, dynamic>.from(lead))
              .toList()
          : const [];
      _loadingPerformanceLeads = false;
    });
  }

  void _selectPerformanceProperty(int index, List<dynamic> properties) {
    final property = Map<String, dynamic>.from(properties[index]);
    setState(() => _selectedPerformancePropertyIndex = index);
    _loadPerformanceLeads(property['id']?.toString() ?? '');
  }

  List<Map<String, dynamic>> get _unansweredRecommendations {
    final raw = _analyticsData['recommendations'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => item['type'] == 'unanswered_enquiry')
        .toList();
  }

  Widget _buildPendingReplies() {
    final pending = _unansweredRecommendations.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_dashboardAvailable && pending.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('No unanswered property messages.',
                style: GoogleFonts.poppins(fontSize: 12, color: _grey)),
          ),
        for (final item in pending)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.3)),
            ),
            child: ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(PhosphorIconsRegular.chatTeardropText,
                    size: 16, color: Color(0xFFB54708)),
              ),
              title: Text(
                item['property'] is Map
                    ? (item['property'] as Map)['title']?.toString() ??
                        'Property inquiry'
                    : 'Property inquiry',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _dark),
              ),
              subtitle: Text(
                item['body']?.toString() ?? 'A tenant is waiting for a reply.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 11, color: _grey),
              ),
              onTap: () {
                final id = item['conversationId']?.toString();
                if (id != null && id.isNotEmpty) {
                  widget.onOpenConversation?.call(id);
                } else {
                  widget.onViewUnansweredMessages?.call();
                }
              },
            ),
          ),
      ],
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

  Widget _buildDesktopViewsPanel() {
    final views = _kpi('views');
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
                    Text('Property detail views',
                        style: GoogleFonts.poppins(
                            color: _dark,
                            fontWeight: FontWeight.w600,
                            fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      _dashboardAvailable
                          ? views['total']?.toString() ?? '0'
                          : 'Unavailable',
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
                  color: _dashboardAvailable
                      ? const Color(0xFFE8F4F1)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20), // Pill shape
                ),
                child: Text(
                  _dashboardAvailable
                      ? views['growth']?.toString() ?? '—'
                      : 'Unavailable',
                  style: GoogleFonts.poppins(
                      color: _dashboardAvailable ? _green : _grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Counts one detail view per signed-in tenant/property per day.',
            style: GoogleFonts.poppins(color: _grey, fontSize: 11),
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
        metrics['avgCtr'] is num
            ? '${(metrics['avgCtr'] as num).toStringAsFixed(1)}%'
            : 'Not enough data',
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

  Widget _buildDesktopDashboard() {
    return Scaffold(
      backgroundColor:
          _bg, // Keeps background canvas visually separate from cards
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
                            borderRadius:
                                BorderRadius.circular(30), // Pill shape
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
                                DropdownMenuItem(
                                    value: 'Last 90 Days',
                                    child: Text('Last 90 days')),
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
                                borderRadius:
                                    BorderRadius.circular(30)), // Pill button
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildKpiGrid(compact: false),
                    const SizedBox(height: 14),
                    _buildRecommendations(),
                    const SizedBox(height: 14),
                    _buildPropertyPerformancePanel(),
                    const SizedBox(height: 14),
                    _buildDesktopViewsPanel(),
                    const SizedBox(height: 14),
                    _buildDesktopEngagementPanel(),
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
                              child: const Icon(
                                  PhosphorIconsRegular.warningCircle,
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

                Align(
                  alignment: Alignment.centerRight,
                  child: DropdownButton<String>(
                    value: _selectedAnalyticsPeriod,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                          value: 'This Week', child: Text('Last 7 days')),
                      DropdownMenuItem(
                          value: 'Last 28 Days', child: Text('Last 28 days')),
                      DropdownMenuItem(
                          value: 'Last 90 Days', child: Text('Last 90 days')),
                    ],
                    onChanged: (period) {
                      if (period == null) return;
                      setState(() => _selectedAnalyticsPeriod = period);
                      _loadData();
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // ─── STATS GRID ───
                _isLoading
                    ? _buildShimmerStats()
                    : _buildKpiGrid(compact: true),
                const SizedBox(height: 24),
                _buildRecommendations(),
                const SizedBox(height: 16),
                _buildPropertyPerformancePanel(),
                const SizedBox(height: 24),

                // ─── VIEW ANALYTICS BUTTON ───
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _openAnalytics,
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

  String _propertyPerformanceImage(Map<String, dynamic> property) =>
      mapApiProperty(property).image;
}

class _DashboardKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;

  const _DashboardKpiCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.onTap,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final label = '$title. $value. $detail';
    return Semantics(
      button: onTap != null,
      label: label,
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 170),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 20, color: _green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: _dark,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (loading)
                    const SizedBox(
                      height: 28,
                      width: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _green,
                      ),
                    )
                  else
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color:
                            value == 'Not enough data' || value == 'Unavailable'
                                ? _grey
                                : _dark,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    detail,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: _grey,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Icon(PhosphorIconsRegular.arrowUpRight,
                        size: 16, color: onTap == null ? _grey : _green),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
