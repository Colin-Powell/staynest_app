import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/session/app_session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const StayNestApp());
}

class StayNestApp extends StatelessWidget {
  const StayNestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StayNest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        scaffoldBackgroundColor:
            const Color(0xFF4A49E4), // Brand Royal Purple/Blue
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashView(),
        '/login': (_) => const _PlaceholderPage(label: 'Login'),
        '/onboarding': (_) => const _PlaceholderPage(label: 'Get Started'),
        '/explore': (_) => const _PlaceholderPage(label: 'Explore'),
      },
    );
  }
}

// ─── Design Tokens ───────────────────────────────────────────────────────────

abstract class _AppColor {
  static const primaryBackground = Color(0xFF4A49E4);
  static const buttonTextPrimary = Color(0xFF4A49E4);
  static const textWhite = Colors.white;
  static const textWhiteSecondary = Color(0xE6FFFFFF);
  static final borderWhite = Colors.white.withValues(alpha: 0.4);
}

// ─── Splash View ─────────────────────────────────────────────────────────────

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateBasedOnSession();
    });
  }

  void _navigateBasedOnSession() {
    if (!mounted) return;

    final isDesktop = MediaQuery.sizeOf(context).width >= 768;

    if (isDesktop &&
        (AppSession.apiToken == null || AppSession.apiToken!.isEmpty)) {
      AppSession.isGuest = true;
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }

    // No stored token — show the splash landing page (do nothing, buttons are shown)
    if (AppSession.apiToken == null || AppSession.apiToken!.isEmpty) {
      return;
    }

    // Token exists but OTP/email not verified yet — go to OTP
    if (!AppSession.isEmailVerified) {
      Navigator.pushReplacementNamed(context, '/otp');
      return;
    }

    // Admin users go to admin dashboard
    if (AppSession.isAdmin) {
      Navigator.pushReplacementNamed(context, '/super_admin');
      return;
    }

    // Landlords: verified → portal, unverified → verification center
    if (AppSession.isLandlord) {
      if (AppSession.currentUserVerified) {
        Navigator.pushReplacementNamed(context, '/portal');
      } else {
        Navigator.pushReplacementNamed(context, '/verification_center');
      }
      return;
    }

    // Tenants go home
    Navigator.pushReplacementNamed(context, '/home');
  }

  // ─── Navigation helpers ─────────────────────
  void _onGetStarted(BuildContext context) =>
      Navigator.pushReplacementNamed(context, '/onboarding');

  void _onLogin(BuildContext context) {
    AppSession.isGuest = false;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _onExploreGuest(BuildContext context) {
    AppSession.isGuest = true;
    Navigator.pushReplacementNamed(context, '/explore');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColor.primaryBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // ── Logo Visual (Circle with Filled House Icon) ────────────────
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(54, 54),
                    painter: _PhosphorHousePainter(
                        color: _AppColor.primaryBackground),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Brand Name ─────────────────────────────────────────────────
              Text(
                'StayNest',
                style: GoogleFonts.poppins(
                  fontSize: 58,
                  fontWeight: FontWeight.w700,
                  color: _AppColor.textWhite,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 28),

              // ── Tagline ────────────────────────────────────────────────────
              Text(
                'Find. Rent. Live',
                style: GoogleFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.w500,
                  color: _AppColor.textWhite,
                ),
              ),

              const SizedBox(height: 20),

              // ── Sub-headline / Hero Copy ──────────────────────────────────
              Text(
                'Your Perfect place\nis just a tap away',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  color: _AppColor.textWhiteSecondary,
                  height: 1.4,
                ),
              ),

              const Spacer(flex: 3),

              // ── CTA Button Group ───────────────────────────────────────────
              // 1. Get Started (Filled Primary)
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () => _onGetStarted(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _AppColor.buttonTextPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Get Started',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2. Login (Outlined)
              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton(
                  onPressed: () => _onLogin(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _AppColor.borderWhite, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Login',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: _AppColor.textWhite,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. Explore as Guest (Outlined Ghost Style)
              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton(
                  onPressed: () => _onExploreGuest(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _AppColor.borderWhite, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Explore as Guest',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: _AppColor.textWhite,
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Custom Painter for Phosphor-style Filled House ──────────────────────────

class _PhosphorHousePainter extends CustomPainter {
  final Color color;
  _PhosphorHousePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    // Exact Phosphor house polygon baseline math
    path.moveTo(size.width * 0.5, size.height * 0.05); // Top peak
    path.lineTo(size.width * 0.05, size.height * 0.42); // Left eave transition
    path.lineTo(size.width * 0.05, size.height * 0.95); // Bottom Left
    path.lineTo(size.width * 0.95, size.height * 0.95); // Bottom Right
    path.lineTo(size.width * 0.95, size.height * 0.42); // Right eave transition
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Placeholder destination pages ───────────

class _PlaceholderPage extends StatelessWidget {
  final String label;
  const _PlaceholderPage({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColor.primaryBackground,
      body: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: _AppColor.textWhite,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
