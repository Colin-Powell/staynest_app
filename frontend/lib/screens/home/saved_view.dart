import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/session/onboarding_prefs.dart';
import 'package:property_app/widgets/onboarding_bottom_sheet.dart';

import 'package:property_app/models/property.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/services/properties_api.dart';
import 'package:property_app/utils/property_mapper.dart';
import 'package:property_app/services/property_service.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/widgets/property_card.dart';

// --- Airbnb-Style Colors ---
const Color _textDark = Color(0xFF222222);
const Color _textLight = Color(0xFF717171);
const Color _dividerColor = Color(0xFFEBEBEB);
const Color _primary = Color(0xFF3F37C9);

// Responsive constant matching desktop standard widths
const double _maxWebWidth = 1280.0;

// ─────────────────────────────────────────────────────────────────────────────
// WISH LIST HUB (Main Page)
// ─────────────────────────────────────────────────────────────────────────────

class SavedView extends StatefulWidget {
  final VoidCallback? onOpenProperty;
  final void Function(Property)? onSelectProperty;

  const SavedView({
    super.key,
    this.onOpenProperty,
    this.onSelectProperty,
  });

  @override
  State<SavedView> createState() => _SavedViewState();
}

class _SavedViewState extends State<SavedView>
    with SingleTickerProviderStateMixin {
  final _propertyService = PropertyService.instance;
  List<Property> _all = [];
  List<Property> _recent = [];
  bool _loading = true;
  bool _hasError = false;

  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!OnboardingPrefs.hasSeen('savedSeen')) {
        OnboardingBottomSheet.show(
          context: context,
          title: 'Keep your favourites close',
          imagePath: 'assets/images/saved_onboarding.png',
          subtitle: 'Your favourite stays, all in one place.',
          ctaText: 'Start saving',
        ).then((_) => OnboardingPrefs.markAsSeen('savedSeen'));
      }
    });

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _hasError = false;
      _loading = true;
    });
    try {
      final loaded = await _propertyService.fetchProperties();
      List<Property> recentProps = [];
      if (AppSession.currentUserId != null) {
        try {
          final recentData = await PropertiesApi.getRecentlyViewed();
          recentProps = recentData.map((e) => mapApiProperty(e)).toList();
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _all = loaded;
        _recent = recentProps;
        _loading = false;
      });
      _animController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _openWishlistDetail(String title, List<Property> properties) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _WishlistDetailScreen(
          title: title,
          properties: properties,
          onOpenProperty: widget.onOpenProperty,
          onSelectProperty: widget.onSelectProperty,
          onListUpdated: () => setState(() {}),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedProperties =
        _all.where((p) => AppSession.isSaved(p.id)).toList();
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 768;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          // Applies the max width wrapper for web and desktop
          constraints: const BoxConstraints(maxWidth: _maxWebWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header ---
              Padding(
                padding: EdgeInsets.only(
                  top: isDesktop ? 64 : MediaQuery.of(context).padding.top + 24,
                  left: isDesktop ? 40 : 24,
                  right: isDesktop ? 40 : 24,
                  bottom: 16,
                ),
                child: Text(
                  'Wishlists',
                  style: GoogleFonts.poppins(
                    fontSize: isDesktop ? 38 : 32,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              // --- Content Area (Dynamic Grid) ---
              Expanded(
                child: _loading
                    ? _SkeletonCollageLoader(isDesktop: isDesktop)
                    : _hasError
                        ? _buildErrorState()
                        : FadeTransition(
                            opacity: _animController,
                            child: GridView(
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 40 : 24,
                                vertical: isDesktop ? 24 : 8,
                              ),
                              physics: const BouncingScrollPhysics(),
                              // Responsive dynamically shifting grid
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:
                                    isDesktop ? (width > 1024 ? 3 : 2) : 1,
                                crossAxisSpacing: 24,
                                mainAxisSpacing: 32,
                                // Maintain image proportions smoothly across all sizes
                                childAspectRatio: isDesktop
                                    ? 0.95
                                    : (width - 48) / ((width - 48) / 1.33 + 70),
                              ),
                              children: [
                                _CollageCard(
                                  title: 'Saved',
                                  properties: savedProperties,
                                  onTap: () => _openWishlistDetail(
                                      'Saved', savedProperties),
                                ),
                                _CollageCard(
                                  title: 'Recently Viewed',
                                  properties: _recent,
                                  onTap: () => _openWishlistDetail(
                                      'Recently Viewed', _recent),
                                ),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: _dividerColor),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: GoogleFonts.poppins(
              color: _textDark,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We couldn\'t load your wishlists.',
            style: GoogleFonts.poppins(color: _textLight),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _load,
            style: OutlinedButton.styleFrom(
              foregroundColor: _textDark,
              side: const BorderSide(color: _textDark, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Try Again',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          )
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COLLAGE CARD (4-image dynamic grid)
// ─────────────────────────────────────────────────────────────────────────────

class _CollageCard extends StatelessWidget {
  final String title;
  final List<Property> properties;
  final VoidCallback onTap;

  const _CollageCard({
    required this.title,
    required this.properties,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Adding MouseRegion to show Web Pointer cursor
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The Image Collage Square (Set to 1.33 for a pleasant wide rectangle)
            AspectRatio(
              aspectRatio: 1.33,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _dividerColor, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: _buildCollageImages(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Subtitle (Count)
            Text(
              '${properties.length} ${properties.length == 1 ? 'property' : 'properties'}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: _textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollageImages() {
    final images =
        properties.map((p) => p.image).where((i) => i.isNotEmpty).toList();

    if (images.isEmpty) {
      return Container(
        color: const Color(0xFFF3F4F6),
        child: const Center(
          child:
              Icon(Icons.maps_home_work_outlined, color: _textLight, size: 36),
        ),
      );
    }

    if (images.length == 1) return _buildImg(images[0]);

    if (images.length == 2) {
      return Row(
        children: [
          Expanded(child: _buildImg(images[0])),
          const SizedBox(width: 2), // Internal divider
          Expanded(child: _buildImg(images[1])),
        ],
      );
    }

    if (images.length == 3) {
      return Row(
        children: [
          Expanded(child: _buildImg(images[0])),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildImg(images[1])),
                const SizedBox(height: 2),
                Expanded(child: _buildImg(images[2])),
              ],
            ),
          ),
        ],
      );
    }

    // 4 or more images -> 2x2 grid
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildImg(images[0])),
              const SizedBox(width: 2),
              Expanded(child: _buildImg(images[1])),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildImg(images[2])),
              const SizedBox(width: 2),
              Expanded(child: _buildImg(images[3])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImg(String url) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: buildPropertyImage(url, fit: BoxFit.cover),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WISHLIST DETAIL SCREEN (Dynamic Desktop/Mobile Grid)
// ─────────────────────────────────────────────────────────────────────────────

class _WishlistDetailScreen extends StatefulWidget {
  final String title;
  final List<Property> properties;
  final VoidCallback? onOpenProperty;
  final void Function(Property)? onSelectProperty;
  final VoidCallback onListUpdated;

  const _WishlistDetailScreen({
    required this.title,
    required this.properties,
    this.onOpenProperty,
    this.onSelectProperty,
    required this.onListUpdated,
  });

  @override
  State<_WishlistDetailScreen> createState() => _WishlistDetailScreenState();
}

class _WishlistDetailScreenState extends State<_WishlistDetailScreen> {
  late List<Property> _localProperties;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _localProperties = List.from(widget.properties);
  }

  Future<void> _removeItem(Property property) async {
    setState(() {
      _localProperties.removeWhere((p) => p.id == property.id);
    });

    widget.onListUpdated();

    if (widget.title == 'Saved' &&
        AppSession.currentUserId != null &&
        AppSession.apiToken != null) {
      AppSession.savedPropertyIds.remove(property.id);
      try {
        await RemoteDatabaseRepository().removeFavoriteForUser(
          userId: AppSession.currentUserId!,
          propertyId: property.id,
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 768;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWebWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header ---
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 40 : 24,
                    isDesktop ? 48 : 16,
                    isDesktop ? 40 : 24,
                    8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: _dividerColor, width: 1.2),
                                ),
                                child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 18,
                                    color: _textDark),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            widget.title,
                            style: GoogleFonts.poppins(
                              fontSize: isDesktop ? 32 : 24,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
                          ),
                        ],
                      ),
                      if (_localProperties.isNotEmpty)
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: TextButton(
                            onPressed: () =>
                                setState(() => _isEditing = !_isEditing),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              foregroundColor: _textDark,
                            ),
                            child: Text(
                              _isEditing ? 'Done' : 'Edit',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // --- Grid Content ---
              Expanded(
                child: _localProperties.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          isDesktop ? 40 : 24,
                          isDesktop ? 24 : 16,
                          isDesktop ? 40 : 24,
                          40,
                        ),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent:
                              isDesktop ? 340 : 200, // Forces dynamic scaling
                          crossAxisSpacing: isDesktop ? 24 : 16,
                          mainAxisSpacing: isDesktop ? 32 : 24,
                          childAspectRatio: isDesktop ? 0.65 : 0.58,
                        ),
                        itemCount: _localProperties.length,
                        itemBuilder: (context, index) {
                          final property = _localProperties[index];
                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: PropertyCard(
                              property: property,
                              isHorizontal: false,
                              isGrid: true,
                              onTap: () {
                                if (_isEditing) return;
                                if (widget.onSelectProperty != null) {
                                  Navigator.of(context).pop();
                                  widget.onSelectProperty!(property);
                                } else {
                                  widget.onOpenProperty?.call();
                                }
                              },
                              imageAction: _isEditing
                                  ? MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () => _removeItem(property),
                                        behavior: HitTestBehavior.opaque,
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.9),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.1),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                            color: _textDark,
                                          ),
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/save.webp',
              height: 140,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.favorite_border,
                  size: 64, color: _dividerColor),
            ),
            const SizedBox(height: 24),
            Text(
              'Nothing here yet',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Properties you add will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: _textLight,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON LOADER (Dynamic Support)
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonCollageLoader extends StatelessWidget {
  final bool isDesktop;

  const _SkeletonCollageLoader({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return GridView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 40 : 24,
        vertical: 8,
      ),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 2 : 1,
        crossAxisSpacing: 24,
        mainAxisSpacing: 32,
        childAspectRatio: isDesktop
            ? 0.95
            : (MediaQuery.of(context).size.width - 48) /
                ((MediaQuery.of(context).size.width - 48) / 1.33 + 70),
      ),
      children: const [
        _SkeletonCard(),
        _SkeletonCard(),
      ],
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();
  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const skeletonColor = Color(0xFFF3F4F6);
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_controller),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.33,
            child: Container(
              decoration: BoxDecoration(
                color: skeletonColor,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
              height: 16,
              width: 140,
              decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 8),
          Container(
              height: 14,
              width: 80,
              decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(4))),
        ],
      ),
    );
  }
}
