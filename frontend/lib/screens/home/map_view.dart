// lib/screens/map_view.dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:property_app/models/property.dart';
import 'package:property_app/theme.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/widgets/shared.dart';
import 'package:property_app/services/routing_service.dart';
import 'package:property_app/services/property_service.dart';
import 'package:property_app/utils/category_utils.dart';

class MapViewScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onFilter;
  final void Function(String id)? onSelectProperty;
  final bool isNavigation;
  final LatLng? navOrigin;
  final LatLng? navDestination;

  const MapViewScreen({
    super.key,
    required this.onBack,
    required this.onFilter,
    this.onSelectProperty,
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
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  late final Animation<Offset> _headerSlide = Tween<Offset>(
    begin: const Offset(0, -1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
  late final Animation<double> _headerFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut));
  late final Animation<double> _pillFade = CurvedAnimation(
    parent: _entryCtrl,
    curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
  );
  late final Animation<double> _pillScale =
      Tween<double>(begin: 0.85, end: 1.0).animate(
    CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutBack)),
  );

  // ── Pin float animation ───────────────────────────────────────
  late final AnimationController _floatCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  // ── Navigation animation ──────────────────────────────────────
  late final LatLng _routeOrigin;
  late final LatLng _routeDestination;
  late List<LatLng> _navRoute;
  late final AnimationController _navProgressCtrl;
  late final Animation<double> _navProgress;

  // ── Selected pin ─────────────────────────────────────────────
  String? _selectedId;
  List<Property> _properties = [];

  @override
  void initState() {
    super.initState();
    _routeOrigin = widget.navOrigin ?? const LatLng(40.7128, -74.0060);
    _routeDestination =
        widget.navDestination ?? const LatLng(40.7208, -74.0010);
    // Default simple route until a real route is fetched
    _navRoute = [_routeOrigin, _routeDestination];

    _navProgressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
    _navProgress = CurvedAnimation(
      parent: _navProgressCtrl,
      curve: Curves.easeInOut,
    );

    _loadProperties();

    if (widget.isNavigation) {
      _navProgressCtrl.repeat(reverse: false);
      // Fetch a real route asynchronously
      fetchAndSetRoute();
    }

    // Stagger entry
    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted) _entryCtrl.forward();
    });
  }

  Future<void> _loadProperties() async {
    try {
      final loaded = await PropertyService.instance.fetchProperties();
      if (mounted) setState(() => _properties = loaded);
    } catch (error) {
      debugPrint('Property map fetch error: $error');
    }
  }

  Future<void> fetchAndSetRoute() async {
    try {
      // lazy import to avoid top-level dependency in this file
      final route = await fetchRouteOsrm(_routeOrigin, _routeDestination);
      if (mounted && route.isNotEmpty) {
        setState(() {
          _navRoute = route;
        });
      }
    } catch (e) {
      // ignore and keep fallback route
      debugPrint('Route fetch error: $e');
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _floatCtrl.dispose();
    _navProgressCtrl.dispose();
    super.dispose();
  }

  LatLng _lerpLatLng(LatLng a, LatLng b, double t) => LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );

  LatLng get _animatedNavigationPosition {
    if (!widget.isNavigation) {
      return _routeOrigin;
    }

    final t = _navProgress.value.clamp(0.0, 1.0);
    final step = t * (_navRoute.length - 1);
    final index = step.floor().clamp(0, _navRoute.length - 2);
    final localT = step - index;
    return _lerpLatLng(_navRoute[index], _navRoute[index + 1], localT);
  }

  List<Marker> _buildNavigationMarkers() {
    return [
      Marker(
        point: _routeOrigin,
        width: 32,
        height: 32,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: Center(
            child: Icon(Icons.circle, color: AppColors.primary, size: 12),
          ),
        ),
      ),
      Marker(
        point: _routeDestination,
        width: 36,
        height: 36,
        child:
            Icon(Icons.location_on_rounded, size: 36, color: AppColors.primary),
      ),
      Marker(
        point: _animatedNavigationPosition,
        width: 42,
        height: 42,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Center(
            child:
                Icon(Icons.navigation_rounded, size: 20, color: Colors.white),
          ),
        ),
      ),
    ];
  }

  List<Marker> _buildMarkers() {
    return _properties.map((prop) {
      final isSelected = _selectedId == prop.id;
      return Marker(
        point: LatLng(prop.lat, prop.lng),
        width: 90,
        height: 56,
        child: _PricePin(
          label: formatPropertyPrice(prop.price),
          isSelected: isSelected,
          floatController: _floatCtrl,
          phaseOffset: _properties.indexOf(prop) * 0.33,
          onTap: () {
            setState(() => _selectedId = prop.id);
            widget.onSelectProperty?.call(prop.id);
          },
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final mapCenter =
        widget.isNavigation ? _routeOrigin : const LatLng(40.7128, -74.0060);
    final markers =
        widget.isNavigation ? _buildNavigationMarkers() : _buildMarkers();

    return Scaffold(
      backgroundColor: AppColors.mapBg,
      body: Stack(
        children: [
          // ── Real Map ────────────────────────────────────────
          FlutterMap(
            options: MapOptions(
              initialCenter: mapCenter,
              initialZoom: 11.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.rashoti.staynest',
              ),
              if (widget.isNavigation)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _navRoute,
                      color: AppColors.primary,
                      strokeWidth: 5,
                      borderColor: Colors.white,
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
              MarkerLayer(markers: markers),
            ],
          ),

          // ── Header overlay ──────────────────────────────────
          Positioned(
            top: topPad + 12,
            left: 16,
            right: 16,
            child: SlideTransition(
              position: _headerSlide,
              child: FadeTransition(
                opacity: _headerFade,
                child: Row(
                  children: [
                    // Back
                    CircleIconButton(
                      onTap: widget.onBack,
                      child: const Icon(Icons.chevron_left_rounded,
                          size: 26, color: AppColors.gray900),
                    ),
                    const SizedBox(width: 10),
                    // Search pill
                    Expanded(
                      child: _SearchBar(),
                    ),
                    const SizedBox(width: 10),
                    // Filter
                    CircleIconButton(
                      onTap: widget.onFilter,
                      child: const Icon(Icons.tune_rounded,
                          size: 21, color: AppColors.gray700),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── "Search this area" pill ─────────────────────────
          Positioned(
            top: topPad + 84,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _pillFade,
              child: ScaleTransition(
                scale: _pillScale,
                child: Center(child: _SearchAreaPill()),
              ),
            ),
          ),

          if (widget.isNavigation)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _NavigationStatusCard(
                origin: _routeOrigin,
                destination: _routeDestination,
                progress: _navProgress.value,
              ),
            ),

          // ── Property preview card (when pin selected) ───────
          if (!widget.isNavigation && _selectedId != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _PropertyPreviewCard(
                property: _properties.firstWhere((p) => p.id == _selectedId),
                onDismiss: () => setState(() => _selectedId = null),
                onSelect: () => widget.onSelectProperty?.call(_selectedId!),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavigationStatusCard extends StatelessWidget {
  final LatLng origin;
  final LatLng destination;
  final double progress;

  const _NavigationStatusCard({
    required this.origin,
    required this.destination,
    required this.progress,
  });

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
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Live Navigation',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
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
                          fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'To: ${destination.latitude.toStringAsFixed(3)}, ${destination.longitude.toStringAsFixed(3)}',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$estimatedMinutes min',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              color: AppColors.primary,
              backgroundColor: const Color(0xFFF3F4F6),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Price Pin ────────────────────────────────────────────────────────────────
class _PricePin extends StatefulWidget {
  final String label;
  final bool isSelected;
  final AnimationController floatController;
  final double phaseOffset;
  final VoidCallback onTap;

  const _PricePin({
    required this.label,
    required this.isSelected,
    required this.floatController,
    required this.phaseOffset,
    required this.onTap,
  });

  @override
  State<_PricePin> createState() => _PricePinState();
}

class _PricePinState extends State<_PricePin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _pressScale =
      Tween(begin: 1.0, end: 0.88).animate(
    CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.floatController, _pressCtrl]),
      builder: (context, _) {
        // Smooth sinusoidal float, each pin offset slightly
        final t = (widget.floatController.value + widget.phaseOffset) % 1.0;
        final floatY = -3.5 * (0.5 + 0.5 * (1 - (2 * t - 1).abs() * 2).abs());

        return GestureDetector(
          onTapDown: (_) => _pressCtrl.forward(),
          onTapUp: (_) {
            _pressCtrl.reverse();
            widget.onTap();
          },
          onTapCancel: () => _pressCtrl.reverse(),
          child: ScaleTransition(
            scale: _pressScale,
            child: Transform.translate(
              offset: Offset(0, floatY),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? AppColors.gray900
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isSelected
                                  ? AppColors.gray900
                                  : AppColors.primary)
                              .withOpacity(0.32),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  // CSS triangle tail
                  CustomPaint(
                    size: const Size(12, 7),
                    painter: _PinTailPainter(
                      color: widget.isSelected
                          ? AppColors.gray900
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      ui.Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_PinTailPainter old) => old.color != color;
}

// ── Search Bar (read-only pill) ──────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gray100),
        boxShadow: AppShadows.button,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: const Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: AppColors.gray400),
          SizedBox(width: 8),
          Text(
            'New York, USA',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.gray900,
            ),
          ),
        ],
      ),
    );
  }
}

// ── "Search this area" pill button ───────────────────────────────────────────
class _SearchAreaPill extends StatefulWidget {
  @override
  State<_SearchAreaPill> createState() => _SearchAreaPillState();
}

class _SearchAreaPillState extends State<_SearchAreaPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _scale = Tween(begin: 1.0, end: 0.95).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
  );

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
            color: const Color(0xE6111827), // gray-900 / 90%
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Text(
            'Search this area',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Property Preview Card (selected state) ───────────────────────────────────
class _PropertyPreviewCard extends StatefulWidget {
  final Property property;
  final VoidCallback onDismiss;
  final VoidCallback onSelect;

  const _PropertyPreviewCard({
    required this.property,
    required this.onDismiss,
    required this.onSelect,
  });

  @override
  State<_PropertyPreviewCard> createState() => _PropertyPreviewCardState();
}

class _PropertyPreviewCardState extends State<_PropertyPreviewCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: buildPropertyImage(
                  p.image,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.gray900,
                        )),
                    const SizedBox(height: 3),
                    Text(p.location,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray500,
                        )),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/reviews'),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: Color(0xFFFBBF24)),
                          const SizedBox(width: 3),
                          Text(
                            '${p.rating}  ·  ${p.reviews} reviews',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.gray600,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                          size: 18, color: AppColors.gray400),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    formatPropertyPrice(p.price),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
