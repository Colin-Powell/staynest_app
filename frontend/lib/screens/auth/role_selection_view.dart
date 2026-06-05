import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  StayNest — Role Selection Screen
//  Design ref: 05_roles.pdf
//
//  Usage:
//    RoleSelectionView(
//      onBack:   () => Navigator.pop(context),
//      onSelect: (role) => Navigator.pushNamed(context, '/$role'),
//    )
// ─────────────────────────────────────────────────────────────────────────────

// ─── Role model ──────────────────────────────────────────────────────────────

enum StayNestRole { tenant, landlord }

extension StayNestRoleX on StayNestRole {
  String get key {
    switch (this) {
      case StayNestRole.tenant:
        return 'tenant';
      case StayNestRole.landlord:
        return 'landlord';
    }
  }

  String get title {
    switch (this) {
      case StayNestRole.tenant:
        return "I'm looking for a place";
      case StayNestRole.landlord:
        return "I'm a Landlord/Agent";
    }
  }

  /// Shown in muted gray below title — empty string hides the row
  String get subtitle {
    switch (this) {
      case StayNestRole.tenant:
        return '(Tenant)';
      case StayNestRole.landlord:
        return '(Landlord/Agent)';
    }
  }

  IconData get icon {
    switch (this) {
      case StayNestRole.tenant:
        return Icons.key_rounded;
      case StayNestRole.landlord:
        return Icons.home_rounded;
    }
  }
}

// ─── View ────────────────────────────────────────────────────────────────────

class RoleSelectionView extends StatefulWidget {
  /// Called when the user taps the back button (if shown).
  /// Pass null to hide the back button entirely (matches PDF design).
  final VoidCallback? onBack;

  /// Called with the selected role key when Continue is tapped.
  final void Function(String role) onSelect;

  const RoleSelectionView({
    super.key,
    this.onBack,
    required this.onSelect,
  });

  @override
  State<RoleSelectionView> createState() => _RoleSelectionViewState();
}

class _RoleSelectionViewState extends State<RoleSelectionView>
    with SingleTickerProviderStateMixin {
  StayNestRole? _selected;

  // Subtle entrance animation for the card list
  late final AnimationController _entranceCtrl;
  late final List<Animation<double>> _cardAnims;

  static const _roles = StayNestRole.values;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Stagger each card by 80ms
    _cardAnims = List.generate(_roles.length, (i) {
      final start = i * 0.15;
      final end = start + 0.55;
      return CurvedAnimation(
        parent: _entranceCtrl,
        curve: Interval(start.clamp(0, 1), end.clamp(0, 1),
            curve: Curves.easeOutCubic),
      );
    });

    // Slight delay so scaffold renders first
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  void _handleContinue() {
    if (_selected == null) return;
    widget.onSelect(_selected!.key);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // PDF background: very light gray, NOT pure white
      backgroundColor: const Color(0xFFF4F4F6),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header block ──────────────────────────────────────
            _Header(onBack: widget.onBack),

            // ── Role cards ────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(22, 36, 22, 24),
                physics: const BouncingScrollPhysics(),
                itemCount: _roles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, i) {
                  final role = _roles[i];
                  return _AnimatedCard(
                    animation: _cardAnims[i],
                    child: _RoleCard(
                      role: role,
                      selected: _selected == role,
                      onTap: () => setState(() => _selected = role),
                    ),
                  );
                },
              ),
            ),

            // ── Continue button ───────────────────────────────────
            _ContinueButton(
              enabled: _selected != null,
              onPressed: _handleContinue,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────
//  PDF: No back arrow on this screen. Back arrow is optional (pass onBack).

class _Header extends StatelessWidget {
  final VoidCallback? onBack;
  const _Header({this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Optional back button — hidden when onBack is null
          if (onBack != null) ...[
            _BackButton(onTap: onBack!),
            const SizedBox(height: 24),
          ],

          // "Choose Your Role" — very large, black, heavy
          Text(
            'Choose Your Role',
            style: GoogleFonts.poppins(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0D0D0D),
              height: 1.08,
              letterSpacing: -1.0,
            ),
          ),

          const SizedBox(height: 10),

          // Subtitle
          Text(
            'Select the option that best describes you.',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF8C8C9A),
              height: 1.50,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const SizedBox(
        width: 44,
        height: 44,
        child: Icon(
          Icons.chevron_left_rounded,
          color: Color(0xFF374151),
          size: 26,
        ),
      ),
    );
  }
}

// ─── Animated card entrance ───────────────────────────────────────────────────

class _AnimatedCard extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _AnimatedCard({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Opacity(
        opacity: animation.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - animation.value)),
          child: child,
        ),
      ),
    );
  }
}

// ─── Role card ───────────────────────────────────────────────────────────────

class _RoleCard extends StatefulWidget {
  final StayNestRole role;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: AppDuration.press,
      lowerBound: 0.975,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final role = widget.role;

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.reverse(),
      onTapUp: (_) {
        _pressCtrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _pressCtrl.forward(),
      child: ScaleTransition(
        scale: _pressCtrl,
        child: AnimatedContainer(
          duration: AppDuration.normal,
          curve: AppCurve.enter,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),

            // Selected: indigo border; unselected: near-invisible hairline
            border: Border.all(
              color:
                  selected ? StayNestColors.primary : const Color(0xFFE8E8EE),
              width: selected ? 2.0 : 1.0,
            ),

            boxShadow: selected
                ? [
                    const BoxShadow(
                      color: Color.fromRGBO(61, 62, 219, 0.10),
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.04),
                      blurRadius: 12,
                      offset: Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // ── Icon box ─────────────────────────────────────────
              AnimatedContainer(
                duration: AppDuration.normal,
                curve: AppCurve.enter,
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: selected
                      ? StayNestColors.primaryLight
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: AnimatedSwitcher(
                  duration: AppDuration.fast,
                  child: Icon(
                    role.icon,
                    key: ValueKey(selected),
                    color: selected
                        ? StayNestColors.primary
                        : const Color(0xFF6B7280),
                    size: 32,
                  ),
                ),
              ),

              const SizedBox(width: 18),

              // ── Text block ───────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      role.title,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? StayNestColors.primary
                            : const Color(0xFF111827),
                        height: 1.22,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (role.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        role.subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF9CA3AF),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Continue button ──────────────────────────────────────────────────────────

class _ContinueButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _ContinueButton({
    required this.enabled,
    required this.onPressed,
  });

  @override
  State<_ContinueButton> createState() => _ContinueButtonState();
}

class _ContinueButtonState extends State<_ContinueButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: AppDuration.press,
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => _pressCtrl.reverse() : null,
        onTapUp: widget.enabled
            ? (_) {
                _pressCtrl.forward();
                widget.onPressed();
              }
            : null,
        onTapCancel: widget.enabled ? () => _pressCtrl.forward() : null,
        child: ScaleTransition(
          scale: _pressCtrl,
          child: AnimatedContainer(
            duration: AppDuration.normal,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.button),
              color: widget.enabled
                  ? StayNestColors.primary
                  : const Color.fromRGBO(61, 62, 219, 0.38),
            ),
            child: Center(
              child: Text(
                'Continue',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: widget.enabled
                      ? Colors.white
                      : const Color.fromRGBO(255, 255, 255, 0.55),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Standalone test entry ────────────────────────────────────────────────────

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RoleSelectionView(
      onSelect: (role) => debugPrint('Selected: $role'),
    ),
  ));
}
