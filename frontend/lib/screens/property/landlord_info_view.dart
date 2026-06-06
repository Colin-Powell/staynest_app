import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/models/property.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/screens/theme.dart';
import 'package:property_app/utils/property_mapper.dart';
import 'package:property_app/widgets/property_image.dart';

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
        _landlordProfile = profile;
        _landlordProperties =
            rawProperties.map(mapApiProperty).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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

  int get _propertyCount =>
      _landlordProfile?['property_count'] as int? ??
      _landlordProperties.length;

  String get _memberSince {
    final created = _landlordProfile?['created_at']?.toString() ??
        widget.property?.agent.memberSince;
    if (created == null || created.isEmpty) return '—';
    final date = DateTime.tryParse(created);
    if (date == null) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
      return Scaffold(
        backgroundColor: StayNestColors.surfaceVariantLight,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: StayNestColors.surfaceVariantLight,
      body: AnimatedSwitcher(
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
        child: _showProperties ? _buildPropertiesView() : _buildInfoView(),
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
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildStaggered(index: 1, child: _buildLandlordProfile()),
                    const SizedBox(height: 24),
                    _buildStaggered(index: 2, child: _buildDivider()),
                    const SizedBox(height: 20),
                    _buildStaggered(index: 3, child: _buildStatsRow()),
                    const SizedBox(height: 20),
                    _buildStaggered(index: 4, child: _buildDivider()),
                    const SizedBox(height: 32),
                    _buildStaggered(index: 5, child: _buildAboutSection()),
                    const SizedBox(height: 32),
                    if (_isVerified)
                      _buildStaggered(
                          index: 6, child: _buildDocumentsSection()),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildStaggered(index: 7, child: _buildBottomCta()),
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
          fontSize: 15,
          color: StayNestColors.textSecondaryLight,
        ),
      );
    }

    return Row(
      children: [
        Icon(PhosphorIcons.star(PhosphorIconsStyle.fill),
            color: StayNestColors.accent, size: 22),
        const SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w900,
            fontSize: 17,
            color: StayNestColors.textPrimaryLight,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '($reviews ${reviews == 1 ? 'Review' : 'Reviews'})',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 15,
            color: StayNestColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildLandlordProfile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE5E7EB),
              border: Border.all(
                color: _isVerified
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFE5E7EB),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _landlordAvatar.isNotEmpty
                ? buildPropertyImage(_landlordAvatar,
                    width: 80, height: 80, fit: BoxFit.cover)
                : const Icon(Icons.person, size: 40, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _landlordName,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: StayNestColors.textPrimaryLight,
                    letterSpacing: -0.3,
                  ),
                ),
                if (_businessSubtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _businessSubtitle!,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: StayNestColors.textSecondaryLight,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  _isVerified ? 'Verified Landlord' : 'Landlord',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _isVerified
                        ? StayNestColors.success
                        : StayNestColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                _buildLandlordReviewsSummary(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCta() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            StayNestColors.surfaceVariantLight.withValues(alpha: 0.0),
            StayNestColors.surfaceVariantLight.withValues(alpha: 0.9),
            StayNestColors.surfaceVariantLight,
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
      ),
      child: ElevatedButton(
        onPressed: _landlordProperties.isEmpty ? null : _toggleProperties,
        style: ElevatedButton.styleFrom(
          backgroundColor: StayNestColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          'View all Properties',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w800,
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
              ? const Center(
                  child: Text(
                    'No properties listed yet.',
                    style: TextStyle(color: Color(0xFF6B7280)),
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
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: buildPropertyImage(
              prop.image,
              width: 140,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prop.name,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: StayNestColors.textPrimaryLight,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                        size: 14,
                        color: StayNestColors.textMutedLight,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          prop.location,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: StayNestColors.textSecondaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'Kes. ${prop.price ~/ 1000}k',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: StayNestColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        '/month',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: StayNestColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              PhosphorIcons.star(PhosphorIconsStyle.fill),
                              size: 14,
                              color: StayNestColors.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              prop.rating.toStringAsFixed(1),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: StayNestColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${prop.features.beds} Beds',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: StayNestColors.textSecondaryLight,
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

  Widget _buildHeader(String title, {required VoidCallback onBack}) {
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 24,
        right: 24,
        bottom: 16,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: const Icon(Icons.arrow_back, size: 28, color: Colors.black),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Divider(
        color: Color(0xFFE5E7EB),
        thickness: 1.5,
        height: 1,
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const _StatItem(label: 'Response Rate', value: '—'),
          _StatItem(label: 'Properties', value: '$_propertyCount'),
          _StatItem(label: 'Member Since', value: _memberSince),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _aboutText,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4B5563),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verified Documents',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(_documents.length, (i) {
            return _buildStaggered(
              index: 7 + i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      color: Color(0xFF22C55E),
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      _documents[i],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
