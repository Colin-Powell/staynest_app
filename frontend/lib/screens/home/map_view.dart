// lib/screens/map_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:property_app/models/property.dart';
import 'package:property_app/models/property_taxonomy.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/theme.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/widgets/shared.dart';
import 'package:property_app/services/routing_service.dart';
import 'package:property_app/services/property_service.dart';

// Assuming PropertyCard is available from your earlier refactor
import 'package:property_app/widgets/property_card.dart';

// ── Configurations ──────────────────────────────────────────────
const double _desktopMaxContentWidth = 1760;
const LatLng _defaultLocation = LatLng(-1.2921, 36.8219);
const double _defaultZoom = 11.5;
const double _detailZoom = 14.5;
const int _itemsPerPage = 12;

class MapViewScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onFilter;
  final void Function(Property property)? onSelectProperty;
  final List<Property>? properties;
  final String? searchQuery;
  final Future<void> Function({VoidCallback? onAuthenticated})?
      onRequireAuthentication;
  final bool isNavigation;
  final LatLng? navOrigin;
  final LatLng? navDestination;

  const MapViewScreen({
    super.key,
    required this.onBack,
    required this.onFilter,
    this.onSelectProperty,
    this.properties,
    this.searchQuery,
    this.onRequireAuthentication,
    this.isNavigation = false,
    this.navOrigin,
    this.navDestination,
  });

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen>
    with TickerProviderStateMixin {
  // ── Entry animations ──────────────────────────────────────────
  late final AnimationController _entryCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 550));
  late final Animation<Offset> _headerSlide = Tween<Offset>(
          begin: const Offset(0, -1), end: Offset.zero)
      .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

  // ── Navigation animation ──────────────────────────────────────
  late final LatLng _routeOrigin;
  late final LatLng _routeDestination;
  late List<LatLng> _navRoute;
  late final AnimationController _navProgressCtrl;
  late final Animation<double> _navProgress;

  // ── Data & Interaction State ──────────────────────────────────
  bool _isLoading = true;
  String? _errorMessage;

  String? _selectedId;
  final ValueNotifier<String?> _hoveredId = ValueNotifier<String?>(null);

  List<Property> _allProperties = [];
  double _maxDataPrice = 100000; // Will be dynamically calculated

  // ── Filter State ──
  late RangeValues _priceRange;
  final Set<String> _selectedAmenities = {};
  static const _quickFilterIds = [
    'parking',
    'pet_friendly',
    'wifi',
    'pool',
    'gym',
    'furnished',
    'water_available',
    'secure_compound',
  ];

  // ── Pagination State ──
  int _currentPage = 1;

  // Scrolling
  final MapController _mapCtrl = MapController();
  final ScrollController _listScrollCtrl = ScrollController();
  final Map<String, GlobalKey> _cardKeys = {};

  @override
  void initState() {
    super.initState();
    _routeOrigin = widget.navOrigin ?? _defaultLocation;
    _routeDestination = widget.navDestination ?? const LatLng(-1.3000, 36.8300);
    _navRoute = [_routeOrigin, _routeDestination];
    _priceRange = RangeValues(0, _maxDataPrice);

    _navProgressCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 24));
    _navProgress =
        CurvedAnimation(parent: _navProgressCtrl, curve: Curves.easeInOut);

    _loadProperties();

    if (widget.isNavigation) {
      _navProgressCtrl.repeat(reverse: false);
      fetchAndSetRoute();
    }

    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted) _entryCtrl.forward();
    });
  }

  // --- Dynamic Bounds Calculation ---
  double _propertyPriceAsDouble(Property property) {
    final price = property.price as num?;
    return price?.toDouble() ?? 0.0;
  }

  void _updateDynamicBounds() {
    if (_allProperties.isEmpty) return;

    double maxP = _allProperties
        .map(_propertyPriceAsDouble)
        .reduce((a, b) => a > b ? a : b);
    _maxDataPrice = (maxP / 10000).ceil() * 10000; // round up to nearest 10k
    if (_maxDataPrice < 50000) _maxDataPrice = 50000; // Sensible minimum max

    _priceRange = RangeValues(0, _maxDataPrice);
  }

  // --- Hover Helper ---
  void _setHover(String? id) {
    if (_hoveredId.value == id) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hoveredId.value = id;
    });
  }

  // --- Filter Logic ---
  List<Property> get _filteredProperties {
    return _allProperties.where((p) {
      final inPriceRange =
          p.price >= _priceRange.start && p.price <= _priceRange.end;
      final hasSelectedAmenities = _selectedAmenities.every((id) {
        return p.amenities
            .any((amenity) => PropertyTaxonomy.mapLegacyLabel(amenity) == id);
      });
      return inPriceRange && hasSelectedAmenities;
    }).toList();
  }

  // --- Pagination Logic ---
  int get _totalPages => (_filteredProperties.length / _itemsPerPage).ceil();

  List<Property> get _paginatedProperties {
    final start = (_currentPage - 1) * _itemsPerPage;
    return _filteredProperties.skip(start).take(_itemsPerPage).toList();
  }

  // --- Scroll to Property Logic ---
  void _onMarkerTapped(Property p, bool isDesktop) {
    setState(() => _selectedId = p.id);
    _mapCtrl.move(LatLng(p.lat, p.lng), _detailZoom);

    if (isDesktop) {
      final index = _filteredProperties.indexWhere((prop) => prop.id == p.id);
      if (index != -1) {
        final targetPage = (index / _itemsPerPage).floor() + 1;
        if (_currentPage != targetPage) {
          setState(() => _currentPage = targetPage);
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToCard(p.id));
        } else {
          _scrollToCard(p.id);
        }
      }
    } else {
      widget.onSelectProperty?.call(p);
    }
  }

  void _openPropertyDetails(Property property) {
    final onSelectProperty = widget.onSelectProperty;
    if (onSelectProperty != null) {
      onSelectProperty(property);
    } else {
      _onMarkerTapped(property, true);
    }
  }

  void _scrollToCard(String id) {
    final key = _cardKeys[id];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
    }
  }

  void _changePage(int newPage) {
    setState(() => _currentPage = newPage);
    _listScrollCtrl.animateTo(0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic);
  }

  void _applyPriceRange(RangeValues r) {
    setState(() {
      _priceRange = r;
      _currentPage = 1;
    });
    _fitMapBounds();
  }

  // --- Data Loading ---
  Future<void> _loadProperties() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final supplied = widget.properties;
      final loaded = supplied != null && supplied.isNotEmpty
          ? supplied
          : await PropertyService.instance.fetchProperties();

      if (mounted) {
        setState(() {
          _allProperties = loaded;
          _isLoading = false;
          _updateDynamicBounds();
        });
        _fitMapBounds();
      }
    } catch (error) {
      debugPrint('Property map fetch error: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              "Failed to load properties. Please check your connection.";
        });
      }
    }
  }

  Future<void> _handleSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results =
          await PropertyService.instance.fetchProperties(city: query.trim());
      if (mounted) {
        setState(() {
          _allProperties = results;
          _currentPage = 1;
          _isLoading = false;
          _updateDynamicBounds();
        });
        _fitMapBounds();
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "We couldn't complete your search.";
        });
      }
    }
  }

  void _fitMapBounds() {
    if (widget.isNavigation) return;
    final validProps =
        _filteredProperties.where((p) => p.lat != 0.0 && p.lng != 0.0).toList();
    if (validProps.isEmpty) return;

    final points = validProps.map((p) => LatLng(p.lat, p.lng)).toList();
    final bounds = LatLngBounds.fromPoints(points);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapCtrl.fitCamera(CameraFit.bounds(
            bounds: bounds, padding: const EdgeInsets.all(80), maxZoom: 15.0));
      }
    });
  }

  Future<void> fetchAndSetRoute() async {
    try {
      final route = await fetchRouteOsrm(_routeOrigin, _routeDestination);
      if (mounted && route.isNotEmpty) setState(() => _navRoute = route);
    } catch (e) {
      debugPrint('Route fetch error: $e');
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _navProgressCtrl.dispose();
    _listScrollCtrl.dispose();
    _mapCtrl.dispose();
    _hoveredId.dispose();
    super.dispose();
  }

  // ── Render Helpers ───────────────────────────────────────────────────────
  List<Marker> _buildMarkers({bool isDesktop = false}) {
    if (_isLoading || _errorMessage != null) return [];

    final list = _filteredProperties;
    return List.generate(list.length, (i) {
      final prop = list[i];
      return Marker(
        point: LatLng(prop.lat, prop.lng),
        width: 120,
        height: 40,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: isDesktop ? (_) => _setHover(prop.id) : null,
          onExit: isDesktop ? (_) => _setHover(null) : null,
          child: ValueListenableBuilder<String?>(
            valueListenable: _hoveredId,
            builder: (_, hovered, __) => _PricePin(
              label: 'Ksh. ${prop.price.toInt()}',
              isSelected:
                  _selectedId == prop.id || (isDesktop && hovered == prop.id),
              onTap: () => _onMarkerTapped(prop, isDesktop),
            ),
          ),
        ),
      );
    });
  }

  List<Marker> _buildNavigationMarkers() => [
        Marker(
            point: _routeOrigin,
            width: 24,
            height: 24,
            child: Icon(Icons.my_location_rounded,
                color: AppColors.primary, size: 24)),
        Marker(
            point: _routeDestination,
            width: 32,
            height: 32,
            child: const Icon(Icons.location_on_rounded,
                color: AppColors.gray900, size: 32)),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            if (isDesktop && !widget.isNavigation) {
              return _buildDesktopSplitLayout(constraints);
            }
            return _buildMobileStackLayout(constraints);
          },
        ),
      ),
    );
  }

  // ── Desktop Layout (Airbnb Spaced Out & Breathing Room) ──────────────────
  Widget _buildDesktopSplitLayout(BoxConstraints constraints) {
    final validProps =
        _filteredProperties.where((p) => p.lat != 0.0 && p.lng != 0.0).toList();
    final mapCenter = validProps.isNotEmpty
        ? LatLng(validProps.first.lat, validProps.first.lng)
        : _defaultLocation;

    return Center(
      child: SizedBox(
        width:
            constraints.maxWidth.clamp(0.0, _desktopMaxContentWidth).toDouble(),
        child: Column(
          children: [
            // ── 1. GLOBAL TOP HEADER ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: const BoxDecoration(color: Colors.white),
              child: Row(
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: CircleIconButton(
                      onTap: widget.onBack,
                      child: const Icon(Icons.chevron_left_rounded,
                          size: 26, color: AppColors.gray900),
                    ),
                  ),

                  // Center Search Bar
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: _SearchBar(
                          text: widget.searchQuery ??
                              (_allProperties.isNotEmpty
                                  ? _allProperties.first.location
                                  : 'Nearby'),
                          onSubmitted: _handleSearch,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (!widget.isNavigation) _buildFilterPills(),

            // ── 2. Split Content View ──
            Expanded(
              child: Row(
                children: [
                  // Left Column (Paginated List)
                  Expanded(
                    flex: 11, // Slightly wider for property cards
                    child: Container(
                      color: Colors.white,
                      child: _isLoading
                          ? const _SkeletonGrid()
                          : _errorMessage != null
                              ? _buildErrorState()
                              : _buildDesktopListContent(),
                    ),
                  ),

                  // Right Column (Map with rounded corners and padding)
                  Expanded(
                    flex: 10,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          16, 24, 24, 24), // Breathing room for map
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                            24), // Airbnb style rounded map corners
                        child: Stack(
                          children: [
                            if (_isLoading)
                              const _SkeletonMap()
                            else
                              FlutterMap(
                                mapController: _mapCtrl,
                                options: MapOptions(
                                  initialCenter: mapCenter,
                                  initialZoom: _defaultZoom,
                                  interactionOptions: const InteractionOptions(
                                      flags: InteractiveFlag.all),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName:
                                        'com.rashoti.staynest',
                                  ),
                                  MarkerLayer(
                                      markers: _buildMarkers(isDesktop: true)),
                                ],
                              ),
                            if (!_isLoading && _errorMessage == null)
                              Positioned(
                                top: 24,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: _SearchAreaPill()),
                                ),
                              ),
                          ],
                        ),
                      ),
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

  Widget _buildDesktopListContent() {
    return CustomScrollView(
      controller: _listScrollCtrl,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 24, 8),
            child: Text(
              'Over ${_filteredProperties.length} homes in this area',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray900),
            ),
          ),
        ),
        if (_filteredProperties.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState()),
        if (_filteredProperties.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(32, 12, 16, 24),
            sliver: SliverLayoutBuilder(
              builder: (context, sc) {
                final cols = ((sc.crossAxisExtent + 24) / (280 + 24))
                    .floor()
                    .clamp(1, 3);
                final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  childAspectRatio: 0.95,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 32,
                );
                final items = _paginatedProperties;
                final split = (cols * 2).clamp(0, items.length);
                final head = items.sublist(0, split);
                final tail = items.sublist(split);

                return SliverMainAxisGroup(
                  slivers: [
                    SliverGrid(
                      gridDelegate: gridDelegate,
                      delegate: SliverChildBuilderDelegate(
                          (context, i) => _buildPropertyCard(head[i]),
                          childCount: head.length),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(
                            top: head.isEmpty ? 0 : 40, bottom: 40, right: 16),
                        child: _InlinePriceFilter(
                          prices: _allProperties
                              .map(_propertyPriceAsDouble)
                              .toList(),
                          range: _priceRange,
                          maxPriceBound: _maxDataPrice,
                          onApply: _applyPriceRange,
                        ),
                      ),
                    ),
                    SliverGrid(
                      gridDelegate: gridDelegate,
                      delegate: SliverChildBuilderDelegate(
                          (context, i) => _buildPropertyCard(tail[i]),
                          childCount: tail.length),
                    ),
                  ],
                );
              },
            ),
          ),
        if (_totalPages > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 64),
              child: _buildPaginationControls(),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterPills() {
    return Container(
      height: 58,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Filters'),
                onPressed: widget.onFilter,
                labelStyle: const TextStyle(
                    color: AppColors.gray900,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
            for (final id in _quickFilterIds)
              _buildFilterPill(
                label: PropertyTaxonomy.getAttributeById(id)?.label ?? id,
                selected: _selectedAmenities.contains(id),
                onSelected: () {
                  setState(() {
                    if (!_selectedAmenities.add(id)) {
                      _selectedAmenities.remove(id);
                    }
                    _currentPage = 1;
                  });
                  _fitMapBounds();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(
      {required String label,
      required bool selected,
      required VoidCallback onSelected}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onSelected(),
        labelStyle: TextStyle(
            color: selected ? Colors.white : AppColors.gray700,
            fontSize: 13,
            fontWeight: FontWeight.w600),
        backgroundColor: Colors.white,
        selectedColor: AppColors.gray900,
        side: BorderSide(
            color: selected ? AppColors.gray900 : const Color(0xFFE5E7EB)),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  // ── Single grid card (hover handled via ValueNotifier) ──
  Widget _buildPropertyCard(Property p) {
    _cardKeys.putIfAbsent(p.id, () => GlobalKey());
    return MouseRegion(
      onEnter: (_) => _setHover(p.id),
      onExit: (_) => _setHover(null),
      child: ValueListenableBuilder<String?>(
        valueListenable: _hoveredId,
        child: PropertyCard(
          property: p,
          isGrid: true,
          isHorizontal: false,
          imageAspectRatio: 1.3,
          onTap: () => _openPropertyDetails(p),
          onRequireAuthentication: widget.onRequireAuthentication,
          detailsAction: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'View property details',
              onPressed: () => _openPropertyDetails(p),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              color: AppColors.gray900,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 38, height: 38),
            ),
          ),
        ),
        builder: (_, hovered, child) {
          final selected = _selectedId == p.id;
          return AnimatedContainer(
            key: _cardKeys[p.id],
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: selected ? AppColors.gray900 : Colors.transparent,
                  width: 2),
              boxShadow: (selected || hovered == p.id)
                  ? [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 8))
                    ]
                  : [],
            ),
            child: child,
          );
        },
      ),
    );
  }

  // ── Pagination Controls UI ──
  Widget _buildPaginationControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        MouseRegion(
          cursor: _currentPage > 1
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: GestureDetector(
            onTap:
                _currentPage > 1 ? () => _changePage(_currentPage - 1) : null,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage > 1 ? Colors.white : AppColors.gray100,
                  border: Border.all(color: const Color(0xFFE5E7EB))),
              child: Icon(Icons.chevron_left_rounded,
                  color:
                      _currentPage > 1 ? AppColors.gray900 : AppColors.gray400),
            ),
          ),
        ),
        const SizedBox(width: 16),
        ...List.generate(_totalPages, (index) {
          final page = index + 1;
          final isSelected = _currentPage == page;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _changePage(page),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.gray900 : Colors.transparent),
                alignment: Alignment.center,
                child: Text('$page',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.gray700)),
              ),
            ),
          );
        }),
        const SizedBox(width: 16),
        MouseRegion(
          cursor: _currentPage < _totalPages
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: GestureDetector(
            onTap: _currentPage < _totalPages
                ? () => _changePage(_currentPage + 1)
                : null,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage < _totalPages
                      ? Colors.white
                      : AppColors.gray100,
                  border: Border.all(color: const Color(0xFFE5E7EB))),
              child: Icon(Icons.chevron_right_rounded,
                  color: _currentPage < _totalPages
                      ? AppColors.gray900
                      : AppColors.gray400),
            ),
          ),
        ),
      ],
    );
  }

  // ── Error & Empty States ──
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 64, color: AppColors.gray400),
          const SizedBox(height: 16),
          Text('Connection Error',
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray900)),
          const SizedBox(height: 8),
          Text(_errorMessage ?? 'Failed to load map data.',
              style: GoogleFonts.poppins(color: AppColors.gray500)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadProperties,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gray900,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded,
              size: 64, color: AppColors.gray400),
          const SizedBox(height: 16),
          Text('No exact matches',
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray900)),
          const SizedBox(height: 8),
          Text('Try changing or removing some of your filters.',
              style: GoogleFonts.poppins(color: AppColors.gray500)),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _selectedAmenities.clear();
                _priceRange = RangeValues(0, _maxDataPrice);
                _currentPage = 1;
              });
              _fitMapBounds();
            },
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gray900,
                side: const BorderSide(color: AppColors.gray900),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            child: const Text('Clear all filters'),
          )
        ],
      ),
    );
  }

  // ── Mobile Layout (Original Stack preserved) ────────────────────────────────
  Widget _buildMobileStackLayout(BoxConstraints constraints) {
    final validProps =
        _filteredProperties.where((p) => p.lat != 0.0 && p.lng != 0.0).toList();
    final mapCenter = widget.isNavigation
        ? _routeOrigin
        : (validProps.isNotEmpty
            ? LatLng(validProps.first.lat, validProps.first.lng)
            : _defaultLocation);
    final selectedMatches =
        _filteredProperties.where((p) => p.id == _selectedId);
    final selectedProperty =
        selectedMatches.isNotEmpty ? selectedMatches.first : null;

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              CircleIconButton(
                  onTap: widget.onBack,
                  child: const Icon(Icons.chevron_left_rounded,
                      size: 26, color: AppColors.gray900)),
              const SizedBox(width: 10),
              Expanded(
                  child: _SearchBar(
                      text: widget.searchQuery ?? 'Nearby',
                      onSubmitted: _handleSearch)),
            ],
          ),
        ),
        if (!widget.isNavigation) _buildFilterPills(),
        Expanded(
          child: _isLoading
              ? const _SkeletonMap()
              : _errorMessage != null
                  ? _buildErrorState()
                  : Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapCtrl,
                          options: MapOptions(
                              initialCenter: mapCenter,
                              initialZoom: _defaultZoom,
                              interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.all)),
                          children: [
                            TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.rashoti.staynest'),
                            if (widget.isNavigation)
                              PolylineLayer(polylines: [
                                Polyline(
                                    points: _navRoute,
                                    color: AppColors.primary,
                                    strokeWidth: 5,
                                    borderColor: Colors.white,
                                    borderStrokeWidth: 1.5)
                              ]),
                            MarkerLayer(
                                markers: widget.isNavigation
                                    ? _buildNavigationMarkers()
                                    : _buildMarkers(isDesktop: false)),
                          ],
                        ),
                        Positioned(
                            top: 16,
                            left: 0,
                            right: 0,
                            child: Center(child: _SearchAreaPill())),
                        if (!widget.isNavigation && selectedProperty != null)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: _PropertyPreviewCard(
                              property: selectedProperty,
                              onDismiss: () =>
                                  setState(() => _selectedId = null),
                              onSelect: () => widget.onSelectProperty
                                  ?.call(selectedProperty),
                            ),
                          ),
                      ],
                    ),
        ),
      ],
    );
  }
}

// ── Inline Price Filter ───────────────────────────────────────────────────
class _InlinePriceFilter extends StatefulWidget {
  final List<double> prices;
  final RangeValues range;
  final double maxPriceBound;
  final ValueChanged<RangeValues> onApply;

  const _InlinePriceFilter(
      {required this.prices,
      required this.range,
      required this.maxPriceBound,
      required this.onApply});

  @override
  State<_InlinePriceFilter> createState() => _InlinePriceFilterState();
}

class _InlinePriceFilterState extends State<_InlinePriceFilter> {
  static const double _min = 0;
  static const int _bins = 48;
  static const double _thumbR = 12;
  static const double _histH = 40;
  late RangeValues _current = widget.range;

  @override
  void didUpdateWidget(covariant _InlinePriceFilter old) {
    super.didUpdateWidget(old);
    if (old.range != widget.range) _current = widget.range;
  }

  List<double> get _histogram {
    final counts = List<int>.filled(_bins, 0);
    for (final p in widget.prices) {
      final i = (((p - _min) / (widget.maxPriceBound - _min)) * _bins)
          .floor()
          .clamp(0, _bins - 1);
      counts[i]++;
    }
    final peak = counts.fold<int>(0, (a, b) => b > a ? b : a);
    return counts.map((c) => peak == 0 ? 0.0 : c / peak).toList();
  }

  String _fmt(double v, {bool plus = false}) {
    final s = v
        .round()
        .toString()
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return 'Ksh. $s${plus ? '+' : ''}';
  }

  bool get _isFull =>
      _current.start <= _min && _current.end >= widget.maxPriceBound;

  @override
  Widget build(BuildContext context) {
    final bars = _histogram;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("See what's in your price range",
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gray900)),
                    const SizedBox(height: 2),
                    Text('Listing price in Ksh',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppColors.gray500)),
                  ],
                ),
              ),
              if (!_isFull)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      final full = RangeValues(_min, widget.maxPriceBound);
                      setState(() => _current = full);
                      widget.onApply(full);
                    },
                    child: Text('Clear',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: _histH + _thumbR,
            child: Stack(
              children: [
                Positioned(
                  left: _thumbR,
                  right: _thumbR,
                  top: 0,
                  height: _histH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(_bins, (i) {
                      final price = _min +
                          (i + 0.5) / _bins * (widget.maxPriceBound - _min);
                      final inRange =
                          price >= _current.start && price <= _current.end;
                      final h = bars[i] == 0
                          ? 2.0
                          : (_histH * bars[i]).clamp(4.0, _histH).toDouble();
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          height: h,
                          decoration: BoxDecoration(
                            color: inRange
                                ? AppColors.primary.withOpacity(0.7)
                                : AppColors.gray500.withOpacity(0.2),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(2)),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _thumbR * 2,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      rangeThumbShape: const RoundRangeSliderThumbShape(
                          enabledThumbRadius: _thumbR,
                          elevation: 3,
                          pressedElevation: 5),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: _thumbR),
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: const Color(0xFFDDDDDD),
                      thumbColor: Colors.white,
                      overlayColor: AppColors.primary.withOpacity(0.08),
                      trackHeight: 3,
                    ),
                    child: RangeSlider(
                      values: _current,
                      min: _min,
                      max: widget.maxPriceBound,
                      onChanged: (v) => setState(() => _current = v),
                      onChangeEnd: (v) => widget.onApply(v),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, c) {
            final trackW = c.maxWidth - _thumbR * 2;
            double xOf(double v) =>
                _thumbR + (v - _min) / (widget.maxPriceBound - _min) * trackW;
            final xs = xOf(_current.start);
            final xe = xOf(_current.end);
            final style = GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.gray900);
            final atMax = _current.end >= widget.maxPriceBound;

            Widget label(double x, String text, double w) => Positioned(
                  left: (x - w / 2)
                      .clamp(0.0, (c.maxWidth - w).clamp(0.0, double.infinity))
                      .toDouble(),
                  width: w,
                  child: Center(child: Text(text, style: style)),
                );

            if (xe - xs < 120) {
              return SizedBox(
                  height: 22,
                  child: Stack(children: [
                    label(
                        (xs + xe) / 2,
                        '${_fmt(_current.start)} – ${_fmt(_current.end, plus: atMax)}',
                        220)
                  ]));
            }
            return SizedBox(
                height: 22,
                child: Stack(children: [
                  label(xs, _fmt(_current.start), 120),
                  label(xe, _fmt(_current.end, plus: atMax), 120)
                ]));
          }),
        ],
      ),
    );
  }
}

// ── Skeletons for Scalable Loading States ──────────────────────────────────
class _SkeletonGrid extends StatefulWidget {
  const _SkeletonGrid();
  @override
  State<_SkeletonGrid> createState() => _SkeletonGridState();
}

class _SkeletonGridState extends State<_SkeletonGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat(reverse: true);
  late final Animation<double> _anim =
      Tween(begin: 0.4, end: 1.0).animate(_ctrl);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(32, 24, 16, 24),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 320,
            childAspectRatio: 0.85,
            crossAxisSpacing: 24,
            mainAxisSpacing: 32),
        itemCount: 6,
        itemBuilder: (context, i) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                    decoration: BoxDecoration(
                        color: AppColors.gray900,
                        borderRadius: BorderRadius.circular(16)))),
            const SizedBox(height: 12),
            Container(
                width: 140,
                height: 16,
                decoration: BoxDecoration(
                    color: AppColors.gray900,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 8),
            Container(
                width: 80,
                height: 14,
                decoration: BoxDecoration(
                    color: AppColors.gray900,
                    borderRadius: BorderRadius.circular(4))),
          ],
        ),
      ),
    );
  }
}

class _SkeletonMap extends StatefulWidget {
  const _SkeletonMap();
  @override
  State<_SkeletonMap> createState() => _SkeletonMapState();
}

class _SkeletonMapState extends State<_SkeletonMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat(reverse: true);
  late final Animation<double> _anim =
      Tween(begin: 0.4, end: 1.0).animate(_ctrl);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF3F4F6),
      child: Center(
        child: FadeTransition(
          opacity: _anim,
          child:
              const Icon(Icons.map_rounded, size: 80, color: Color(0xFFD1D5DB)),
        ),
      ),
    );
  }
}

// ── Reused Original UI Widgets (Unchanged functionality) ───────────────────
// _NavigationStatusCard, _PricePin, _PinTailPainter, _SearchBar, _SearchAreaPill, _PropertyPreviewCard
class _NavigationStatusCard extends StatelessWidget {
  final LatLng origin;
  final LatLng destination;
  final double progress;
  const _NavigationStatusCard(
      {required this.origin,
      required this.destination,
      required this.progress});

  @override
  Widget build(BuildContext context) {
    final estimatedMinutes = (18 - (progress * 6)).round();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 26,
                offset: const Offset(0, 12))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Live Navigation',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'From: ${origin.latitude.toStringAsFixed(3)}, ${origin.longitude.toStringAsFixed(3)}',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF6B7280))),
                    const SizedBox(height: 4),
                    Text(
                        'To: ${destination.latitude.toStringAsFixed(3)}, ${destination.longitude.toStringAsFixed(3)}',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16)),
                  child: Text('$estimatedMinutes min',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800))),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                  value: progress,
                  color: AppColors.primary,
                  backgroundColor: const Color(0xFFF3F4F6),
                  minHeight: 8)),
        ],
      ),
    );
  }
}

class _PricePin extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PricePin({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gray900 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.gray900,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  final String text;
  final ValueChanged<String>? onSubmitted;
  const _SearchBar({required this.text, this.onSubmitted});
  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.text);
  }

  @override
  void didUpdateWidget(covariant _SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && widget.text != _ctrl.text) {
      _ctrl.text = widget.text;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: AppColors.gray100),
          boxShadow: AppShadows.button),
      padding: const EdgeInsets.only(left: 20, right: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Find properties',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray900,
                      height: 1.3),
                ),
                TextField(
                  controller: _ctrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: widget.onSubmitted,
                  cursorColor: AppColors.gray900,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    hintText: 'By area or property name',
                    hintStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.gray400),
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gray900,
                      decorationThickness: 0),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: AppColors.gray900,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Search properties',
              onPressed: widget.onSubmitted == null
                  ? null
                  : () => widget.onSubmitted!(_ctrl.text),
              icon: const Icon(Icons.search_rounded,
                  size: 20, color: Colors.white),
              constraints: const BoxConstraints.tightFor(width: 46, height: 46),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchAreaPill extends StatefulWidget {
  @override
  State<_SearchAreaPill> createState() => _SearchAreaPillState();
}

class _SearchAreaPillState extends State<_SearchAreaPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200));
  late final Animation<double> _scale = Tween(begin: 1.0, end: 0.95)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
              color: const Color(0xE6111827),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 6))
              ]),
          child: const Text('Search this area',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ),
      ),
    );
  }
}

class _PropertyPreviewCard extends StatefulWidget {
  final Property property;
  final VoidCallback onDismiss;
  final VoidCallback onSelect;
  const _PropertyPreviewCard(
      {required this.property,
      required this.onDismiss,
      required this.onSelect});
  @override
  State<_PropertyPreviewCard> createState() => _PropertyPreviewCardState();
}

class _PropertyPreviewCardState extends State<_PropertyPreviewCard>
    with SingleTickerProviderStateMixin {
  String? _completedBookingId;
  bool _canReview = false;
  bool _hasReviewed = false;

  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380));
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  @override
  void initState() {
    super.initState();
    _ctrl.forward();
    _loadReviewEligibility();
  }

  Future<void> _loadReviewEligibility() async {
    if (AppSession.isGuest) return;

    try {
      final eligibility = await RemoteDatabaseRepository()
          .getReviewEligibility(widget.property.id);
      if (!mounted) return;
      setState(() {
        _completedBookingId = eligibility['bookingId']?.toString();
        _canReview = eligibility['canReview'] == true;
        _hasReviewed = eligibility['reviewExists'] == true;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onSelect,
            child: Container(
              margin: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 30,
                        offset: const Offset(0, 8))
                  ]),
              child: Row(
                children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: buildPropertyImage(widget.property.image,
                          width: 80, height: 80, fit: BoxFit.cover)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.property.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppColors.gray900)),
                        const SizedBox(height: 3),
                        Text(widget.property.location,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.gray500)),
                        const SizedBox(height: 6),
                        if (_completedBookingId?.isNotEmpty == true) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  '/reviews',
                                  arguments: {
                                    'propertyId': widget.property.id,
                                    'propertyName': widget.property.name,
                                    'bookingId': _completedBookingId,
                                    'averageRating':
                                        widget.property.rating.toDouble(),
                                    'reviewCount': widget.property.reviews,
                                    'canReview': _canReview,
                                    'hasReviewed': _hasReviewed,
                                  },
                                ),
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        size: 14, color: Color(0xFFFBBF24)),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${widget.property.rating}  ·  ${widget.property.reviews} reviews',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.gray600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  '/location',
                                  arguments: widget.property,
                                ),
                                icon: const Icon(Icons.location_on_outlined,
                                    size: 14),
                                label: const Text('View location'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      GestureDetector(
                          onTap: widget.onDismiss,
                          child: Container(
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close_rounded,
                                  size: 18, color: AppColors.gray400))),
                      const SizedBox(height: 14),
                      Text('Ksh. ${widget.property.price.toInt()}',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
