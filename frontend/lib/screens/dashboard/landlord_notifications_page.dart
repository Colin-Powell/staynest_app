import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/widgets/property_image.dart';

class LandlordNotificationsPage extends StatefulWidget {
  const LandlordNotificationsPage({super.key});

  static Route route() {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) =>
          FadeTransition(opacity: animation, child: const LandlordNotificationsPage()),
    );
  }

  @override
  State<LandlordNotificationsPage> createState() => _LandlordNotificationsPageState();
}

class _LandlordNotificationsPageState extends State<LandlordNotificationsPage> {
  // Design Tokens
  static const Color primaryGreen = Color(0xFF059669);
  static const Color textDark = Color(0xFF111827);
  static const Color textLight = Color(0xFF6B7280);
  final TextEditingController _searchController = TextEditingController();

  // Notification Data mapping the PDF
  final List<Map<String, dynamic>> _notifications = [
    {
      'title': 'Booking Confirmed',
      'subtitle': 'Your booking for 11 Green Bank is confirmed.',
      'time': '2m',
      'icon': PhosphorIcons.check(PhosphorIconsStyle.bold),
      'iconBg': const Color(0xFFD1FAE5),
      'iconColor': primaryGreen,
      'isAvatar': false,
    },
    {
      'title': 'New Message',
      'subtitle': 'John Kamau sent you a message.',
      'time': '10m',
      'icon': PhosphorIcons.chatCenteredText(PhosphorIconsStyle.fill),
      'iconBg': const Color(0xFFDBEAFE),
      'iconColor': const Color(0xFF3B82F6),
      'isAvatar': false,
    },
    {
      'title': 'GreenHomes Ltd.',
      'subtitle': 'New Message',
      'time': '9:15 AM',
      'icon': PhosphorIcons.houseLine(PhosphorIconsStyle.fill),
      'iconBg': const Color(0xFFE8F6EF),
      'iconColor': primaryGreen,
      'isAvatar': false,
    },
    {
      'title': 'Price Drop',
      'subtitle': 'Sunset Apartment price dropped by \$100.',
      'time': 'Yesterday',
      'icon': PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
      'iconBg': const Color(0xFFFEE2E2),
      'iconColor': const Color(0xFFEF4444),
      'isAvatar': false,
    },
    {
      'title': 'New Property',
      'subtitle': '5 new properties available near you.',
      'time': 'Yesterday',
      'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=256&h=256&q=80',
      'isAvatar': true,
      'unreadCount': 2,
    },
    {
      'title': 'Verification Update',
      'subtitle': 'Your profile has been verified.',
      'time': 'Mon',
      'icon': PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
      'iconBg': const Color(0xFFD1FAE5),
      'iconColor': primaryGreen,
      'isAvatar': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Suble Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [const Color(0xFFE8F6EF).withOpacity(0.4), Colors.white],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildSearchBar(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      return _NotificationTile(item: _notifications[index]);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: textDark, size: 30),
          ),
          Text(
            'Notifications',
            style: GoogleFonts.poppins(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const Icon(Icons.more_vert, color: textDark, size: 30),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB).withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Notifications',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 17,
                  color: const Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: const Icon(Icons.search, color: textDark, size: 26),
                suffixIcon: Container(
                  margin: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(color: textDark, shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _NotificationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLeading(),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item['title'],
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                    Text(
                      item['time'],
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item['subtitle'],
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          if (item['unreadCount'] != null) ...[
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.only(top: 25),
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFE5E7EB),
                shape: BoxShape.circle,
              ),
              child: Text(
                item['unreadCount'].toString(),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildLeading() {
    if (item['isAvatar']) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipOval(
          child: buildPropertyImage(
            item['avatar'],
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: item['iconBg'],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          item['icon'],
          color: item['iconColor'],
          size: 30,
        ),
      ),
    );
  }
}