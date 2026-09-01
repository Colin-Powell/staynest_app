import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/models/property.dart';
import 'package:property_app/models/property_taxonomy.dart';
import 'package:property_app/theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/repository/remote_database_repository.dart';

class PropertyCard extends StatefulWidget {
  final Property property;
  final VoidCallback onTap;
  final bool isHorizontal;
  final double width;
  final bool isGrid;

  const PropertyCard({
    super.key,
    required this.property,
    required this.onTap,
    this.isHorizontal = true,
    this.width = 300,
    this.isGrid = false,
  });

  @override
  State<PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<PropertyCard> {
  bool get _isSaved => AppSession.isSaved(widget.property.id);

  Future<void> _toggleSave() async {
    final wasSaved = _isSaved;

    // Optimistic UI
    setState(() {
      AppSession.toggleSaved(widget.property.id);
    });

    // Backend sync
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
      } catch (_) {
        // Revert on failure
        if (!mounted) return;
        setState(() {
          AppSession.toggleSaved(widget.property.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final property = widget.property;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.isHorizontal ? widget.width : double.infinity,
        margin: EdgeInsets.only(right: widget.isHorizontal ? 20 : 0, bottom: widget.isGrid ? 0 : (widget.isHorizontal ? 0 : 24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Box
            if (widget.isGrid)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AppColors.gray100,
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: widget.property.image.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: widget.property.image,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.broken_image, color: AppColors.gray400),
                                )
                              : const Icon(Icons.image, color: AppColors.gray400),
                        ),
                      ),
                      // Badges
                      Positioned(
                        top: 16,
                        left: 16,
                        child: _buildBadge(),
                      ),
                      // Heart (wired to save/unsave)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: _toggleSave,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.25),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                                child: Icon(
                                  _isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  key: ValueKey(_isSaved),
                                  color: _isSaved ? const Color(0xFFEF4444) : Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
            Container(
              height: widget.isHorizontal ? widget.width * 0.9 : 320,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AppColors.gray100,
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: property.image.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: property.image,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.broken_image, color: AppColors.gray400),
                            )
                          : const Icon(Icons.image, color: AppColors.gray400),
                    ),
                  ),
                  // Badges
                  Positioned(
                    top: 16,
                    left: 16,
                    child: _buildBadge(),
                  ),
                  // Heart (wired to save/unsave)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: _toggleSave,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                            child: Icon(
                              _isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              key: ValueKey(_isSaved),
                              color: _isSaved ? const Color(0xFFEF4444) : Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    property.location,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 18, color: AppColors.gray900),
                    const SizedBox(width: 4),
                    Text(
                      property.rating > 0 ? property.rating.toStringAsFixed(1) : "New",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gray900,
                      ),
                    ),
                    if (property.reviews > 0) ...[
                      Text(
                        ' (${property.reviews})',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.gray500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              property.name,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.gray500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            _buildHighlights(property.amenities),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "Ksh. ${property.price.toInt()}",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray900,
                    ),
                  ),
                  TextSpan(
                    text: " / month",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.gray500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
        fontSize: 13,
        color: AppColors.gray600,
        fontWeight: FontWeight.w400,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildBadge() {
    String text = "";
    if (widget.property.rating >= 4.8) {
      text = "Guest Favourite";
    } else if (widget.property.rating == 0) {
      text = "New";
    }

    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.gray900,
        ),
      ),
    );
  }
}
