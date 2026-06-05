import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:property_app/app_theme.dart';

class NearbyServicesView extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onViewMap;

  const NearbyServicesView({
    super.key,
    required this.onClose,
    this.onViewMap,
  });

  @override
  State<NearbyServicesView> createState() => _NearbyServicesViewState();
}

class _NearbyServicesViewState extends State<NearbyServicesView> {
  String _selectedCategory = 'Universities';

  static const LatLng _center = LatLng(-1.2921, 36.8219);

  static const _categories = [
    {'id': 'Universities', 'icon': Icons.school_rounded},
    {'id': 'Hospitals', 'icon': Icons.local_hospital_rounded},
    {'id': 'Supermarkets', 'icon': Icons.shopping_cart_rounded},
    {'id': 'Bus Stops', 'icon': Icons.directions_bus_rounded},
  ];

  static const _places = [
    {'name': 'Yaya Centre', 'dist': '1.2 km', 'icon': Icons.store_rounded},
    {
      'name': 'Aga Khan Hospital',
      'dist': '3.4 km',
      'icon': Icons.local_hospital_rounded
    },
    {
      'name': 'Carrefour Junction',
      'dist': '1.6 km',
      'icon': Icons.shopping_cart_rounded
    },
    {'name': 'Prestige Plaza', 'dist': '1.5 km', 'icon': Icons.store_rounded},
    {
      'name': 'Kilimani Police Station',
      'dist': '1.3 km',
      'icon': Icons.local_police_rounded
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          Column(
            children: [
              // Header
              Container(
                color: const Color(0xFFF8F9FA),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 24,
                  right: 24,
                  bottom: 16,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFF3F4F6),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.chevron_left,
                          size: 20,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Nearby Services',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              // Category pills
              SizedBox(
                height: 100,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final item = _categories[index];
                    final isActive = item['id'] == _selectedCategory;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedCategory = item['id'] as String;
                      }),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: isActive ? 1.0 : 0.4,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color:
                                    isActive ? AppTheme.primary : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isActive
                                      ? AppTheme.primary
                                      : const Color(0xFFF3F4F6),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isActive
                                        ? AppTheme.primary.withOpacity(0.3)
                                        : Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                item['icon'] as IconData,
                                size: 20,
                                color: isActive
                                    ? Colors.white
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['id'] as String,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Map + list
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 112),
                  child: Column(
                    children: [
                      // Map
                      SizedBox(
                        height: 250,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFFF9FAFB),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x14000000),
                                  blurRadius: 18,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: FlutterMap(
                              options: const MapOptions(
                                initialCenter: _center,
                                initialZoom: 13,
                                interactionOptions: InteractionOptions(
                                  flags: InteractiveFlag.pinchZoom |
                                      InteractiveFlag.drag,
                                ),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
                                  subdomains: const ['a', 'b', 'c', 'd'],
                                  userAgentPackageName:
                                      'com.example.property_app',
                                ),
                                const MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _center,
                                      width: 42,
                                      height: 42,
                                      child: Icon(
                                        Icons.location_on_rounded,
                                        color: Colors.red,
                                        size: 36,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // White card panel
                      Transform.translate(
                        offset: const Offset(0, -16),
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(32),
                              topRight: Radius.circular(32),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x0D000000),
                                blurRadius: 30,
                                offset: Offset(0, -8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nearby Places',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ..._places.map(
                                (place) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFF3F4F6),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              place['icon'] as IconData,
                                              size: 20,
                                              color: const Color(0xFF9CA3AF),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              place['name'] as String,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: Color(0xFF374151),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          place['dist'] as String,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Color(0xFF6B7280),
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
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // View on Map CTA
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 20,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: widget.onViewMap,
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'View on Map',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
