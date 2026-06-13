import 'package:flutter/material.dart';

import 'package:property_app/models/property.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/services/property_service.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/widgets/property_image.dart';

class SavedView extends StatefulWidget {
  final VoidCallback? onOpenProperty;
  final ValueChanged<String>? onSelectProperty;

  const SavedView({super.key, this.onOpenProperty, this.onSelectProperty});

  @override
  State<SavedView> createState() => _SavedViewState();
}

class _SavedViewState extends State<SavedView>
    with SingleTickerProviderStateMixin {
  final _propertyService = PropertyService.instance;
  List<Property> _all = [];
  bool _loading = true;

  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _load();
  }

  Future<void> _toggleSave(String propertyId) async {
    final isCurrentlySaved = AppSession.isSaved(propertyId);
    if (AppSession.currentUserId != null && AppSession.apiToken != null) {
      try {
        final repository = RemoteDatabaseRepository();
        if (isCurrentlySaved) {
          await repository.removeFavoriteForUser(
            userId: AppSession.currentUserId!,
            propertyId: propertyId,
          );
          AppSession.savedPropertyIds.remove(propertyId);
        } else {
          await repository.savePropertyForUser(
            userId: AppSession.currentUserId!,
            propertyId: propertyId,
          );
          AppSession.savedPropertyIds.add(propertyId);
        }
        return;
      } catch (_) {
        // Nothing to do; fall back to local state.
      }
    }
    AppSession.toggleSaved(propertyId);
  }

  Future<void> _load() async {
    final loaded = await _propertyService.fetchProperties();
    if (!mounted) return;
    setState(() {
      _all = loaded;
      _loading = false;
    });
    // Start the cascade animation once data is loaded
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Helper to create a smooth staggered fade and upward slide for list items
  Widget _buildStaggered({required Widget child, required int index}) {
    final double start = (index * 0.08).clamp(0.0, 1.0);
    final double end = (start + 0.4).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _animController,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              left: 24,
              right: 24,
              bottom: 24,
            ),
            child: const Text(
              'Saved Properties',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // List Content
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF3F37C9),
                    ),
                  )
                : Builder(builder: (context) {
                    final savedProperties =
                        _all.where((p) => AppSession.isSaved(p.id)).toList();
                    if (savedProperties.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'No saved properties yet. Tap the heart icon on a listing to save it.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(
                        left: 24,
                        right: 24,
                        bottom: 112,
                      ),
                      itemCount: savedProperties.length,
                      itemBuilder: (context, index) {
                        final property = savedProperties[index];
                        return _buildStaggered(
                          index: index,
                          child: GestureDetector(
                            onTap: () => (widget.onOpenProperty != null
                                ? widget.onOpenProperty!()
                                : widget.onSelectProperty?.call(property.id)),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              height: 140,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                children: [
                                  // Left Image
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: buildPropertyImage(
                                      property.image,
                                      width: 140,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Right Content
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          0, 16, 16, 16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Title & Heart
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  property.name,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.black,
                                                    height: 1.1,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () {
                                                  _toggleSave(property.id).then(
                                                      (_) => setState(() {}));
                                                },
                                                child: const Icon(
                                                  Icons.favorite,
                                                  color: Color(
                                                      0xFFEC4899), // Pink filled heart
                                                  size: 20,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),

                                          // Location
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.location_on,
                                                size: 14,
                                                color: Color(0xFF9CA3AF),
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  property.location,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF9CA3AF),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),

                                          const Spacer(),

                                          // Price
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.baseline,
                                            textBaseline:
                                                TextBaseline.alphabetic,
                                            children: [
                                              Text(
                                                'Kes. ${property.price ~/ 1000}k',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              const Text(
                                                '/month',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF9CA3AF),
                                                ),
                                              ),
                                            ],
                                          ),

                                          const Spacer(),

                                          // Rating & Beds
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              // Rating Pill
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFF3F4F6),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.star_rounded,
                                                      size: 14,
                                                      color: Color(0xFFF59E0B),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${property.rating.toStringAsFixed(1)} (${property.reviews})',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Beds
                                              Text(
                                                '${property.features.beds} Beds',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF9CA3AF),
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
                            ),
                          ),
                        );
                      },
                    );
                  }),
          ),
        ],
      ),
    );
  }
}
