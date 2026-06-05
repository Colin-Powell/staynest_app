// lib/screens/how_it_works_view.dart
import 'package:flutter/material.dart';
import 'package:property_app/app_theme.dart';

class HowItWorksView extends StatefulWidget {
  final String title;
  final String subtitle;
  final String details;

  const HowItWorksView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.details,
  });

  // 🚀 FIX: Use this in main.dart to securely cast the return type to Widget
  static Widget buildRoute(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    return HowItWorksView.fromArguments(args);
  }

  factory HowItWorksView.fromArguments(Object? arguments) {
    final args = arguments as Map<String, dynamic>?;
    final title = args?['title'] as String? ?? 'How it Works';
    final subtitle = args?['subtitle'] as String? ??
        'A clean overview of the app flow and what to wire next.';
    final details = args?['details'] as String? ?? _defaultDetailsFor(title);

    return HowItWorksView(
      title: title,
      subtitle: subtitle,
      details: details,
    );
  }

  static String _defaultDetailsFor(String title) {
    switch (title) {
      case 'Frequently Asked Questions':
        return 'StayNest helps users discover rental homes, contact landlords, and secure bookings through a modern mobile experience. All FAQ items are placeholder content until the real support backend is connected.';
      case 'Contact Support':
        return 'Use this page to reach our support team, open tickets, or chat about booking and property questions. The current flow is a design placeholder that should connect to real support channels later.';
      case 'Safety Tips':
        return 'StaySafe tips help tenants and landlords feel secure. This section is designed to be enhanced with dynamic safety guidance, policy references, and emergency contact links when the backend is ready.';
      case 'Report a Problem':
        return 'Users can report issues directly from the app, including booking problems, listing inaccuracies, or messaging failures. This placeholder page should be wired to a ticketing service before launch.';
      case 'Terms & Conditions':
        return 'Terms and conditions explain how StayNest operates, what users agree to, and how personal data is handled. Replace this placeholder content with legal text from the product team.';
      case 'Privacy Policy':
        return 'The privacy policy page explains what data is collected, how it is used, and how users can manage privacy settings. It is intentionally clean and ready for the real privacy copy.';
      case 'About StayNest':
      case 'How it Works':
      default:
        return 'This page explains the core app flow: browse properties, view details, book with the landlord, and manage your account. It is a clean summary screen that helps the team understand how the frontend is structured and what needs to be connected to real APIs next.';
    }
  }

  @override
  State<HowItWorksView> createState() => _HowItWorksViewState();
}

class _HowItWorksViewState extends State<HowItWorksView>
    with TickerProviderStateMixin {
  late final AnimationController _pageCtrl;
  late final AnimationController _staggerCtrl;
  late final Animation<double> _pageFade;

  @override
  void initState() {
    super.initState();
    // Screen entrance animation
    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pageFade = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);

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
          begin: const Offset(0, 0.15),
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
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0, // Clean flat look
          centerTitle: true,
          title: Text(
            widget.title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
                decelerationRate: ScrollDecelerationRate.fast),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStaggered(
                  index: 0,
                  child: Text(
                    widget.subtitle,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildStaggered(
                  index: 1,
                  child: const _Section(
                    label: 'What this app does',
                    content:
                        'StayNest helps tenants explore rental listings, save favorites, contact landlords, view landlord profiles, and complete bookings. Landlords can manage listings, review inquiries, and track tenants with the right role path.',
                  ),
                ),
                const SizedBox(height: 24),
                _buildStaggered(
                  index: 2,
                  child: const _Section(
                    label: 'How it is structured',
                    content:
                        'The main shell contains Home, Search, Saved, Messages, and Profile tabs. Property details are shown with overlay panels. Settings and help pages are routed through named routes, while chat and map screens use direct page transitions.',
                  ),
                ),
                const SizedBox(height: 24),
                _buildStaggered(
                  index: 3,
                  child: const _Section(
                    label: 'Current data wiring',
                    content:
                        'Most screens use local mock data from the frontend repository. The map route uses a public OSRM endpoint for route previews, but the booking, referral, and review flows are still stubbed and need backend integration.',
                  ),
                ),
                const SizedBox(height: 24),
                _buildStaggered(
                  index: 4,
                  child: _Section(
                    label: 'What to connect next',
                    content: widget.details,
                  ),
                ),
                const SizedBox(height: 40),
                _buildStaggered(
                  index: 5,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF), // Soft Indigo background
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE0E7FF)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next steps',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF3730A3), // Deep Indigo
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '1. Replace mock repositories with API services.\n\n'
                          '2. Wire authentication and user role paths.\n\n'
                          '3. Connect booking, review, and landlord workflows.\n\n'
                          '4. Add legal pages and support ticketing links.',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF4338CA), // Indigo
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final String content;

  const _Section({required this.label, required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: const TextStyle(
            fontSize: 15,
            height: 1.7,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}