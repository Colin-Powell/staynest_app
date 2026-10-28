import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/models/property.dart';
import 'package:property_app/models/property_taxonomy.dart';
import 'package:property_app/theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/services/analytics/analytics_service.dart';
import 'package:property_app/services/properties_api.dart';
import 'package:property_app/utils/property_links.dart';
import 'package:visibility_detector/visibility_detector.dart';

class PropertyCard extends StatefulWidget {
  final Property property;
  final VoidCallback onTap;
  final bool isHorizontal;
  final double width;
  final bool isGrid;
  final bool showHighlights;
  final bool titleFirst;
  final double imageAspectRatio;
  final String? badgeLabel;
  final ValueChanged<bool>? onFavoriteChanged;
  final Future<void> Function({VoidCallback? onAuthenticated})?
      onRequireAuthentication;
  final Widget? imageAction;
  final Widget? detailsAction;

  const PropertyCard({
    super.key,
    required this.property,
    required this.onTap,
    this.isHorizontal = true,
    this.width = 300,
    this.isGrid = false,
    this.showHighlights = true,
    this.titleFirst = false,
    this.imageAspectRatio = 1,
    this.badgeLabel,
    this.onFavoriteChanged,
    this.onRequireAuthentication,
    this.imageAction,
    this.detailsAction,
  });

  @override
  State<PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<PropertyCard> {
  String? _impressedPropertyId;

  bool get _isSaved => AppSession.isSaved(widget.property.id);

  void _recordImpression(double visibleFraction) {
    final property = widget.property;
    if (visibleFraction <= 0.5 ||
        _impressedPropertyId == property.id ||
        AppSession.isGuest ||
        AppSession.isLandlord ||
        property.moderationStatus != 'approved') {
      return;
    }
    _impressedPropertyId = property.id;
    unawaited(PropertiesApi.recordPropertyImpression(property.id));
    unawaited(
      AnalyticsService.logListingInteraction(
        AnalyticsEvents.listingImpression,
        listingId: property.id,
      ),
    );
  }

  Future<void> _toggleSave() async {
    if (AppSession.isGuest) {
      final requireAuthentication = widget.onRequireAuthentication;
      if (requireAuthentication != null) {
        await requireAuthentication(onAuthenticated: _toggleSave);
        return;
      }
      await _showLoginPrompt();
      return;
    }
    final wasSaved = _isSaved;

    // Optimistic UI
    setState(() {
      AppSession.toggleSaved(widget.property.id);
    });

    // Backend sync
    var synced = false;
    if (AppSession.currentUserId != null && AppSession.apiToken != null) {
      try {
        final repo = RemoteDatabaseRepository();
        if (wasSaved) {
          await repo.removeFavoriteForUser(
            userId: AppSession.currentUserId!,
            propertyId: widget.property.id,
          );
        } else {
          await repo.savePropertyForUser(
            userId: AppSession.currentUserId!,
            propertyId: widget.property.id,
          );
        }
        synced = true;
      } catch (_) {
        // Revert on failure
        if (!mounted) return;
        setState(() {
          AppSession.toggleSaved(widget.property.id);
        });
      }
    }
    if (mounted && synced) widget.onFavoriteChanged?.call(!wasSaved);
  }

  Future<void> _shareProperty() async {
    final property = widget.property;
    try {
      final shared = await PropertyLinks.showShareOptions(
        context,
        propertyId: property.id,
        propertyName: property.name,
        imagePath: property.image,
        shareText: '${property.name} on StayNest',
      );
      if (shared) await AnalyticsService.trackPropertyShare(property.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share this property.')),
        );
      }
    }
  }

  Future<void> _showLoginPrompt() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Login required'),
        content: const Text('Log in to save properties to your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              AppSession.isGuest = false;
              Navigator.pop(dialogContext);
              Navigator.pushReplacementNamed(context, '/login');
            },
            icon: const Icon(Icons.login),
            label: const Text('Log in'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey('property_card_${widget.property.id}'),
      onVisibilityChanged: (info) => _recordImpression(info.visibleFraction),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          // Dynamic sizing: fixed width for horizontal lists, fills parent width for grids/vertical lists
          width: widget.isHorizontal ? widget.width : null,
          margin: EdgeInsets.only(
            right: widget.isHorizontal ? 20 : 0,
            bottom: widget.isGrid ? 0 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize
                .min, // Ensures card tightens dynamically to fit text
            children: [
              if (widget.isGrid)
                AspectRatio(
                  aspectRatio: widget.imageAspectRatio,
                  child: _buildImageContainer(),
                )
              else if (widget.isHorizontal)
                Expanded(child: _buildImageContainer())
              else
                AspectRatio(
                  aspectRatio: widget.imageAspectRatio,
                  child: _buildImageContainer(),
                ),

              const SizedBox(height: 12),

              // Text Details Layout
              _buildDetails(),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the consolidated Image Stack with Fav button and Badges
  Widget _buildImageContainer() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16), // Airbnb standard soft corners
        color: AppColors.gray100,
      ),
      child: Stack(
        children: [
          // Image
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: widget.property.image.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.property.image,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => const Icon(
                          Icons.broken_image,
                          color: AppColors.gray400),
                    )
                  : const Icon(Icons.image, color: AppColors.gray400),
            ),
          ),

          // Badge
          Positioned(
            top: 12,
            left: 12,
            child: _buildBadge(),
          ),

          // Favorite or screen-specific image action
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.detailsAction != null) ...[
                  widget.detailsAction!,
                  const SizedBox(width: 8),
                ],
                _buildShareButton(),
                const SizedBox(width: 8),
                widget.imageAction ?? _buildFavoriteButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    final property = widget.property;
    final location = widget.titleFirst
        ? property.location
            .split(',')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .take(3)
            .join(', ')
        : property.location;
    final title = Text(
      property.name,
      style: GoogleFonts.poppins(
        fontSize: widget.titleFirst ? 15 : 14,
        fontWeight: widget.titleFirst ? FontWeight.w600 : FontWeight.normal,
        color: widget.titleFirst ? AppColors.gray900 : AppColors.gray500,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.titleFirst) title,
        if (widget.titleFirst) const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                location,
                style: GoogleFonts.poppins(
                  fontSize: widget.titleFirst ? 12 : 15,
                  fontWeight:
                      widget.titleFirst ? FontWeight.normal : FontWeight.w600,
                  color: AppColors.gray900,
                ),
                maxLines: widget.titleFirst ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (property.rating > 0 && property.reviews > 0)
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      size: 16, color: AppColors.gray900),
                  const SizedBox(width: 4),
                  Text(
                    '${property.rating.toStringAsFixed(1)} (${property.reviews})',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.gray900,
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (!widget.titleFirst) const SizedBox(height: 2),
        if (!widget.titleFirst) title,
        const SizedBox(height: 2),
        if (widget.showHighlights) ...[
          _buildHighlights(property.amenities),
          const SizedBox(height: 6),
        ],
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "Ksh. ${property.price.toInt()}",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight:
                      widget.titleFirst ? FontWeight.w800 : FontWeight.w600,
                  color: AppColors.gray900,
                ),
              ),
              TextSpan(
                text: " / month",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.gray900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteButton() {
    return GestureDetector(
      onTap: _toggleSave,
      behavior:
          HitTestBehavior.opaque, // Ensures the whole circle is tappable easily
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
            color: Colors.white
                .withOpacity(0.85), // Airbnb uses solid/blur light circles
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ]),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              _isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey(_isSaved),
              color: _isSaved ? const Color(0xFFEF4444) : Colors.black87,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShareButton() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        tooltip: 'Share property',
        onPressed: _shareProperty,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        icon: const Icon(Icons.ios_share_rounded, size: 16),
      ),
    );
  }

  Widget _buildHighlights(List<String> amenities) {
    if (amenities.isEmpty) return const SizedBox.shrink();

    // Convert to attributes
    final attrs = amenities
        .map((id) => PropertyTaxonomy.getAttributeById(id))
        .where((a) => a != null)
        .cast<PropertyAttribute>()
        .toList();

    // Sort so that popular items are first
    attrs.sort((a, b) {
      if (a.isPopular && !b.isPopular) return -1;
      if (!a.isPopular && b.isPopular) return 1;
      return 0;
    });

    final display = attrs.take(3).map((a) => a.label).join(' • ');
    if (display.isEmpty) return const SizedBox.shrink();

    return Text(
      display,
      style: GoogleFonts.poppins(
        fontSize: 14, // Slightly scaled up for readability
        color: AppColors.gray500,
        fontWeight: FontWeight.w400,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildBadge() {
    final availabilityStatus = widget.property.availabilityStatus.toLowerCase();
    final isUnavailable = const {
      'fully_booked',
      'unavailable',
      'rented',
      'maintenance',
    }.contains(availabilityStatus);
    final text =
        availabilityStatus == 'unknown' || availabilityStatus == 'available'
            ? widget.badgeLabel ?? ''
            : widget.property.availabilityLabel;

    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isUnavailable ? const Color(0xFFFFE4E6) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isUnavailable ? const Color(0xFF9F1239) : AppColors.gray900,
        ),
      ),
    );
  }
}
