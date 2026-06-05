import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  staynest — Onboarding Flow  (Modern redesign with Poppins typography)
//
//  Features:
//    - Poppins font family for all typography
//    - Asset-based illustrations (PNG/JPG from assets/illustrations/)
//    - Phosphor icons integration (filled, bold)
//    - Clean, modern UI matching current design system
//
//  Drop-in usage:
//    OnboardingView(onFinish: () => Navigator.pushReplacementNamed(ctx, '/home'))
//
//  Required assets in pubspec.yaml:
//    - assets/illustrations/slide_1_house.png
//    - assets/illustrations/slide_2_shield.png
//    - assets/illustrations/slide_3_magnify.png
// ─────────────────────────────────────────────────────────────────────────────

// ─── Design tokens ───────────────────────────────────────────────────────────

abstract class _C {
  /// Primary indigo — button fill, active dot
  static const primary = Color(0xFF3D3EDB);

  static const background = Color(0xFFFFFFFF);
  static const heading = Color(0xFF0D0D0D);
  static const body = Color(0xFF8C8C9A);
  static const dotInactive = Color(0xFFDDDDEE);
  static const skip = Color(0xFF9CA3AF);
}

abstract class _T {
  static const slide = Duration(milliseconds: 380);
  static const fade = Duration(milliseconds: 300);
  static const dot = Duration(milliseconds: 260);
  static const press = Duration(milliseconds: 80);
}

// ─── Data model ──────────────────────────────────────────────────────────────

class _Slide {
  final String title;
  final String body;
  final Widget Function(BuildContext) illustrationBuilder;

  const _Slide({
    required this.title,
    required this.body,
    required this.illustrationBuilder,
  });
}

// ─── Main widget ─────────────────────────────────────────────────────────────

class OnboardingView extends StatefulWidget {
  final VoidCallback onFinish;

  const OnboardingView({super.key, required this.onFinish});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView>
    with TickerProviderStateMixin {
  int _current = 0;
  int _previous = -1;
  bool _animating = false;

  late AnimationController _slideCtrl;
  late AnimationController _fadeCtrl;
  late Animation<Offset> _slideIn;
  late Animation<Offset> _slideOut;
  late Animation<double> _fadeIn;
  late Animation<double> _fadeOut;

  final _slides = <_Slide>[
    _Slide(
      title: 'Find Your\nPerfect Place',
      body: 'Discover verified rooms, apartments\nand houses near you',
      illustrationBuilder: (_) => const _HouseIllustration(),
    ),
    _Slide(
      title: 'Verified Homes,\nTrusted Landlords',
      body:
          'We verify every landlord and listing\nto keep you safe from fraud.',
      illustrationBuilder: (_) => const _ShieldIllustration(),
    ),
    _Slide(
      title: 'Easy Search,\nSmart Choice',
      body: 'Search, compare and book\nhomes that fit your budget.',
      illustrationBuilder: (_) => const _MagnifyIllustration(),
    ),
  ];

  @override
  void initState() {
    super.initState();

    _slideCtrl = AnimationController(vsync: this, duration: _T.slide);
    _fadeCtrl = AnimationController(vsync: this, duration: _T.fade);

    _slideIn = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideOut = Tween<Offset>(begin: Offset.zero, end: const Offset(-0.25, 0))
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeIn));

    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeOut = Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(parent: _slideCtrl, curve: const Interval(0, 0.4)));

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ─── Navigation ──────────────────────────────────────────────────────────

  Future<void> _advance() async {
    if (_animating) return;

    if (_current == _slides.length - 1) {
      widget.onFinish();
      return;
    }

    _animating = true;
    _previous = _current;

    setState(() => _current += 1);

    _slideCtrl.reset();
    _fadeCtrl.reset();
    await Future.wait([_slideCtrl.forward(), _fadeCtrl.forward()]);

    setState(() => _previous = -1);
    _animating = false;
  }

  void _skip() => widget.onFinish();

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLast = _current == _slides.length - 1;
    final isFirst = _current == 0;

    return Scaffold(
      backgroundColor: _C.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Content area (title + body + illustration) ─────────────────
            Expanded(
              child: Stack(
                children: [
                  // Outgoing slide (previous)
                  if (_previous >= 0)
                    SlideTransition(
                      position: _slideOut,
                      child: FadeTransition(
                        opacity: _fadeOut,
                        child: _SlideContent(slide: _slides[_previous]),
                      ),
                    ),

                  // Incoming / current slide
                  SlideTransition(
                    position: _previous >= 0
                        ? _slideIn
                        : const AlwaysStoppedAnimation(Offset.zero),
                    child: FadeTransition(
                      opacity: _previous >= 0
                          ? _fadeIn
                          : const AlwaysStoppedAnimation(1.0),
                      child: _SlideContent(slide: _slides[_current]),
                    ),
                  ),
                ],
              ),
            ),

            // ── Bottom controls ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Next / Get Started button
                  _PrimaryButton(
                    label: isLast ? 'Get Started' : 'Next',
                    onTap: _advance,
                  ),

                  const SizedBox(height: 16),

                  // Skip — hidden on slide 3)
                  AnimatedOpacity(
                    opacity: isLast ? 0 : 1,
                    duration: _T.fade,
                    child: IgnorePointer(
                      ignoring: isFirst,
                      child: GestureDetector(
                        onTap: _skip,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Center(
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                color: _C.skip,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Step dots — below Skip, matching PDF layout
                  _StepDots(total: _slides.length, current: _current),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Slide content (title + body + illustration) ──────────────────────────────

class _SlideContent extends StatelessWidget {
  final _Slide slide;
  const _SlideContent({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text block
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title — Poppins bold weight, tight leading, left-aligned
              Text(
                slide.title,
                style: GoogleFonts.poppins(
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: _C.heading,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              // Body — Poppins medium weight, relaxed leading, muted gray
              Text(
                slide.body,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _C.body,
                  height: 1.60,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),

        // Illustration — takes remaining vertical space
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Center(
              child: slide.illustrationBuilder(context),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Step indicator dots ──────────────────────────────────────────────────────

class _StepDots extends StatelessWidget {
  final int total;
  final int current;
  const _StepDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: _T.dot,
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 26 : 9,
          height: 9,
          decoration: BoxDecoration(
            color: active ? _C.primary : _C.dotInactive,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}

// ─── Primary button with press-scale feedback ─────────────────────────────────

class _PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: _T.press,
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _ctrl,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: _C.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: _T.fade,
              child: Text(
                widget.label,
                key: ValueKey(widget.label),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Illustrations — Asset-based images from assets/illustrations/
// ─────────────────────────────────────────────────────────────────────────────

// ── Slide 1: Modern house with landscaping ────────────────────────────────────

class _HouseIllustration extends StatelessWidget {
  const _HouseIllustration();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Image.asset(
          'assets/illustrations/slide_1_house.png',
          fit: BoxFit.contain,
        ),
      );
}

// ── Slide 2: Shield with check on lavender circle ────────────────────────────

class _ShieldIllustration extends StatelessWidget {
  const _ShieldIllustration();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Image.asset(
          'assets/illustrations/slide_2_shield.png',
          fit: BoxFit.contain,
        ),
      );
}

// ── Slide 3: Magnifying glass over a house ────────────────────────────────────

class _MagnifyIllustration extends StatelessWidget {
  const _MagnifyIllustration();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Image.asset(
          'assets/illustrations/slide_3_magnify.png',
          fit: BoxFit.contain,
        ),
      );
}

// ─── Stub entry point for standalone testing ─────────────────────────────────

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OnboardingView(
      onFinish: () {},
    ),
  ));
}
