import 'dart:async';

import 'package:flutter/material.dart';
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
const Color _bg = Color.fromARGB(0, 255, 255, 255); //TRANSPARENT
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981);

// Reusable Soft Shadow for Premium Feel
final List<BoxShadow> _premiumShadow = [
  BoxShadow(
    color: Colors.black.withOpacity(0.04),
    blurRadius: 24,
    offset: const Offset(0, 8),
  ),
];

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
  final PageController _topPropertiesPageController = PageController();
  Timer? _topPropertiesCarouselTimer;
  int _topPropertiesCarouselIndex = 0;
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
    _topPropertiesCarouselTimer?.cancel();
    _topPropertiesPageController.dispose();
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
      limit: 6,
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
      if (!loadMore) {
        _selectedPerformancePropertyIndex = 0;
        _topPropertiesCarouselIndex = 0;
      }
    });
    if (!loadMore && _topPropertiesPageController.hasClients) {
      _topPropertiesPageController.jumpToPage(0);
    }
    _scheduleTopPropertiesAdvance();
    if (firstPropertyId != null && firstPropertyId.isNotEmpty) {
      unawaited(_loadPerformanceLeads(firstPropertyId));
    }
  }

  Map<String, dynamic> _analyticsSection(String key) {
    final value = _analyticsData[key];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  Map<String, dynamic> _kpi(String key) => _dashboardAvailable
      ? _analyticsSection('kpis')[key] is Map
          ? Map<String, dynamic>.from(_analyticsSection('kpis')[key] as Map)
          : <String, dynamic>{}
      : <String, dynamic>{};

  String _displayRate(Object? value) =>
      value is num ? '${value.toStringAsFixed(1)}%' : 'Not enough data';

  void _openAllProperties() {
    if (widget.onViewAllProperties != null) {
      widget.onViewAllProperties!();
    } else {
      Navigator.of(context).pushNamed('/landlord_properties');
    }
  }

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

  // ─── UI BUILDERS ─────────────────────────────────────────────────────────────

  Widget _buildShimmerStats({required bool compact}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = compact || constraints.maxWidth < 1100 ? 2 : 4;
        const spacing = 16.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(
            4,
            (index) => SizedBox(
              width: cardWidth,
              child: Shimmer.fromColors(
                baseColor: Colors.grey.shade200,
                highlightColor: Colors.grey.shade100,
                child: Container(
                  height: 180,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: cardWidth * 0.42,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: (cardWidth - 48) * 0.78,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: cardWidth * 0.62,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
            ? '${properties['published'] ?? 0} published · ${properties['pending'] ?? 0} pending · ${properties['draft'] ?? 0} drafts · ${properties['rented'] ?? 0} rented'
            : 'Property counts could not be loaded.',
        icon: PhosphorIconsRegular.buildings,
        onTap: _openAllProperties,
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
        title: 'Conversations',
        value:
            _dashboardAvailable ? '${enquiries['total'] ?? 0}' : 'Unavailable',
        detail: _dashboardAvailable
            ? '${enquiries['uniqueTenants'] ?? 0} distinct tenants engaged'
            : 'Conversation data could not be loaded.',
        icon: PhosphorIconsRegular.chatTeardropText,
        onTap: widget.onViewMessages,
        loading: _isLoading,
      ),
      _DashboardKpiCard(
        title: 'Pending Bookings',
        value: _dashboardAvailable
            ? '${pendingBookings['count'] ?? 0}'
            : 'Unavailable',
        detail: 'Current requests requiring landlord action.',
        icon: PhosphorIconsRegular.calendarCheck,
        onTap: widget.onViewBookings,
        loading: _isLoading,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = compact
            ? 2
            : constraints.maxWidth >= 1100
                ? 4
                : 2;
        final gap = 16.0;
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

    return _buildDesktopPanel(
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
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: priority == 'high'
                        ? const Color(0xFFFEF2F2)
                        : _green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    priority == 'high'
                        ? PhosphorIconsRegular.warningCircle
                        : PhosphorIconsRegular.lightbulb,
                    color:
                        priority == 'high' ? const Color(0xFFB42318) : _green,
                    size: 20,
                  ),
                ),
                title: Text(
                    recommendation['title']?.toString() ?? 'Review item',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  '${recommendation['body'] ?? ''}${propertyMap['title'] == null ? '' : '\n${propertyMap['title']}'}',
                  style: GoogleFonts.poppins(fontSize: 12, color: _grey),
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
                child: FilledButton.tonal(
                  onPressed: () => _handleRecommendation(recommendation),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F4F6),
                    foregroundColor: _dark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child:
                      Text(recommendation['actionText']?.toString() ?? 'Open'),
                ),
              ),
              if (recommendation != rows.last)
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
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

  Widget _buildDesktopPanel({
    String? title,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(32),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(32), // Premium bubble radius
        boxShadow: _premiumShadow,
        border: Border.all(
            color: const Color(0xFFF3F4F6),
            width: 1), // Subtle border for pure white bg
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title,
                style: GoogleFonts.poppins(
                    color: _dark, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
          ],
          child,
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _topPerformingProperties =>
      _propertyPerformance.take(5).toList();

  void _scheduleTopPropertiesAdvance() {
    _topPropertiesCarouselTimer?.cancel();
    final itemCount = _topPerformingProperties.length + 1;
    if (!mounted || itemCount < 2) return;

    _topPropertiesCarouselTimer = Timer(const Duration(seconds: 30), () {
      if (!mounted || !_topPropertiesPageController.hasClients) return;
      final nextPage = (_topPropertiesCarouselIndex + 1) % itemCount;
      _topPropertiesPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _changeTopPropertyPage(int direction) {
    if (!_topPropertiesPageController.hasClients) return;
    final itemCount = _topPerformingProperties.length + 1;
    if (itemCount < 2) return;
    final nextPage =
        (_topPropertiesCarouselIndex + direction + itemCount) % itemCount;
    _topPropertiesPageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
    );
  }

  Widget _buildTopPropertiesCarouselSkeleton(double height) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 24,
              left: 24,
              child: _shimmerBlock(116, 28, radius: 20),
            ),
            Positioned(
              top: 24,
              right: 24,
              child: Row(
                children: [
                  _shimmerBlock(42, 42, radius: 21),
                  const SizedBox(width: 8),
                  _shimmerBlock(42, 42, radius: 21),
                ],
              ),
            ),
            Positioned(
              left: 28,
              right: 28,
              bottom: 38,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBlock(180, 30, radius: 8),
                  const SizedBox(height: 10),
                  _shimmerBlock(180, 14, radius: 6),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _shimmerBlock(48, 30, radius: 6),
                      const SizedBox(width: 12),
                      _shimmerBlock(48, 30, radius: 6),
                      const SizedBox(width: 12),
                      _shimmerBlock(48, 30, radius: 6),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _shimmerBlock(150, 48, radius: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBlock(double width, double height, {double radius = 8}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildTopPropertiesCarousel() {
    final properties = _topPerformingProperties;
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final height = isMobile ? 360.0 : 440.0;

    if (!_dashboardAvailable) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile) ...[
          Text(
            'Top Highlights',
            style: GoogleFonts.poppins(
              color: _dark,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (properties.isEmpty && _loadingPropertyPerformance)
          _buildTopPropertiesCarouselSkeleton(height)
        else
          Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: _premiumShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _topPropertiesPageController,
                    itemCount: properties.length + 1,
                    onPageChanged: (index) {
                      setState(() => _topPropertiesCarouselIndex = index);
                      _scheduleTopPropertiesAdvance();
                    },
                    itemBuilder: (context, index) => index < properties.length
                        ? _buildTopPropertySlide(properties[index], index)
                        : _buildBoostListingsSlide(properties,
                            isMobile: isMobile),
                  ),
                  if (properties.length + 1 > 1) ...[
                    Positioned(
                      right: 24,
                      top: 24,
                      child: Row(
                        children: [
                          _buildCarouselArrow(
                            PhosphorIconsRegular.caretLeft,
                            () => _changeTopPropertyPage(-1),
                          ),
                          const SizedBox(width: 8),
                          _buildCarouselArrow(
                            PhosphorIconsRegular.caretRight,
                            () => _changeTopPropertyPage(1),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 32,
                      bottom: 32,
                      child: Row(
                        children: List.generate(
                          properties.length + 1,
                          (index) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: GestureDetector(
                              onTap: () =>
                                  _topPropertiesPageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 700),
                                curve: Curves.easeInOutCubic,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: index == _topPropertiesCarouselIndex
                                    ? 28
                                    : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(
                                      index == _topPropertiesCarouselIndex
                                          ? 1
                                          : 0.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCarouselArrow(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.black.withOpacity(0.25),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildBoostListingsSlide(
    List<Map<String, dynamic>> properties, {
    required bool isMobile,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/boost.png',
          fit: BoxFit.cover,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.white.withOpacity(0.78),
              ],
              stops: const [0.42, 1],
            ),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'BOOST LISTINGS',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF27804F),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Put your listing in the spotlight.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: _dark,
                    fontSize: isMobile ? 26 : 36,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Reach more renters and stand out in search.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF45634E),
                    fontSize: isMobile ? 15 : 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () {
                      final propertyId =
                          properties.firstOrNull?['id']?.toString();
                      if (propertyId == null || propertyId.isEmpty) {
                        _openAllProperties();
                        return;
                      }
                      BoostListingModal.show(context, propertyId);
                    },
                    icon:
                        const Icon(PhosphorIconsRegular.rocketLaunch, size: 17),
                    label: Text(
                      'Boost a listing',
                      style: GoogleFonts.poppins(
                        fontSize: isMobile ? 15 : 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF27804F),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 22 : 28,
                        vertical: isMobile ? 16 : 19,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopPropertySlide(Map<String, dynamic> property, int index) {
    final id = property['id']?.toString();
    final title = property['title']?.toString() ?? 'Untitled property';
    final location = property['location']?.toString() ??
        property['city']?.toString() ??
        'Location unavailable';
    final views = int.tryParse(property['views']?.toString() ?? '') ?? 0;
    final enquiries =
        int.tryParse(property['enquiries']?.toString() ?? '') ?? 0;
    final bookings = int.tryParse(property['bookings']?.toString() ?? '') ?? 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        buildPropertyImage(
          _propertyPerformanceImage(property),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorPlaceholder: Container(
            color: const Color(0xFF6FAF7D),
            child: const Icon(PhosphorIconsRegular.houseLine,
                color: Colors.white70, size: 56),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF6FAF7D).withOpacity(0.12),
                Colors.transparent,
                const Color(0xFF3F8050).withOpacity(0.82),
              ],
              stops: const [0, 0.4, 1],
            ),
          ),
        ),
        Positioned(
          top: 24,
          left: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Text(
              'TOP ${index + 1} PERFORMER',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
        Positioned(
          left: 32,
          right: 32,
          bottom: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 32,
                runSpacing: 12,
                children: [
                  _buildTopPropertyStat('Total Views', views),
                  _buildTopPropertyStat('Enquiries', enquiries),
                  _buildTopPropertyStat('Bookings', bookings),
                ],
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: id == null || id.isEmpty
                      ? null
                      : () => widget.onOpenProperty?.call(id),
                  icon: const Icon(PhosphorIconsRegular.arrowUpRight, size: 17),
                  label: Text('View Details',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color.fromARGB(255, 13, 51, 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopPropertyStat(String label, int value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          NumberFormat('#,###').format(value),
          style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
              color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ─── SPLIT PROPERTY PERFORMANCE UI ─────────────

  Widget _buildPropertyPerformancePanel() {
    if (!_dashboardAvailable) {
      return const SizedBox.shrink();
    }
    final properties = _propertyPerformance;

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
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPerformanceLeftSidebar(properties),
              const SizedBox(width: 24),
              Expanded(
                child: selectedProperty != null
                    ? _buildPerformanceMainDetail(selectedProperty)
                    : Container(
                        height: 760,
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: _premiumShadow,
                        ),
                        child: Center(
                          child: Text(_searchQuery.isEmpty
                              ? 'No properties to display yet.'
                              : 'No properties match this search.'),
                        ),
                      ),
              ),
            ],
          );
        } else {
          // Mobile responsive layout
          return Column(
            children: [
              _buildPerformanceLeftSidebar(properties, isMobile: true),
              const SizedBox(height: 24),
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
      width: isMobile ? double.infinity : 360,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: _premiumShadow,
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Properties',
                  style: GoogleFonts.poppins(
                      fontSize: 20, fontWeight: FontWeight.w700, color: _dark)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$_propertyPerformanceTotal',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _dark)),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
            style: GoogleFonts.poppins(
                fontSize: 14, color: _dark, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Search properties...',
              hintStyle: GoogleFonts.poppins(color: _grey, fontSize: 14),
              prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass,
                  color: _grey, size: 20),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (isMobile)
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = (constraints.maxWidth - 12) / 2;
                return Column(
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
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
                  ],
                );
              },
            )
          else ...[
            for (var index = 0; index < properties.length && index < 5; index++)
              _buildPerformancePropertyTile(properties, index),
            if (_loadingPropertyPerformance)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(color: _green)),
              ),
          ],

          if (_propertyPerformanceHasMore)
            Center(
              child: TextButton(
                onPressed: _loadingMorePropertyPerformance
                    ? null
                    : () => _loadPropertyPerformance(loadMore: true),
                style: TextButton.styleFrom(
                    foregroundColor: _dark,
                    textStyle:
                        GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                child: Text(_loadingMorePropertyPerformance
                    ? 'Loading…'
                    : 'Show more properties'),
              ),
            ),

          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 24),

          _buildPendingInquiriesSection(),

          const SizedBox(height: 24),
          // Bottom Actions
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
              icon: const Icon(PhosphorIconsRegular.rocketLaunch, size: 18),
              label: Text('Boost Listing',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              style: FilledButton.styleFrom(
                backgroundColor: _dark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingInquiriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Pending Inquiries',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _dark)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12)),
              child: Text('${_pendingInquiries.length}',
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _dark)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_pendingInquiries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('You are all caught up!',
                style: GoogleFonts.poppins(fontSize: 13, color: _grey)),
          )
        else
          for (final inquiry in _pendingInquiries)
            _buildPendingInquiryTile(inquiry),
      ],
    );
  }

  Widget _buildPendingInquiryTile(ConversationModel inquiry) {
    final name = inquiry.userName;
    final avatar = inquiry.userAvatar;
    final subtitle = [inquiry.property?.title, inquiry.lastMessage]
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipOval(
          child: avatar == null || avatar.isEmpty
              ? Container(
                  width: 44,
                  height: 44,
                  color: const Color(0xFFF9FAFB),
                  alignment: Alignment.center,
                  child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _dark)),
                )
              : buildPropertyImage(avatar, width: 44, height: 44),
        ),
        title: Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w700, color: _dark)),
        subtitle: Text(subtitle.isEmpty ? 'New property inquiry' : subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
                fontSize: 12, color: _grey, fontWeight: FontWeight.w500)),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6), shape: BoxShape.circle),
          child: const Icon(PhosphorIconsRegular.arrowUpRight,
              size: 16, color: _dark),
        ),
        onTap: () => widget.onOpenConversation?.call(inquiry.conversationId!),
      ),
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

    return GestureDetector(
      onTap: () => _selectPerformanceProperty(index, properties),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: double.infinity,
        margin: EdgeInsets.only(bottom: isMobile ? 0 : 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? _green.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? _green.withOpacity(0.3) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: buildPropertyImage(
                _propertyPerformanceImage(property),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorPlaceholder: Container(
                  width: 56,
                  height: 56,
                  color: _grey.withOpacity(0.1),
                  child: const Icon(PhosphorIconsRegular.image,
                      color: _grey, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 16),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _grey),
                  ),
                ],
              ),
            ),
            if (!isMobile && isSelected)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsRegular.arrowUpRight,
                  color: _dark,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceMainDetail(Map<String, dynamic> property,
      {bool isMobile = false}) {
    return SizedBox(
      height: isMobile ? null : 920,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPerformanceHeroCard(property, isMobile: isMobile),
          const SizedBox(height: 24),
          _buildPerformanceMetricsCard(property, isMobile: isMobile),
          const SizedBox(height: 24),
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

    if (isMobile) {
      return Container(
        height: 280,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: _dark,
          boxShadow: _premiumShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            buildPropertyImage(imageUrl, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.8)
                  ],
                ),
              ),
            ),
            Positioned(
                bottom: 24,
                left: 24,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700)),
                    Text(location,
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 14)),
                  ],
                ))
          ],
        ),
      );
    }

    // Full Bleed to the Left, Top, and Bottom configuration
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: _premiumShadow,
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(32)), // Full Bleed Left
              child: buildPropertyImage(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorPlaceholder: Container(
                  color: const Color(0xFFF3F4F6),
                  child: const Icon(PhosphorIconsRegular.image,
                      color: _grey, size: 48),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: _dark,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(PhosphorIconsFill.mapPin,
                          color: _grey, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        location,
                        style: GoogleFonts.poppins(
                          color: _grey,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: _buildSelectedPropertyLeads(
                            isMobile: false, property: property),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
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
                        icon: const Icon(PhosphorIconsRegular.slidersHorizontal,
                            size: 18),
                        label: Text('Manage',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                          backgroundColor: _dark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 20),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPropertyLeads(
      {required bool isMobile, required Map<String, dynamic> property}) {
    final displayedLeads = _performanceLeads.take(4).toList();
    final stackWidth = displayedLeads.isEmpty
        ? 0.0
        : 40.0 + (displayedLeads.length - 1) * 24.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: stackWidth,
          height: 40,
          child: Stack(
            children: [
              for (var index = 0; index < displayedLeads.length; index++)
                Positioned(
                  left: index * 24.0,
                  child: _buildLeadAvatar(displayedLeads[index]),
                ),
            ],
          ),
        ),
        if (displayedLeads.isNotEmpty) const SizedBox(width: 16),
        Flexible(
          child: Text(
            _loadingPerformanceLeads
                ? 'Loading leads…'
                : '${_performanceLeads.length} Hot Leads',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
                color: _dark, fontSize: 14, fontWeight: FontWeight.w600),
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: ClipOval(
          child: avatar.isEmpty
              ? Container(
                  color: const Color(0xFFF9FAFB),
                  alignment: Alignment.center,
                  child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _dark)),
                )
              : buildPropertyImage(avatar, width: 40, height: 40),
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
    double change(String key, int current) {
      final raw = property[key];
      final parsed =
          raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
      if (parsed != null) return parsed;
      return current > 0 ? 100 : 0;
    }

    final format = NumberFormat.compact();

    // Restored Original Horizontal Metrics layout directly inside the premium panel
    final metricsWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: _premiumShadow,
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildMetricItem('Total Views', format.format(views),
              change('viewsChangePercent', views)),
          _buildMetricItem('Saved / Favorites', format.format(saves),
              change('savesChangePercent', saves)),
          _buildMetricItem('Inquiries', format.format(enquiries),
              change('enquiriesChangePercent', enquiries)),
          _buildMetricItem('Scheduled Viewings', format.format(bookings),
              change('bookingsChangePercent', bookings)),
        ],
      ),
    );

    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(width: 700, child: metricsWidget),
      );
    }
    return metricsWidget;
  }

  Widget _buildMetricItem(
    String label,
    String value,
    double? changePercent,
  ) {
    final change = changePercent ?? 0.0;
    final isPositive = change > 0;
    final color = change == 0
        ? _grey
        : isPositive
            ? _green
            : const Color(0xFFEF4444);
    final bgColor = color.withOpacity(0.12);
    final arrowIcon = isPositive
        ? PhosphorIconsRegular.arrowUp
        : PhosphorIconsRegular.arrowDown;
    final trendLabel = '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)}%';

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: _grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 36, // Impressive display font sizing
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: _dark,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(arrowIcon, size: 12, color: color),
                    const SizedBox(width: 4),
                    Text(trendLabel,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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

    final maxCount = [views, clicks, inquiries, viewings]
        .fold<int>(0, (max, value) => value > max ? value : max);
    final denominator = maxCount > 0 ? maxCount : 1;

    double fraction(int count) => count / denominator;

    String percentage(int count) {
      if (views <= 0) return '0%';
      final pct = (count / views) * 100;
      return '${pct % 1 == 0 ? pct.toInt() : pct.toStringAsFixed(1)}%';
    }

    String? dropOff(int current, int previous, String action) {
      if (previous <= 0) {
        return current <= 0 ? '0% drop-off' : 'No previous-stage baseline';
      }
      if (current == previous) return '0% drop-off';
      if (current > previous) {
        final pct = ((current - previous) / previous) * 100;
        final formatted = pct % 1 == 0 ? pct.toInt() : pct.toStringAsFixed(1);
        return '+$formatted% above previous stage';
      }
      final pct = ((previous - current) / previous) * 100;
      return '-${pct % 1 == 0 ? pct.toInt() : pct.toStringAsFixed(1)}% $action';
    }

    final format = NumberFormat('#,###');

    // Conversion funnel
    final funnelWidget = Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: _premiumShadow,
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Conversion Funnel',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 8),
          Text('Stage counts and drop-off for the selected period.',
              style: GoogleFonts.poppins(fontSize: 14, color: _grey)),
          SizedBox(height: isMobile ? 20 : 28),
          Column(
            children: [
              _buildFunnelRow(
                'Views',
                views > 0 ? '100%' : '0%',
                format.format(views),
                fraction(views),
                isBaseline: true,
              ),
              SizedBox(height: isMobile ? 16 : 20),
              _buildFunnelRow(
                'Clicks',
                percentage(clicks),
                format.format(clicks),
                fraction(clicks),
                dropOff: dropOff(clicks, views, 'did not click'),
              ),
              SizedBox(height: isMobile ? 16 : 20),
              _buildFunnelRow(
                'Inquiries',
                percentage(inquiries),
                format.format(inquiries),
                fraction(inquiries),
                dropOff: dropOff(inquiries, clicks, 'did not inquire'),
              ),
              SizedBox(height: isMobile ? 16 : 20),
              _buildFunnelRow(
                'Viewings',
                percentage(viewings),
                format.format(viewings),
                fraction(viewings),
                dropOff: dropOff(viewings, inquiries, 'did not schedule'),
              ),
            ],
          ),
        ],
      ),
    );

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
    final barColor = isBaseline ? _green : const Color(0xFFD1D5DB);

    final dropText = isBaseline ? '' : (dropOff ?? '0% drop-off');
    final dropColor = dropText.startsWith('+')
        ? _green
        : dropText.startsWith('-')
            ? const Color(0xFFEF4444)
            : _grey;

    return LayoutBuilder(
      builder: (context, constraints) {
        const labelWidth = 100.0;
        const pctWidth = 64.0;
        const valueWidth = 80.0;
        if (constraints.maxWidth < 500) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(PhosphorIconsRegular.info,
                      size: 18, color: _grey.withOpacity(0.5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(label,
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _dark)),
                  ),
                  Text(pctStr,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _dark)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 56,
                    child: Text(valueStr,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _dark)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LayoutBuilder(
                  builder: (context, barConstraints) => Container(
                    width: barConstraints.maxWidth * fraction.clamp(0.0, 1.0),
                    height: 12,
                    decoration: BoxDecoration(
                      color: isBaseline ? Colors.transparent : barColor,
                    ),
                    child: isBaseline
                        ? CustomPaint(painter: HatchedPainter(color: barColor))
                        : null,
                  ),
                ),
              ),
              if (dropText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    dropText,
                    softWrap: true,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: dropColor,
                    ),
                  ),
                ),
            ],
          );
        }

        final availableWidth = math.max(
          0.0,
          constraints.maxWidth -
              24.0 -
              8.0 -
              labelWidth -
              pctWidth -
              valueWidth -
              24.0,
        );
        final barWidth = availableWidth * fraction.clamp(0.0, 1.0);
        final labelLeft = (barWidth + 12).clamp(0.0, availableWidth * 0.45);
        final dropLabelWidth =
            (availableWidth - labelLeft).clamp(0.0, availableWidth);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(PhosphorIconsRegular.info,
                size: 20, color: _grey.withOpacity(0.5)),
            const SizedBox(width: 12),
            SizedBox(
              width: labelWidth,
              child: Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600, color: _dark)),
            ),
            SizedBox(
              width: pctWidth,
              child: Text(pctStr,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700, color: _dark)),
            ),
            SizedBox(
              width: valueWidth,
              child: Text(valueStr,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700, color: _dark)),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: barWidth,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isBaseline ? Colors.transparent : barColor,
                      ),
                      child: isBaseline
                          ? CustomPaint(
                              painter: HatchedPainter(color: barColor),
                            )
                          : null,
                    ),
                  ),
                  if (dropText.isNotEmpty)
                    Padding(
                      padding:
                          EdgeInsets.only(left: labelLeft.toDouble(), top: 6),
                      child: SizedBox(
                        width: dropLabelWidth.toDouble(),
                        child: Text(
                          dropText,
                          softWrap: true,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: dropColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
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

  // ─── DESKTOP SPECIFIC BUILDERS (PREMIUM GRID) ───────────────

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
        final itemWidth = (constraints.maxWidth - (24 * 3)) / 4;
        return Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _buildDesktopPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item.$3, color: _dark, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    color: _dark,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800)),
                            Text(item.$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    color: _grey,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
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
      backgroundColor: _bg, // Pure White
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _green,
          backgroundColor: _surface,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(40, 32, 40, 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Premium Header Nav
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: _premiumShadow,
                            border: Border.all(
                                color: const Color(0xFFF3F4F6), width: 1),
                          ),
                          child: const Icon(PhosphorIconsFill.squaresFour,
                              color: _dark, size: 28),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Overview',
                                style: GoogleFonts.poppins(
                                  color: _dark,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.0,
                                ),
                              ),
                              Text(
                                'Welcome back, ${AppSession.displayName.split(' ').first} 👋',
                                style: GoogleFonts.poppins(
                                    color: _grey,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        // Pill Filters
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: _premiumShadow,
                            border: Border.all(
                                color: const Color(0xFFF3F4F6), width: 1),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedAnalyticsPeriod,
                              isDense: true,
                              icon: const Padding(
                                padding: EdgeInsets.only(left: 8.0),
                                child: Icon(PhosphorIconsRegular.caretDown,
                                    size: 16, color: _dark),
                              ),
                              style: GoogleFonts.poppins(
                                  color: _dark,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                              items: const [
                                DropdownMenuItem(
                                    value: 'This Week',
                                    child: Text('This Week')),
                                DropdownMenuItem(
                                    value: 'Last 28 Days',
                                    child: Text('Last 28 Days')),
                                DropdownMenuItem(
                                    value: 'Last 90 Days',
                                    child: Text('Last 90 Days')),
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
                        const SizedBox(width: 20),
                        FilledButton.icon(
                          onPressed: widget.onAddProperty,
                          icon: const Icon(PhosphorIconsRegular.plus, size: 18),
                          label: Text('Add Property',
                              style: GoogleFonts.poppins(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          style: FilledButton.styleFrom(
                            backgroundColor: _dark, // Premium contrast
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 20),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(40)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    _buildTopPropertiesCarousel(),
                    const SizedBox(height: 24),

                    _isLoading
                        ? _buildShimmerStats(compact: false)
                        : _buildKpiGrid(compact: false),
                    const SizedBox(height: 24),

                    _buildRecommendations(),
                    const SizedBox(height: 24),

                    _buildPropertyPerformancePanel(),
                    const SizedBox(height: 24),

                    _buildDesktopEngagementPanel(),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 24),
                      _buildDesktopPanel(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFEF2F2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                  PhosphorIconsRegular.warningCircle,
                                  color: Color(0xFFB42318)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(_errorMessage!,
                                  style: GoogleFonts.poppins(
                                      color: const Color(0xFFB42318),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                            ),
                            FilledButton.tonal(
                                onPressed: _loadData,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFFEF2F2),
                                  foregroundColor: const Color(0xFFB42318),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30)),
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

  // ─── MOBILE SPECIFIC BUILDER ──────────────────────────────────

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
                24, 24, 24, MediaQuery.of(context).padding.bottom + 130),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _grey,
                            ),
                          ),
                          Text(
                            '${AppSession.displayName.split(' ')[0]} 👋',
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: _dark,
                              letterSpacing: -1,
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
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _surface,
                          shape: BoxShape.circle,
                          boxShadow: _premiumShadow,
                          border: Border.all(
                              color: const Color(0xFFF3F4F6), width: 1),
                        ),
                        child: Stack(
                          children: [
                            const Icon(PhosphorIconsRegular.bell,
                                color: _dark, size: 24),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2)),
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
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Column(
                      children: [
                        const Icon(PhosphorIconsRegular.warningCircle,
                            color: Color(0xFFEF4444), size: 48),
                        const SizedBox(height: 12),
                        Text(_errorMessage!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                                color: const Color(0xFF991B1B),
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                              elevation: 0),
                          child: Text('Retry',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: _premiumShadow,
                        border: Border.all(
                            color: const Color(0xFFF3F4F6), width: 1)),
                    child: DropdownButton<String>(
                      value: _selectedAnalyticsPeriod,
                      underline: const SizedBox.shrink(),
                      icon: const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child:
                              Icon(PhosphorIconsRegular.caretDown, size: 16)),
                      style: GoogleFonts.poppins(
                          color: _dark,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                      items: const [
                        DropdownMenuItem(
                            value: 'This Week', child: Text('This Week')),
                        DropdownMenuItem(
                            value: 'Last 28 Days', child: Text('Last 28 Days')),
                        DropdownMenuItem(
                            value: 'Last 90 Days', child: Text('Last 90 Days')),
                      ],
                      onChanged: (period) {
                        if (period == null) return;
                        setState(() => _selectedAnalyticsPeriod = period);
                        _loadData();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ─── STATS GRID ───
                _buildTopPropertiesCarousel(),
                const SizedBox(height: 24),
                _isLoading
                    ? _buildShimmerStats(compact: true)
                    : _buildKpiGrid(compact: true),
                const SizedBox(height: 24),
                _buildRecommendations(),
                const SizedBox(height: 24),
                _buildPropertyPerformancePanel(),
                const SizedBox(height: 24),

                // ─── VIEW ANALYTICS BUTTON ───
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: _openAnalytics,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _surface,
                      foregroundColor: _dark,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: BorderSide(
                            color: const Color(0xFFF3F4F6), width: 1),
                      ),
                    ),
                    child: Text(
                      'View Detailed Analytics',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
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
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(PhosphorIconsRegular.houseLine,
                                size: 48, color: _grey),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No properties listed yet',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _dark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first property to start earning.',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: _grey,
                                fontWeight: FontWeight.w500),
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

                const SizedBox(height: 24),

                // ─── VIEW ALL PROPERTIES BUTTON ───
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: _openAllProperties,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _dark, // High contrast primary CTA
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text(
                      'View All Properties',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: _premiumShadow,
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: buildPropertyImage(
              imageUrl,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorPlaceholder: Container(
                width: 80,
                height: 80,
                color: const Color(0xFFF3F4F6),
                child: const Icon(PhosphorIconsRegular.image, color: _grey),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  city,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _grey,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Ksh. ${price.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                    const Spacer(),
                    if (reviews > 0) ...[
                      const Icon(PhosphorIconsFill.star,
                          size: 16, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerProperties() {
    return Column(
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade200,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 112,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 110,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: 80,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
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
        borderRadius: BorderRadius.circular(32),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
              boxShadow: _premiumShadow,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 180),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                                color: Color(0xFFF3F4F6),
                                shape: BoxShape.circle),
                            child: Icon(icon, size: 20, color: _green)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                              color: Color(0xFFF9FAFB), shape: BoxShape.circle),
                          child: Icon(PhosphorIconsRegular.arrowUpRight,
                              size: 14, color: onTap == null ? _grey : _dark),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (loading)
                      const SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: _green,
                        ),
                      )
                    else
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: value == 'Not enough data' ||
                                  value == 'Unavailable'
                              ? _grey
                              : _dark,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: _dark,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: _grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
