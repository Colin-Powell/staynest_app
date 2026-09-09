import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/session/onboarding_prefs.dart';
import 'package:property_app/widgets/onboarding_bottom_sheet.dart';
import 'package:property_app/widgets/property_card.dart';

import 'package:property_app/models/property.dart';
import 'package:property_app/services/properties_api.dart';
import 'package:property_app/utils/property_mapper.dart';
import 'package:property_app/utils/category_utils.dart';

const _bg = Color(0xFFFAFAFA);
const _dark = Color(0xFF111827);
const _grey = Color(0xFF9CA3AF);
const _primaryText = Color(0xFF4F70F8);

class HomeView extends StatefulWidget {
  final void Function(Property)? onSelectProperty;
  final VoidCallback? onNotifications;
  final void Function(String category)? onSeeCategory;

  const HomeView({
    super.key,
    this.onSelectProperty,
    this.onNotifications,
    this.onSeeCategory,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _searchController = TextEditingController();

  Map<String, List<Property>> _collections = {};
  bool _loading = true;
  bool _hasError = false;
  String _selectedCategory = 'All';

  bool _matchesCategory(Property p, String category) {
    return categoryMatchesUiFilter(
      p.category,
      category,
      beds: p.features.beds,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadCollections();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!OnboardingPrefs.hasSeen('homeSeen')) {
        OnboardingBottomSheet.show(
          context: context,
          imagePath: 'assets/images/home_onboarding.png',
          title: 'Discover your next stay',
          subtitle:
              'Browse curated property collections, discover trending stays, and find highly rated properties near you.',
          ctaText: 'Explore stays',
        ).then((_) => OnboardingPrefs.markAsSeen('homeSeen'));
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCollections() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });

    try {
      final categoriesData = await PropertiesApi.getCategories();
      Map<String, List<Property>> mapped = {};

      // Add personalized layers before the public category collections.
      try {
        if (AppSession.currentUserId != null) {
          final recentData = await PropertiesApi.getRecentlyViewed();
          if (recentData.isNotEmpty) {
            mapped['Recently Viewed'] =
                recentData.map((e) => mapApiProperty(e)).toList();
          }

          final recommendations = await PropertiesApi.getRecommendations();
          if (recommendations.isNotEmpty) {
            mapped['Recommended For You'] =
                recommendations.map((e) => mapApiProperty(e)).toList();
          }
        }
      } catch (e) {
        debugPrint('Error loading personalized home layers: $e');
      }

      categoriesData.forEach((key, value) {
        if (value is List) {
          mapped[key] = value
              .map((e) => mapApiProperty(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      });

      // Fallback if categories are empty, fetch all and group manually
      if (categoriesData.isEmpty) {
        final allProps = await PropertiesApi.getAllProperties();
        final list = allProps.map((e) => mapApiProperty(e)).toList();

        mapped['New on StayNest'] = list.take(5).toList();
        mapped['Trending Now'] =
            list.where((p) => p.rating >= 4.0).take(5).toList();
        mapped['Budget-Friendly'] =
            list.where((p) => p.price < 25000).take(5).toList();
      }

      if (mounted) {
        setState(() {
          _collections = mapped;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading collections: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCollections = <String, List<Property>>{};
    for (final entry in _collections.entries) {
      final filteredList = entry.value
          .where((p) => _matchesCategory(p, _selectedCategory))
          .toList();
      if (filteredList.isNotEmpty) {
        filteredCollections[entry.key] = filteredList;
      }
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCollections,
          color: _primaryText,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildCategoryPills()),
              if (_loading)
                SliverToBoxAdapter(child: _buildShimmerLoading())
              else if (_hasError)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text('Failed to load properties',
                          style: GoogleFonts.poppins(color: _grey)),
                    ),
                  ),
                )
              else if (filteredCollections.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                          _collections.isEmpty
                              ? 'No properties available'
                              : 'No properties match this category',
                          style: GoogleFonts.poppins(color: _grey)),
                    ),
                  ),
                )
              else
                ...() {
                  final sliverWidgets = <Widget>[];
                  bool promoAdded = false;

                  for (int i = 0; i < filteredCollections.length; i++) {
                    final entry = filteredCollections.entries.elementAt(i);

                    // Add the horizontal collection
                    sliverWidgets.add(
                      SliverToBoxAdapter(
                        child: _buildHorizontalCollection(entry.key, entry.value),
                      ),
                    );

                    // Insert Promo Card after 'Recently Viewed', or after the 1st item if Recently Viewed doesn't exist
                    if (entry.key == 'Recently Viewed' || (!filteredCollections.containsKey('Recently Viewed') && i == 0)) {
                      sliverWidgets.add(SliverToBoxAdapter(child: _buildPromoCard()));
                      promoAdded = true;
                    }
                  }
                  
                  return sliverWidgets;
                }(),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── PROMOTION CARD ─────────────────────────────────────────────────────────

  Widget _buildPromoCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _grey.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REHANI',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Find affordable pre-loved essentials from students around you.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: _grey,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _primaryText.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Coming Soon',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _primaryText,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Image.asset(
              'assets/images/rehani.png',
              width: 90,
              height: 90,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: _grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(PhosphorIconsRegular.shoppingBag, color: _grey, size: 32),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── UI BUILDERS ──────────────────────────────────────────────────────────

  Widget _buildCategoryPills() {
    final types = [
      {'name': 'All', 'image': 'assets/images/all.webp'},
      {'name': 'Apartments', 'image': 'assets/images/apartments.webp'},
      {'name': 'Bedsitter', 'image': 'assets/images/bedsitter.webp'},
      {'name': 'Single Room', 'image': 'assets/images/singleroom.webp'},
      {'name': 'One Bedroom', 'image': 'assets/images/onebedroom.webp'},
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: SizedBox(
        height: 52, // Adjusted height for premium pills
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: types.length,
          separatorBuilder: (context, index) => const SizedBox(width: 16),
          itemBuilder: (context, index) {
            final type = types[index];
            final label = type['name']!;
            final imagePath = type['image']!;
            final isSelected = _selectedCategory == label;

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (_selectedCategory == label) {
                    _selectedCategory = 'All'; // Deselect if already selected
                  } else {
                    _selectedCategory = label;
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.only(
                    left: 6, right: 16, top: 6, bottom: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected
                        ? Colors.black
                        : Colors.grey.withOpacity(0.2),
                    width: isSelected ? 2.0 : 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: AssetImage(imagePath),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _dark,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Where to next?',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              GestureDetector(
                onTap: widget.onNotifications,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: const Icon(PhosphorIconsRegular.bell,
                      color: _dark, size: 24),
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => widget.onSeeCategory?.call(''), // Route to search tab
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.magnifyingGlass,
                      color: _grey, size: 22),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Search destinations',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _dark,
                        ),
                      ),
                      Text(
                        'Anywhere • Any week • Add guests',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _grey,
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

  Widget _buildHorizontalCollection(String title, List<Property> properties) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => widget.onSeeCategory
                      ?.call(title), // Route to search tab with category
                  child: Text(
                    'See All',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 380,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 24),
              itemCount: properties.length,
              itemBuilder: (context, index) {
                final p = properties[index];
                return PropertyCard(
                  property: p,
                  onTap: () => widget.onSelectProperty?.call(p),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(2, (sectionIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Shimmer.fromColors(
                  baseColor: Colors.grey.shade200,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                    width: 150,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 380,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 24),
                  itemCount: 3,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: Shimmer.fromColors(
                        baseColor: Colors.grey.shade200,
                        highlightColor: Colors.grey.shade100,
                        child: Container(
                          width: 300,
                          height: 380,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        );
      }),
    );
  }
}