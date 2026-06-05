import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/screens/communication/notifications_view.dart';
import 'package:property_app/widgets/shared.dart';
import 'package:property_app/services/property_service.dart';
import 'package:property_app/services/properties_api.dart';
// Removed unused import.

// ─── Theme colors ─────────────────────────────────────────────────────────────
const _primaryText = Color(0xFF4F70F8);
const _bg = Color(0xFFFAFAFA);
const _dark = Color(0xFF111827);
const _grey = Color(0xFF9CA3AF);
const _green = Color(0xFF22C55E);

// ─── Data Model & Stub Data ───────────────────────────────────────────────────
class PropertyFeatures {
  final int beds;
  final int rooms;
  final int baths;
  final bool furnished;

  const PropertyFeatures({
    this.beds = 0,
    this.rooms = 0,
    this.baths = 0,
    this.furnished = false,
  });
}

class Agent {
  final String id;
  final String name;
  final String avatarUrl;

  const Agent({
    this.id = '',
    this.name = '',
    this.avatarUrl = '',
  });
}

class _Property {
  final String id;
  final String category;
  final String name;
  final String location;

  /// Single thumbnail (kept for backward compatibility with stub data).
  final String image;

  /// Gallery images from backend.
  final List<String> images;

  /// Property amenities.
  final List<String> amenities;

  /// Beds/rooms/baths/etc.
  final PropertyFeatures features;

  /// Landlord/agent info (best-effort, depends on API response).
  final Agent landlord;

  final double rating;
  final int reviews;
  final String price;

  const _Property({
    required this.id,
    required this.category,
    required this.name,
    required this.location,
    required this.image,
    this.images = const [],
    this.amenities = const [],
    this.features = const PropertyFeatures(),
    this.landlord = const Agent(),
    required this.rating,
    required this.reviews,
    required this.price,
  });
}

// Exactly matching the screenshot's chip labels
const _filters = ['Apertments', 'Bedsitter', 'Single Room'];

final _allNearbyProperties = [
  // Apertments (>= 3 per filter)
  const _Property(
    id: '1',
    category: 'Apertments',
    name: '11 Green bank',
    location: 'Kilifi, Kenya',
    image: 'assets/images/hero.jpg',
    rating: 4.8,
    reviews: 124,
    price: 'Kes. 12k',
  ),
  const _Property(
    id: '2',
    category: 'Apertments',
    name: 'Azure Heights',
    location: 'Mombasa, Kenya',
    image: 'assets/images/hero1.jpg',
    rating: 4.6,
    reviews: 88,
    price: 'Kes. 18k',
  ),
  const _Property(
    id: '8',
    category: 'Apertments',
    name: 'Modern Living',
    location: 'Kilimani, Nairobi',
    image: 'assets/images/apertment1.jpg',
    rating: 4.7,
    reviews: 102,
    price: 'Kes. 20k',
  ),

  // Bedsitter (>= 3 per filter)
  const _Property(
    id: '3',
    category: 'Bedsitter',
    name: 'Cozy Studio',
    location: 'Nairobi, Kenya',
    image: 'assets/images/hero3.jpg',
    rating: 4.5,
    reviews: 90,
    price: 'Kes. 8k',
  ),
  const _Property(
    id: '9',
    category: 'Bedsitter',
    name: 'Luxury Bedsitter',
    location: 'Westlands, Nairobi',
    image: 'assets/images/apertment2.jpg',
    rating: 4.9,
    reviews: 201,
    price: 'Kes. 15k',
  ),
  const _Property(
    id: '10',
    category: 'Bedsitter',
    name: 'Comfy Corner',
    location: 'Lavington, Nairobi',
    image: 'assets/images/apertment3.jpg',
    rating: 4.4,
    reviews: 77,
    price: 'Kes. 10k',
  ),

  // Single Room (>= 3 per filter)
  const _Property(
    id: '4',
    category: 'Single Room',
    name: 'Minimal Space',
    location: 'Nakuru, Kenya',
    image: 'assets/images/hero2.jpg',
    rating: 4.2,
    reviews: 45,
    price: 'Kes. 5k',
  ),
  const _Property(
    id: '11',
    category: 'Single Room',
    name: 'Student Room',
    location: 'Juja, Kenya',
    image: 'assets/images/rec1.jpg',
    rating: 4.3,
    reviews: 67,
    price: 'Kes. 4k',
  ),
  const _Property(
    id: '12',
    category: 'Single Room',
    name: 'Quiet Retreat',
    location: 'Thika, Kenya',
    image: 'assets/images/rec2.jpg',
    rating: 4.1,
    reviews: 39,
    price: 'Kes. 3.8k',
  ),
];

// Recommendations should always have at least 3 cards total.
final _allRecommendedProperties = [
  const _Property(
    id: '5',
    category: 'Apertments',
    name: 'Modern Studio Apartment',
    location: 'Kilimani, Nairobi',
    image: 'assets/images/rec1.jpg',
    rating: 4.8,
    reviews: 124,
    price: 'Kes. 25k',
  ),
  const _Property(
    id: '6',
    category: 'Bedsitter',
    name: 'Luxury Bedsitter',
    location: 'Westlands, Nairobi',
    image: 'assets/images/rec2.jpg',
    rating: 4.9,
    reviews: 201,
    price: 'Kes. 15k',
  ),
  const _Property(
    id: '7',
    category: 'Single Room',
    name: 'Student Room',
    location: 'Juja, Kenya',
    image: 'assets/images/rec3.jpg',
    rating: 4.3,
    reviews: 67,
    price: 'Kes. 4k',
  ),
];

// ─── HomeView ─────────────────────────────────────────────────────────────────

class HomeView extends StatefulWidget {
  final void Function(String id)? onSelectProperty;
  final VoidCallback? onNotifications;

  const HomeView({
    super.key,
    this.onSelectProperty,
    this.onNotifications,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _activeFilter = 0;
  final _searchController = TextEditingController();
  final PageController _carouselController =
      PageController(viewportFraction: 0.88);
  final _service = PropertyService.instance;

  List<_Property> _nearby = [];
  List<_Property> _recommended = [];
  bool _loadingNearby = true;
  bool _loadingRecommended = true;

  String _uiCategoryToBackend(String ui) {
    final normalized = ui.trim().toLowerCase();
    // Backend categories (from local mock) are: Apartment, Studio, Penthouse.
    // UI chips are: Apertments, Bedsitter, Single Room.
    if (normalized == 'apertments' || normalized == 'apartment(s)') {
      return 'Apartment';
    }
    if (normalized == 'bedsitter') {
      return 'Studio';
    }
    if (normalized == 'single room') {
      return 'Penthouse';
    }
    return ui;
  }

  // Getter for functionally filtering the arrays based on the selected chip
  List<_Property> get _filteredNearby {
    final backendCategory = _uiCategoryToBackend(_filters[_activeFilter]);
    return _nearby.where((p) => p.category == backendCategory).toList();
  }

  List<_Property> get _filteredRecommended {
    final backendCategory = _uiCategoryToBackend(_filters[_activeFilter]);
    return _recommended.where((p) => p.category == backendCategory).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loadingNearby = true;
      _loadingRecommended = true;
    });

    try {
      // Fetch all properties from API
      final allProperties = await PropertiesApi.getAllProperties();

      if (allProperties.isNotEmpty) {
        final properties =
            allProperties.map((p) => _mapFromApiResponse(p)).toList();

        // Nearby: all properties (filtered by chip in UI)
        // Recommended: backend recommendations if available, otherwise top 3 from all.
        final rec = await PropertiesApi.getRecommendations();
        final recMapped = rec.isNotEmpty
            ? rec.map((p) => _mapFromApiResponse(p)).toList()
            : properties.take(3).toList();

        setState(() {
          _nearby = properties;
          _recommended = recMapped;
          _loadingNearby = false;
          _loadingRecommended = false;
        });
      } else {
        // Remote returned empty; keep empty so UI doesn't show dummy data.
        setState(() {
          _nearby = [];
          _recommended = [];
          _loadingNearby = false;
          _loadingRecommended = false;
        });
      }
    } catch (e) {
      // Error loading data; keep empty so UI doesn't show dummy data.
      debugPrint('Error loading properties: $e');
      setState(() {
        _nearby = [];
        _recommended = [];
        _loadingNearby = false;
        _loadingRecommended = false;
      });
    }
  }

  _Property _mapFromApiResponse(Map<String, dynamic> p) {
    final priceValue = p['price'];
    final price =
        priceValue is String ? priceValue : priceValue?.toString() ?? '0';

    final category = p['category']?.toString() ?? 'Apartment';

    final id = p['id']?.toString() ?? p['_id']?.toString() ?? '';

    // Backend SELECTs: image_url, bedrooms, bathrooms; but other fields may exist.
    final thumbnailCandidates = <String?>[
      (p['photos'] is List && (p['photos'] as List).isNotEmpty)
          ? (p['photos'] as List).first?.toString()
          : null,
      (p['images'] is List && (p['images'] as List).isNotEmpty)
          ? (p['images'] as List).first?.toString()
          : null,
      p['image_url']?.toString(),
      p['image']?.toString(),
    ].whereType<String>().toList();

    final images = (() {
      final photos = p['photos'];
      if (photos is List) {
        return photos.map((e) => e?.toString()).whereType<String>().toList();
      }
      final maybeImages = p['images'];
      if (maybeImages is List) {
        return maybeImages
            .map((e) => e?.toString())
            .whereType<String>()
            .toList();
      }
      final imageUrl = p['image_url']?.toString();
      if (imageUrl != null && imageUrl.trim().isNotEmpty) return [imageUrl];
      final image = p['image']?.toString();
      if (image != null && image.trim().isNotEmpty) return [image];
      return const <String>[];
    })();

    final amenities = (() {
      final a = p['amenities'];
      if (a is List)
        return a.map((e) => e?.toString()).whereType<String>().toList();
      return const <String>[];
    })();

    final features = PropertyFeatures(
      beds: (p['bedrooms'] is num)
          ? (p['bedrooms'] as num).toInt()
          : int.tryParse(p['bedrooms']?.toString() ?? '') ?? 0,
      rooms: ((p['bedrooms'] is num)
              ? (p['bedrooms'] as num).toInt()
              : int.tryParse(p['bedrooms']?.toString() ?? '') ?? 0) +
          1,
      baths: (p['bathrooms'] is num)
          ? (p['bathrooms'] as num).toInt()
          : int.tryParse(p['bathrooms']?.toString() ?? '') ?? 0,
      furnished: (p['furnished'] is bool) ? (p['furnished'] as bool) : false,
    );

    final landlord = Agent(
      id: p['landlord_id']?.toString() ?? '',
      name: p['landlord_name']?.toString() ?? 'Agent',
      avatarUrl: p['landlord_avatar']?.toString() ??
          p['landlord_avatar_url']?.toString() ??
          'https://i.pravatar.cc/150?img=1',
    );

    final name = p['title']?.toString() ?? p['name']?.toString() ?? 'Unknown';
    final location =
        p['city']?.toString() ?? p['location']?.toString() ?? 'Unknown';

    final rating = (p['rating'] is num) ? (p['rating'] as num).toDouble() : 4.5;
    final reviews = (p['reviews'] is num) ? (p['reviews'] as num).toInt() : 0;

    final image = (() {
      if (images.isNotEmpty) return images.first;
      if (thumbnailCandidates.isNotEmpty) {
        return thumbnailCandidates.first;
      }
      return 'assets/images/hero.jpg';
    })();

    return _Property(
      id: id,
      category: category,
      name: name,
      location: location,
      image: image,
      images: images,
      amenities: amenities,
      features: features,
      landlord: landlord,
      rating: rating,
      reviews: reviews,
      price: 'Kes. $price',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Theme(
        data: ThemeData(
          textTheme: GoogleFonts.poppinsTextTheme(),
        ),
        child: Scaffold(
          backgroundColor: _bg,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(child: _buildNearbySection()),
              SliverToBoxAdapter(child: _buildRecommendedSection()),
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final displayName = AppSession.displayName;
    final displayAvatar = AppSession.displayAvatar;

    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 24,
        right: 24,
        bottom: 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Hello, $displayName 👋',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
              ),
              // Notification Bell
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsView(),
                    ),
                  );
                },
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE5E7EB),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_rounded,
                        size: 24,
                        color: _dark,
                      ),
                      Positioned(
                        top: 10,
                        right: 12,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Avatar (tap to open Profile)
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/profile'),
                child: Avatar(
                  url: displayAvatar,
                  name: displayName,
                  size: 46,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Hero Text
          Text(
            'Find your\nperfect place',
            style: GoogleFonts.poppins(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: _dark,
              height: 1.2,
              letterSpacing: -1.0,
            ),
          ),

          const SizedBox(height: 24),

          // Search Bar
          Container(
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(
                    Icons.search_rounded,
                    color: _dark,
                    size: 22,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: _dark,
                      fontWeight: FontWeight.w500,
                    ),
                    onSubmitted: (v) async {
                      await _service.saveSearchTerm(v);
                      await _loadData();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search locations, area...',
                      hintStyle: GoogleFonts.poppins(
                        color: _grey,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Icon(
                    Icons.cancel_outlined,
                    size: 22,
                    color: _dark,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: _filters.asMap().entries.map((e) {
                final isActive = e.key == _activeFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _activeFilter = e.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isActive ? _dark : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isActive ? _dark : Colors.grey.shade200,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        e.value,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : _dark,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ─── Nearby Section ────────────────────────────────────────────────────────

  Widget _buildNearbySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Nearby You',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                'See all',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _primaryText,
                ),
              ),
            ],
          ),
        ),
        if (_filteredNearby.isEmpty)
          _loadingNearby
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Center(
                    child: Text(
                      'No ${_filters[_activeFilter]} nearby.',
                      style: GoogleFonts.poppins(color: _grey),
                    ),
                  ),
                )
        else
          SizedBox(
            height: 380,
            child: PageView.builder(
              controller: _carouselController,
              clipBehavior: Clip.none,
              physics: const BouncingScrollPhysics(),
              itemCount: _filteredNearby.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _NearbyCard(
                  property: _filteredNearby[i],
                  onTap: () => widget.onSelectProperty?.call(
                    _filteredNearby[i].id,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Recommended Section ──────────────────────────────────────────────────

  Widget _buildRecommendedSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Recommended For You',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingRecommended)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filteredRecommended.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No recommendations found.',
                style: GoogleFonts.poppins(color: _grey),
              ),
            )
          else
            ..._filteredRecommended.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _RecommendedCard(
                  property: p,
                  onTap: () => widget.onSelectProperty?.call(p.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Nearby Card ────────────────────────────────────────────────────────────

class _NearbyCard extends StatelessWidget {
  final _Property property;
  final VoidCallback onTap;

  const _NearbyCard({required this.property, required this.onTap});

  bool _isNetworkImage(String url) {
    final s = url.trim();
    return s.startsWith('http://') || s.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _isNetworkImage(property.image)
                  ? Image.network(
                      property.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.expand(),
                    )
                  : Image.asset(
                      property.image,
                      fit: BoxFit.cover,
                    ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.4, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.85),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 18,
                left: 18,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFBBC05), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${property.rating}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _dark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Positioned(
                top: 18,
                right: 18,
                child: VerifiedBadge(size: 36),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            property.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          property.price,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _green,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          '/month',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Recommended Card ──────────────────────────────────────────────────────

class _RecommendedCard extends StatelessWidget {
  final _Property property;
  final VoidCallback onTap;

  const _RecommendedCard({required this.property, required this.onTap});

  bool _isNetworkImage(String url) {
    final s = url.trim();
    return s.startsWith('http://') || s.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _isNetworkImage(property.image)
                  ? Image.network(
                      property.image,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.expand(),
                    )
                  : Image.asset(
                      property.image,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 16),
            // Prevent horizontal overflow inside the recommended card.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 14, color: _grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: _grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Force this row to wrap content rather than overflow.
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 0,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            property.price,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _dark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            '/mo',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: _grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Color(0xFFFBBC05), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${property.rating}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
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
          ],
        ),
      ),
    );
  }
}
