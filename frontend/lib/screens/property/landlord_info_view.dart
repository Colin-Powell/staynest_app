import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/models/property.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/utils/property_mapper.dart';
import 'package:property_app/widgets/property_image.dart';

// ─── Design System Constants ──────────────────────────────────────────────────
const _bg = Color(0xFFFAFAFA);
const _dark = Color(0xFF111827);
const _grey = Color(0xFF9CA3AF);
const _surface = Colors.white;
const _primaryText = Color(0xFF4F70F8); // Blue CTA
const _green = Color(0xFF10B981); // Emerald Green for Verified items

class LandlordInfoView extends StatefulWidget {
  final VoidCallback onClose;
  final Property? property;

  const LandlordInfoView({
    super.key,
    required this.onClose,
    this.property,
  });

  @override
  State<LandlordInfoView> createState() => _LandlordInfoViewState();
}

class _LandlordInfoViewState extends State<LandlordInfoView>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  bool _showProperties = false;
  bool _loading = true;

  Map<String, dynamic>? _landlordProfile;
  List<Property> _landlordProperties = [];

  final List<String> _documents = [
    'ID / Passport',
    'Business Registration',
    'Property Ownership',
    'KRA PIN Certificate',
  ];

  bool _hasAuthIssue = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadLandlordData();
  }

  Future<void> _loadLandlordData() async {
    final landlordId = widget.property?.agent.userId;
    if (landlordId == null || landlordId.isEmpty) {
      setState(() => _loading = false);
      _controller.forward();
      return;
    }

    try {
      final repo = RemoteDatabaseRepository();
      final profile = await repo.loadUserById(landlordId);
      final rawProperties = await repo.loadPropertiesForUser(landlordId);
      if (!mounted) return;
      setState(() {
        _hasAuthIssue = false;
        _landlordProfile = profile;
        _landlordProperties = rawProperties.map(mapApiProperty).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasAuthIssue = true;
          _loading = false;
        });
      }
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleProperties() {
    setState(() => _showProperties = !_showProperties);
    _controller.reset();
    _controller.forward();
  }

  String get _landlordName {
    final profileName = _landlordProfile?['name']?.toString().trim() ?? '';
    if (profileName.isNotEmpty) return profileName;

    final agentName = widget.property?.agent.name.trim() ?? '';
    if (agentName.isNotEmpty && agentName != 'Agent') return agentName;

    final businessName =
        _landlordProfile?['business_name']?.toString().trim() ??
            widget.property?.agent.businessName?.trim() ??
            '';
    if (businessName.isNotEmpty) return businessName;

    return 'Landlord';
  }

  String? get _businessSubtitle {
    final businessName =
        _landlordProfile?['business_name']?.toString().trim() ??
            widget.property?.agent.businessName?.trim();
    if (businessName == null || businessName.isEmpty) return null;
    if (businessName == _landlordName) return null;
    return businessName;
  }

  String get _landlordAvatar {
    final fromProfile = _landlordProfile?['avatar']?.toString() ?? '';
    if (fromProfile.isNotEmpty) return fromProfile;
    return widget.property?.agent.avatar ?? '';
  }

  bool get _isVerified =>
      _landlordProfile?['verified'] == true ||
      widget.property?.agent.verified == true;

  String get _aboutText {
    final fromProfile =
        _landlordProfile?['business_description']?.toString() ?? '';
    if (fromProfile.isNotEmpty) return fromProfile;
    return widget.property?.agent.businessDescription ??
        'This landlord has not added a business description yet.';
  }

  int get _propertyCount {
    final payloadCount = _landlordProfile?['property_count'] ??
        _landlordProfile?['landlord_property_count'] ??
        widget.property?.agent.propertyCount;
    return _toInt(payloadCount, fallback: _landlordProperties.length);
  }

  String get _responseTime {
    final responseSeconds = _landlordProfile?['response_time_seconds'] ??
        _landlordProfile?['landlord_response_time_seconds'] ??
        widget.property?.agent.responseTimeSeconds;
    final seconds = _toDouble(responseSeconds);
    if (seconds == null || seconds < 0) return '—';
    if (seconds < 3600) return '${(seconds / 60).round()}m';
    if (seconds < 86400) return '${(seconds / 3600).round()}h';
    return '${(seconds / 86400).round()}d';
  }

  int _toInt(dynamic value, {required int fallback}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String get _memberSince {
    final created = _landlordProfile?['created_at']?.toString() ??
        widget.property?.agent.memberSince;
    if (created == null || created.isEmpty) return '—';
    final date = DateTime.tryParse(created);
    if (date == null) return '—';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Widget _buildStaggered({required Widget child, required int index}) {
    final double start = (index * 0.08).clamp(0.0, 1.0);
    final double end = (start + 0.4).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _primaryText)),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child:
                  _showProperties ? _buildPropertiesView() : _buildInfoView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoView() {
    return Stack(
      key: const ValueKey('InfoView'),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStaggered(
              index: 0,
              child: _buildHeader('Landlord Info', onBack: widget.onClose),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildStaggered(
                      index: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildLandlordProfile(),
                              const SizedBox(height: 24),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: Divider(
                                    color: _grey.withOpacity(0.2), height: 1),
                              ),
                              const SizedBox(height: 20),
                              _buildStatsRow(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildStaggered(
                      index: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4)),
                            ],
                          ),
                          child: _buildAboutSectionContent(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_isVerified)
                      _buildStaggered(
                        index: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4)),
                              ],
                            ),
                            child: _buildDocumentsSectionContent(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (!_showProperties)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildStaggered(index: 4, child: _buildBottomCta()),
          ),
      ],
    );
  }

  Widget _buildLandlordReviewsSummary() {
    final reviews = widget.property?.reviews ?? 0;
    final rating = widget.property?.rating ?? 0;

    if (reviews <= 0 || rating <= 0) {
      return Text(
        'No reviews yet',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: _grey,
        ),
      );
    }

    return Row(
      children: [
        const Icon(PhosphorIconsFill.star, color: Color(0xFFF59E0B), size: 16),
        const SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: _dark,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '($reviews ${reviews == 1 ? 'Review' : 'Reviews'})',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: _grey,
          ),
        ),
      ],
    );
  }

  Widget _buildLandlordProfile() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 24),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _grey.withOpacity(0.1),
            border: Border.all(
              color: _isVerified ? _green : Colors.transparent,
              width: 2.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: AppSession.buildAvatar(_landlordAvatar, width: 72, height: 72),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _landlordName,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(PhosphorIconsFill.sealCheck,
                        color: _green, size: 20),
                  ]
                ],
              ),
              if (_businessSubtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  _businessSubtitle!,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 6),
              _buildLandlordReviewsSummary(),
            ],
          ),
        ),
        const SizedBox(width: 24),
      ],
    );
  }

  Widget _buildBottomCta() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(context).padding.bottom + 20),
          decoration: BoxDecoration(
            color: _surface.withOpacity(0.85),
            border: Border(top: BorderSide(color: _grey.withOpacity(0.1))),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (_landlordProperties.isEmpty || _hasAuthIssue)
                  ? null
                  : _toggleProperties,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryText,
                disabledBackgroundColor: _grey.withOpacity(0.2),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32)),
              ),
              child: Text(
                'View all Properties',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPropertiesView() {
    return Column(
      key: const ValueKey('PropertiesView'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStaggered(
          index: 0,
          child: _buildHeader('Properties', onBack: _toggleProperties),
        ),
        Expanded(
          child: _landlordProperties.isEmpty
              ? Center(
                  child: Text(
                    'No properties listed yet.',
                    style: GoogleFonts.poppins(color: _grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: 16,
                    left: 24,
                    right: 24,
                    bottom: MediaQuery.of(context).padding.bottom + 24,
                  ),
                  itemCount: _landlordProperties.length,
                  itemBuilder: (context, index) {
                    final prop = _landlordProperties[index];
                    return _buildStaggered(
                      index: index + 1,
                      child: _buildPropertyCard(prop),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPropertyCard(Property prop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 120, // Tighter card height
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: buildPropertyImage(
              prop.image,
              width: 120,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prop.name,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(PhosphorIconsRegular.mapPin,
                          size: 14, color: _grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          prop.location,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: _grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            'Ksh. ${prop.price}',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _dark,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            ' /mo',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _grey,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(PhosphorIconsFill.star,
                              size: 12, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                            prop.rating.toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _dark,
                            ),
                          ),
                        ],
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

  Widget _buildHeader(String title, {required VoidCallback onBack}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: const Icon(PhosphorIconsRegular.caretLeft,
                size: 24, color: _dark),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _dark,
                letterSpacing: -0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(label: 'Response', value: _responseTime),
          Container(width: 1, height: 32, color: _grey.withOpacity(0.2)),
          _StatItem(label: 'Properties', value: '$_propertyCount'),
          Container(width: 1, height: 32, color: _grey.withOpacity(0.2)),
          _StatItem(label: 'Joined', value: _memberSince),
        ],
      ),
    );
  }

  Widget _buildAboutSectionContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About',
          style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w700, color: _dark),
        ),
        const SizedBox(height: 12),
        Text(
          _aboutText,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: _grey,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsSectionContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verified Documents',
          style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w700, color: _dark),
        ),
        const SizedBox(height: 16),
        ...List.generate(_documents.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                const Icon(PhosphorIconsFill.checkCircle,
                    color: _green, size: 22),
                const SizedBox(width: 12),
                Text(
                  _documents[i],
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: _dark,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: _dark,
          ),
        ),
      ],
    );
  }
}
