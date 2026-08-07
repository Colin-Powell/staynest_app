// lib/screens/dashboard/landlord_overview_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/widgets/skeleton_property_card.dart';
import 'package:property_app/screens/dashboard/landlord_notifications_page.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/services/properties_api.dart';
import 'package:property_app/utils/api_result.dart';
import 'package:property_app/utils/property_mapper.dart';
import 'analytics_service.dart';

import 'dashboard_widgets.dart';
import 'landlord_analytics_page.dart';

class LandlordOverviewPage extends StatefulWidget {
  const LandlordOverviewPage({super.key});

  @override
  State<LandlordOverviewPage> createState() => _LandlordOverviewPageState();
}

class _LandlordOverviewPageState extends State<LandlordOverviewPage> {
  static const Color textDark = Color(0xFF111827);
  static const Color textLight = Color(0xFF4B5563);
  static const Color textGreen = Color(0xFF059669);

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _properties = [];
  Map<String, String> _metrics = {
    'totalViews': '0',
    'viewsGrowth': '0%',
    'totalBookings': '0',
    'occupancyRate': '0%',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final results = await Future.wait([
        PropertiesApi.getLandlordProperties(),
        AnalyticsService.getLandlordOverview('This Week'),
      ]);
      
      setState(() {
        _properties = results[0] as List<Map<String, dynamic>>;
        final analyticsData = results[1] as Map<String, dynamic>?;

        if (analyticsData != null) {
          // Calculate occupancy based on properties marked 'rented' as requested
          final rentedCount = _properties.where((p) => 
              p['status']?.toString().toLowerCase() == 'rented').length;
          final occRate = _properties.isEmpty ? 0 : (rentedCount / _properties.length * 100);

          _metrics = {
            'totalViews': analyticsData['overview']?['totalViews']?.toString() ?? '0',
            'viewsGrowth': analyticsData['overview']?['growth']?.toString() ?? '0%',
            'totalBookings': analyticsData['metrics']?['totalBookings']?.toString() ?? '0',
            'occupancyRate': '${occRate.toStringAsFixed(0)}%',
          };
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = ApiResult.mapError(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && false) {
      return const Center(
        child: CircularProgressIndicator(color: textGreen),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.warning(PhosphorIconsStyle.fill),
                size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: textDark),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        // Padding prevents overlap with the glass nav bar at the bottom
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER (GREETINGS & BELL) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good Morning,',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textLight,
                      ),
                    ),
                    Text(
                      'Landlord 👋',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LandlordNotificationsPage(),
                      ),
                    );
                  },
                  child: GlassContainer(
                    padding: const EdgeInsets.all(10),
                    borderRadius: BorderRadius.circular(50),
                    child: Stack(
                      children: [
                        Icon(PhosphorIcons.bell(), color: textDark, size: 24),
                        Positioned(
                          top: 0,
                          right: 2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444), // Red notification dot
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // --- INTRO TEXT ---
            Text(
              'Here\'s what\'s happening\nwith your properties',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textDark,
                height: 1.3,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),

            // --- STATS GRID ---
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.25,
              children: [
                _buildStatCard('Properties', _properties.length.toString(), '+0', true),
                _buildStatCard('Bookings', _metrics['totalBookings']!, '+0', true),
                _buildStatCard('Views', _metrics['totalViews']!, _metrics['viewsGrowth']!, !_metrics['viewsGrowth']!.startsWith('-')),
                _buildStatCard('Occupancy', _metrics['occupancyRate']!, '+0', true),
              ],
            ),
            const SizedBox(height: 16),

            // --- VIEW ANALYTICS BUTTON (Clean & Minimal) ---
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LandlordAnalyticsPage(),
                  ),
                );
              },
              child: GlassContainer(
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'View Analytics',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textDark, // Clean text color matching theme
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // --- RECENT PROPERTIES ---
            Text(
              _isLoading ? 'Your Properties' : (_properties.isEmpty ? 'No Properties Yet' : 'Your Properties'),
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textDark,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 2,
                itemBuilder: (context, index) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: SkeletonPropertyCard(width: double.infinity, margin: EdgeInsets.zero),
                  );
                },
              )
            else if (_properties.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Column(
                    children: [
                      Icon(PhosphorIcons.house(PhosphorIconsStyle.regular),
                          size: 48, color: const Color(0xFFD1D5DB)),
                      const SizedBox(height: 12),
                      Text(
                        'No properties listed yet',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._properties.take(3).map((property) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: _buildPropertyCard(property),
                );
              }),
            const SizedBox(height: 16),

            // --- VIEW ALL PROPERTIES BUTTON ---
            GlassContainer(
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'View All Properties',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, String change, bool isPositive) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textLight,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: textDark,
                  height: 1.0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  change,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isPositive ? textGreen : textDark,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> property) {
    final imageUrl = mapApiProperty(property).image;
    final title = property['title'] as String? ?? 'Untitled';
    final city = property['city'] as String? ?? 'Unknown';
    final priceValue = property['price'];
    final price = priceValue is String 
        ? double.tryParse(priceValue) ?? 0 
        : (priceValue as num? ?? 0);
    final rating = (double.tryParse(property['average_rating']?.toString() ?? '0') ?? 0.0).toDouble();
    final reviews = int.tryParse(property['review_count']?.toString() ?? '0') ?? 0;

    return GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: buildPropertyImage(
              imageUrl,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorPlaceholder: Container(
                width: 64,
                height: 64,
                color: const Color(0xFFE5E7EB),
                child: Icon(
                  PhosphorIcons.image(PhosphorIconsStyle.regular),
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  city,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: textLight,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'KES ${price.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textGreen,
                      ),
                    ),
                    const Spacer(),
                    if (reviews > 0) ...[
                      const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($reviews)',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: textLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF9CA3AF),
            size: 24,
          ),
        ],
      ),
    );
  }
}
