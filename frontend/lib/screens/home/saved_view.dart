import 'package:flutter/material.dart';
import 'package:property_app/session/onboarding_prefs.dart';
import 'package:property_app/widgets/onboarding_bottom_sheet.dart';

import 'package:property_app/models/property.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/services/properties_api.dart';
import 'package:property_app/utils/property_mapper.dart';
import 'package:property_app/services/property_service.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/widgets/property_image.dart';

class SavedView extends StatefulWidget {
  final VoidCallback? onOpenProperty;
  final void Function(Property)? onSelectProperty;
  final int initialTab;

  const SavedView({super.key, this.onOpenProperty, this.onSelectProperty, this.initialTab = 0});

  @override
  State<SavedView> createState() => _SavedViewState();
}

class _SavedViewState extends State<SavedView>
    with SingleTickerProviderStateMixin {
  final _propertyService = PropertyService.instance;
  List<Property> _all = [];
  List<Property> _recent = [];
  late int _tab;
  bool _loading = true;

  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;

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
      duration: const Duration(milliseconds: 800),
    );
    _load();
  }

  @override
  void didUpdateWidget(SavedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      setState(() {
        _tab = widget.initialTab;
        _animController.forward(from: 0);
      });
    }
  }

  Future<void> _toggleSave(String propertyId) async {
    final isCurrentlySaved = AppSession.isSaved(propertyId);

    // Optimistic UI update
    setState(() {
      if (isCurrentlySaved) {
        AppSession.savedPropertyIds.remove(propertyId);
      } else {
        AppSession.savedPropertyIds.add(propertyId);
      }
    });

    if (AppSession.currentUserId != null && AppSession.apiToken != null) {
      try {
        final repository = RemoteDatabaseRepository();
        if (isCurrentlySaved) {
          await repository.removeFavoriteForUser(
            userId: AppSession.currentUserId!,
            propertyId: propertyId,
          );
        } else {
          await repository.savePropertyForUser(
            userId: AppSession.currentUserId!,
            propertyId: propertyId,
          );
        }
      } catch (_) {
        // Revert on failure
        if (!mounted) return;
        setState(() {
          if (isCurrentlySaved) {
            AppSession.savedPropertyIds.add(propertyId);
          } else {
            AppSession.savedPropertyIds.remove(propertyId);
          }
        });
      }
    }
  }

  bool _hasError = false;

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


          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() { _tab = 0; _animController.forward(from: 0); }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _tab == 0 ? Colors.black : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text('Saved', style: TextStyle(color: _tab == 0 ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() { _tab = 1; _animController.forward(from: 0); }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _tab == 1 ? Colors.black : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text('Recently Viewed', style: TextStyle(color: _tab == 1 ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // List Content
          Expanded(
            child: _loading
                ? const _SkeletonListLoader()
                : _hasError
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            const Text(
                              'Failed to load properties',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Retry',
                                  style: TextStyle(color: Color(0xFF3F37C9))),
                            )
                          ],
                        ),
                      )

                    : Builder(builder: (context) {
                        final savedProperties = _tab == 0 
                            ? _all.where((p) => AppSession.isSaved(p.id)).toList()
                            : _recent;
                        
                        if (savedProperties.isEmpty) {
                          return Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 40),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Empty State Image
                                  Image.asset(
                                    'assets/images/save.webp',
                                    height: 180, // Slightly reduced to give more whitespace
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(height: 32),
                                  const Text(
                                    'No saved properties yet',
                                    style: TextStyle(
                                      fontSize: 18, // Reduced for whitespace
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Tap the heart icon on a listing to save it and view it here later.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14, // Reduced for whitespace
                                      color: Color(0xFF6B7280),
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 24), // Tighter spacing to hug the button
                                  // Call to Action Button hugging content
                                  ElevatedButton(
                                    onPressed: () {
                                      // TODO: Add logic to navigate to listings/home tab
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3F37C9),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32, vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'View listings',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
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
                                    : widget.onSelectProperty?.call(property)),
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
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      property.name,
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w900,
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
                                                      _toggleSave(property.id);
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
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color:
                                                            Color(0xFF9CA3AF),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis,
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
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  const Text(
                                                    '/month',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Color(0xFF9CA3AF),
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              const Spacer(),

                                              // Rating & Beds
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  // Rating Pill
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFF3F4F6),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons.star_rounded,
                                                          size: 14,
                                                          color:
                                                              Color(0xFFF59E0B),
                                                        ),
                                                        const SizedBox(
                                                            width: 4),
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
                                                      fontWeight:
                                                          FontWeight.w600,
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

// --- Skeleton Loading Components ---

/// Provides a repeating opacity pulse to mimic shimmer without external packages
class _SkeletonPulse extends StatefulWidget {
  final Widget child;
  const _SkeletonPulse({required this.child});

  @override
  State<_SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<_SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_controller),
      child: widget.child,
    );
  }
}

/// Mimics the layout of the property list items while loading
class _SkeletonListLoader extends StatelessWidget {
  const _SkeletonListLoader();

  @override
  Widget build(BuildContext context) {
    final skeletonColor = const Color(0xFFE5E7EB);
    
    return _SkeletonPulse(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 112),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                // Skeleton Image
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                const SizedBox(width: 16),
                // Skeleton Content Details
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              height: 18,
                              width: 120,
                              decoration: BoxDecoration(
                                color: skeletonColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            Container(
                              height: 20,
                              width: 20,
                              decoration: BoxDecoration(
                                color: skeletonColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 12,
                          width: 80,
                          decoration: BoxDecoration(
                            color: skeletonColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          height: 16,
                          width: 100,
                          decoration: BoxDecoration(
                            color: skeletonColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              height: 24,
                              width: 65,
                              decoration: BoxDecoration(
                                color: skeletonColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            Container(
                              height: 12,
                              width: 45,
                              decoration: BoxDecoration(
                                color: skeletonColor,
                                borderRadius: BorderRadius.circular(4),
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
        },
      ),
    );
  }
}