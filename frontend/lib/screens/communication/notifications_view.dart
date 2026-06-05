// lib/screens/notifications_view.dart
import 'package:flutter/material.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView>
    with TickerProviderStateMixin {
  late final AnimationController _pageCtrl;
  late final Animation<double> _pageFade;
  late final Animation<Offset> _pageSlide;

  late final AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    // Screen entrance animation
    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pageFade = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));

    // Staggered list items animation
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pageCtrl.forward().then((_) => _staggerCtrl.forward());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  // Staggered animation helper for list items
  Widget _buildStaggered({required int index, required Widget child}) {
    final start = (index * 0.1).clamp(0.0, 1.0);
    final end = (start + 0.4).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _staggerCtrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _pageFade,
      child: SlideTransition(
        position: _pageSlide,
        child: Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                _buildSearchBar(),
                Expanded(
                  child: ScrollConfiguration(
                    behavior: const AppScrollBehavior(),
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        24,
                        20,
                        MediaQuery.of(context).padding.bottom + 24,
                      ),
                      physics: const BouncingScrollPhysics(
                        decelerationRate: ScrollDecelerationRate.fast,
                      ),
                      itemCount: _mockNotifications.length,
                      separatorBuilder: (context, index) => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(
                          color: Colors.transparent,
                          height: 1,
                        ),
                      ),
                      itemBuilder: (context, index) {
                        return _buildStaggered(
                          index: index,
                          child: _NotificationItemTile(
                            item: _mockNotifications[index],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.only(right: 16, top: 4, bottom: 4),
              child: Icon(
                Icons.arrow_back,
                size: 28,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Notifications',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {},
            behavior: HitTestBehavior.opaque,
            child: const Icon(
              Icons.more_vert,
              size: 28,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: TextField(
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF111827),
        ),
        decoration: InputDecoration(
          hintText: 'Search Notifications',
          hintStyle: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontWeight: FontWeight.w600,
            fontSize: 15.5,
          ),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF111827), size: 22),
          suffixIcon: const Icon(Icons.cancel_outlined, color: Color(0xFF111827), size: 20),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color(0xFF111827), width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _NotificationItemTile extends StatelessWidget {
  final NotificationItem item;

  const _NotificationItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Leading Icon / Avatar
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: item.iconColor,
            image: item.imageAsset != null
                ? DecorationImage(
                    image: AssetImage(item.imageAsset!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: item.icon != null
              ? Icon(
                  item.icon,
                  color: Colors.white,
                  size: 26,
                )
              : null,
        ),
        const SizedBox(width: 16),
        // Texts Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2), // Visual alignment
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.time,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Custom Smooth Scroll Behavior
class AppScrollBehavior extends ScrollBehavior {
  const AppScrollBehavior();
  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(
          decelerationRate: ScrollDecelerationRate.fast);
}

// ==================== MOCK DATA ====================

class NotificationItem {
  final String title;
  final String subtitle;
  final String time;
  final IconData? icon;
  final Color? iconColor;
  final String? imageAsset;

  const NotificationItem({
    required this.title,
    required this.subtitle,
    required this.time,
    this.icon,
    this.iconColor,
    this.imageAsset,
  });
}

const List<NotificationItem> _mockNotifications = [
  NotificationItem(
    title: 'Booking Confirmed',
    subtitle: 'Your booking for 11 Green Bank is confirmed.',
    time: '2m',
    icon: Icons.check,
    iconColor: Color(0xFF22C55E),
  ),
  NotificationItem(
    title: 'New Message',
    subtitle: 'John Kamau sent you a message.',
    time: '10m',
    iconColor: Color(0xFF3B82F6), // Blue circle matching PDF
  ),
  NotificationItem(
    title: 'GreenHomes Ltd.',
    subtitle: 'New Message',
    time: '9:15 AM',
    icon: Icons.home_rounded,
    iconColor: Color(0xFF22C55E),
  ),
  NotificationItem(
    title: 'Price Drop',
    subtitle: 'Sunset Apartment price dropped by \$100.',
    time: 'Yesterday',
    icon: Icons.priority_high_rounded,
    iconColor: Color(0xFFEF4444), // Red circle matching PDF
  ),
  NotificationItem(
    title: 'New Property',
    subtitle: '5 new properties available near you.',
    time: 'Yesterday',
    imageAsset: 'assets/images/hero.jpg', 
    iconColor: Color(0xFFE5E7EB),
  ),
  NotificationItem(
    title: 'Verification Update',
    subtitle: 'Your profile has been verified.',
    time: 'Mon',
    icon: Icons.check,
    iconColor: Color(0xFF22C55E),
  ),
];