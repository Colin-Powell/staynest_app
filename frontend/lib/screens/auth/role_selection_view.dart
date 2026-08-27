import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Theme Constants (Minimalist Style) ──────────────────────────────────────
const Color _primary = Color(0xFF3F37C9);      // Tenant Blue
const Color _textDark = Color(0xFF222222);     // Dark Grey/Black
const Color _textLight = Color(0xFF717171);    // Light Grey
const Color _dividerColor = Color(0xFFEBEBEB); // Soft Border Color

const Duration _durNormal = Duration(milliseconds: 250);
const Duration _durPress = Duration(milliseconds: 150);
const Curve _curveEnter = Curves.easeOutCubic;

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

  String get subtitle {
    switch (this) {
      case StayNestRole.tenant:
        return '(Tenant)';
      case StayNestRole.landlord:
        return '(Landlord/Agent)';
    }
  }

  // Replace IconData with webp image paths
  String get imagePath {
    switch (this) {
      case StayNestRole.tenant:
        return 'assets/images/tenant.webp';
      case StayNestRole.landlord:
        return 'assets/images/landlord.webp';
    }
  }
}

// ─── View ────────────────────────────────────────────────────────────────────

class RoleSelectionView extends StatefulWidget {
  final VoidCallback? onBack;
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

    _cardAnims = List.generate(_roles.length, (i) {
      final start = i * 0.15;
      final end = start + 0.55;
      return CurvedAnimation(
        parent: _entranceCtrl,
        curve: Interval(start.clamp(0, 1), end.clamp(0, 1), curve: _curveEnter),
      );
    });

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Ultra-clean solid white background
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header block ──────────────────────────────────────
            _Header(onBack: widget.onBack),

            // ── Role cards ────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                physics: const BouncingScrollPhysics(),
                itemCount: _roles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 20),
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

class _Header extends StatelessWidget {
  final VoidCallback? onBack;
  const _Header({this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null) ...[
            _BackButton(onTap: onBack!),
            const SizedBox(height: 32),
          ],
          
          Text(
            'Choose Your Role',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: _textDark,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Select the option that best describes you.',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: _textLight,
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
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _dividerColor, width: 1.2),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: _textDark,
          size: 20,
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
      duration: _durPress,
      lowerBound: 0.96,
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
          duration: _durNormal,
          curve: _curveEnter,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? _primary : _dividerColor,
              width: selected ? 2.0 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(selected ? 0.08 : 0.02),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // ── Image box (No background styling) ──────────────────
              SizedBox(
                width: 72,
                height: 72,
                child: Image.asset(
                  role.imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.image_not_supported, color: _textLight),
                ),
              ),

              const SizedBox(width: 20),

              // ── Text block ───────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      role.title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                        height: 1.2,
                      ),
                    ),
                    if (role.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        role.subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: _textLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // ── Optional Selection Indicator (Circle Check) ─────────
              AnimatedContainer(
                duration: _durNormal,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? _primary : Colors.transparent,
                  border: Border.all(
                    color: selected ? _primary : _dividerColor,
                    width: 2,
                  ),
                ),
                child: selected 
                    ? const Icon(Icons.check, size: 14, color: Colors.white) 
                    : null,
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
      duration: _durPress,
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
      padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).padding.bottom + 24),
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
            duration: _durNormal,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: widget.enabled ? _primary : _primary.withOpacity(0.4),
            ),
            child: Center(
              child: Text(
                'Continue',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
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