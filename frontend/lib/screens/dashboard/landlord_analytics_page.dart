// lib/screens/dashboard/landlord_analytics_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/widgets/property_image.dart';

import 'dashboard_widgets.dart';

class LandlordAnalyticsPage extends StatefulWidget {
  const LandlordAnalyticsPage({super.key});

  @override
  State<LandlordAnalyticsPage> createState() => _LandlordAnalyticsPageState();
}

class _LandlordAnalyticsPageState extends State<LandlordAnalyticsPage> {
  String _selectedFilter = 'This Week';
  final List<String> _filters = ['This Week', 'Last 28 Days'];

  // Mock data for the chart based on selection
  final List<double> _weekData = [120, 150, 180, 140, 210, 250, 310];
  final List<double> _monthData = [100, 120, 110, 160, 200, 180, 260, 290, 340, 310, 390, 420]; 

  List<double> get _chartData => _selectedFilter == 'This Week' ? _weekData : _monthData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Gradient matching the portal
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF7FDF9), Color(0xFFE8F6EF), Color(0xFFD4EFE1)],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Custom AppBar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.arrow_back, color: Color(0xFF111827), size: 28),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Analytics',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF111827),
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    children: [
                      // --- HEADER & FILTER ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Profile Views',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          GlassContainer(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            borderRadius: BorderRadius.circular(12),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedFilter,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF111827),
                                ),
                                dropdownColor: Colors.white,
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() => _selectedFilter = newValue);
                                  }
                                },
                                items: _filters.map<DropdownMenuItem<String>>((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // --- CUSTOM LINE CHART USING GLASS CONTAINER ---
                      GlassContainer(
                        padding: const EdgeInsets.all(24),
                        borderRadius: BorderRadius.circular(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFilter == 'This Week' ? '1,360' : '4,820',
                              style: GoogleFonts.poppins(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF111827),
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(PhosphorIcons.trendUp(PhosphorIconsStyle.bold), color: const Color(0xFF059669), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '+14.5% vs previous period',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            // The Line Graph
                            SizedBox(
                              height: 160,
                              width: double.infinity,
                              child: CustomPaint(
                                painter: _SmoothLineChartPainter(
                                  data: _chartData,
                                  lineColor: const Color(0xFF059669),
                                  gradientColor: const Color(0xFF059669).withOpacity(0.25),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // --- TOP PROPERTIES LIST ---
                      Text(
                        'Top Performing Properties',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildTopPropertyCard(
                        'Modern Apartment',
                        'Kilimani, Nairobi',
                        'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                        '845',
                      ),
                      _buildTopPropertyCard(
                        'Cozy Studio',
                        'Westlands, Nairobi',
                        'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                        '532',
                      ),
                      _buildTopPropertyCard(
                        'Luxury Villa',
                        'Karen, Nairobi',
                        'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                        '410',
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPropertyCard(String name, String location, String image, String views) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        padding: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: buildPropertyImage(
                image,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorPlaceholder: Container(
                  width: 72, height: 72, color: const Color(0xFFE5E7EB),
                  child: Icon(PhosphorIcons.image(), color: const Color(0xFF9CA3AF)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_rounded, size: 16, color: Color(0xFF059669)),
                  const SizedBox(width: 6),
                  Text(
                    views,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF059669),
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
}

// ─── Custom Cubic Bezier Line Chart Painter (Dependency Free) ──────────────
class _SmoothLineChartPainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final Color gradientColor;

  _SmoothLineChartPainter({
    required this.data,
    required this.lineColor,
    required this.gradientColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double maxData = data.reduce((a, b) => a > b ? a : b);
    final double minData = data.reduce((a, b) => a < b ? a : b);
    
    final List<Offset> points = [];
    final double widthStep = size.width / (data.length - 1);
    final double heightRange = maxData - minData == 0 ? 1 : maxData - minData;

    for (int i = 0; i < data.length; i++) {
      final double x = i * widthStep;
      // Invert Y axis because canvas draws from top to bottom
      final double normalizedY = (data[i] - minData) / heightRange;
      final double y = size.height - (normalizedY * (size.height * 0.8)) - (size.height * 0.1); 
      points.add(Offset(x, y));
    }

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    // Draw Smooth Cubic Bezier Curves
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);
      path.cubicTo(
        controlPoint1.dx, controlPoint1.dy,
        controlPoint2.dx, controlPoint2.dy,
        p2.dx, p2.dy,
      );
    }

    // 1. Draw the gradient fill under the line
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [gradientColor, gradientColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // 2. Draw the actual line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // 3. Draw dots on the points
    final dotPaint = Paint()..color = Colors.white;
    final dotBorderPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (var point in points) {
      canvas.drawCircle(point, 4.5, dotPaint);
      canvas.drawCircle(point, 4.5, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}