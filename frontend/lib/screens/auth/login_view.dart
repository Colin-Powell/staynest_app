import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/services/api_client.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  StayNest — Login Screen
//  Design ref: 06_login.pdf
//
//  Usage:
//    LoginView(
//      onLogin:    () => Navigator.pushReplacementNamed(context, '/home'),
//      onRegister: () => Navigator.pushNamed(context, '/register'),
//      onForgotPassword: () => Navigator.pushNamed(context, '/forgot'),
//    )
// ─────────────────────────────────────────────────────────────────────────────

class LoginView extends StatefulWidget {
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onGoogleSignIn;

  const LoginView({
    super.key,
    required this.onLogin,
    required this.onRegister,
    this.onForgotPassword,
    this.onGoogleSignIn,
  });

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> with TickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _emailFocused = false;
  bool _passwordFocused = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  // ── Animation controllers ──────────────────────────────────────────────────

  /// Staggered content entrance
  late final AnimationController _entranceCtrl;

  /// Wave hand emoji — plays on mount, repeats 3×
  late final AnimationController _waveCtrl;

  /// Shake on failed login attempt
  late final AnimationController _shakeCtrl;

  // Derived entrance animations (7 layers, staggered)
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;
  late final Animation<double> _waveAnim;
  late final Animation<double> _shakeAnim;

  static const _layerCount =
      7; // header, email, password, forgot, btn, divider, social+link

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    // ── Entrance ─────────────────────────────────────────────────
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnims = [];
    _slideAnims = [];

    for (var i = 0; i < _layerCount; i++) {
      final start = (i * 0.10).clamp(0.0, 0.7);
      final end = (start + 0.40).clamp(0.0, 1.0);
      final curve = CurvedAnimation(
        parent: _entranceCtrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
      _fadeAnims.add(curve);
      _slideAnims.add(
        Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
            .animate(curve),
      );
    }

    // ── Wave emoji ───────────────────────────────────────────────
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _waveAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.35), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.35, end: -0.15), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -0.15, end: 0.25), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.25, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _waveCtrl, curve: Curves.easeInOut));

    // ── Shake ────────────────────────────────────────────────────
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 8.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 6.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -4.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    // ── Focus listeners ──────────────────────────────────────────
    _emailFocus.addListener(
        () => setState(() => _emailFocused = _emailFocus.hasFocus));
    _passwordFocus.addListener(
        () => setState(() => _passwordFocused = _passwordFocus.hasFocus));

    // ── Fire sequences ────────────────────────────────────────────
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _entranceCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _waveCtrl.repeat(count: 3);
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _waveCtrl.dispose();
    _shakeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    // Basic validation — shake if fields empty
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      _shakeCtrl.reset();
      _shakeCtrl.forward();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both email and password.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = RemoteDatabaseRepository();
      final user = await repository.authenticate(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );

      if (user == null) {
        _shakeCtrl.reset();
        _shakeCtrl.forward();
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid email or password. Please try again.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      AppSession.updateCurrentUser(user);
      AppSession.apiToken = user['token']?.toString() ??
          user['accessToken']?.toString() ??
          AppSession.apiToken;

      if (AppSession.currentUserId != null && AppSession.apiToken != null) {
        final favoriteRepository = RemoteDatabaseRepository();
        try {
          final favorites = await favoriteRepository
              .loadFavoritesForUser(AppSession.currentUserId!);
          final favoriteIds = favorites
              .map((item) => item['id']?.toString())
              .whereType<String>();
          AppSession.setSavedPropertyIds(favoriteIds);
        } catch (_) {
          // Ignore favorites fetch failures and continue with local session state.
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful. Redirecting...'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) widget.onLogin();
      }
    } catch (err) {
      _shakeCtrl.reset();
      _shakeCtrl.forward();
      final message = _buildErrorMessage(err);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _buildErrorMessage(Object err) {
    if (err is TimeoutException) {
      return 'Server is taking too long to respond. Please check your internet connection.';
    }

    if (err is ApiException) {
      if (err.statusCode == 401) {
        return 'Invalid email or password. Please try again.';
      }
      if (err.statusCode == 400) {
        return 'Invalid login request. Please check your details.';
      }
      return 'Unable to login right now. Please try again later.';
    }

    return 'Unable to login right now. Please try again later.';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(26, 52, 26, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── [0] Header ───────────────────────────────────
                _Entrance(
                  fade: _fadeAnims[0],
                  slide: _slideAnims[0],
                  child: _Header(waveAnim: _waveAnim),
                ),

                const SizedBox(height: 40),

                // ── [1] Email field ──────────────────────────────
                _Entrance(
                  fade: _fadeAnims[1],
                  slide: _slideAnims[1],
                  child: _InputField(
                    controller: _emailCtrl,
                    focusNode: _emailFocus,
                    isFocused: _emailFocused,
                    placeholder: 'Phone number or Email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),

                const SizedBox(height: 14),

                // ── [2] Password field ───────────────────────────
                _Entrance(
                  fade: _fadeAnims[2],
                  slide: _slideAnims[2],
                  child: AnimatedBuilder(
                    animation: _shakeAnim,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(_shakeAnim.value, 0),
                      child: child,
                    ),
                    child: _InputField(
                      controller: _passwordCtrl,
                      focusNode: _passwordFocus,
                      isFocused: _passwordFocused,
                      placeholder: 'Password',
                      obscure: _obscurePassword,
                      suffixWidget: _EyeToggle(
                        obscure: _obscurePassword,
                        onToggle: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── [3] Forgot password ──────────────────────────
                _Entrance(
                  fade: _fadeAnims[3],
                  slide: _slideAnims[3],
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _ForgotButton(
                      onTap: widget.onForgotPassword ?? () {},
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── [4] Login button ─────────────────────────────
                _Entrance(
                  fade: _fadeAnims[4],
                  slide: _slideAnims[4],
                  child: _LoginButton(
                    isLoading: _isLoading,
                    onPressed: _handleLogin,
                  ),
                ),

                const SizedBox(height: 32),

                // ── [5] Divider ──────────────────────────────────
                _Entrance(
                  fade: _fadeAnims[5],
                  slide: _slideAnims[5],
                  child: const _OrDivider(),
                ),

                const SizedBox(height: 28),

                // ── [6] Social sign-in ──────────────────────────
                _Entrance(
                  fade: _fadeAnims[6],
                  slide: _slideAnims[6],
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _SocialCircle(
                            type: _SocialType.google,
                            onTap: widget.onGoogleSignIn ?? () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _SignUpLink(onTap: widget.onRegister),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Entrance wrapper ─────────────────────────────────────────────────────────
// DRY helper: wraps any child in fade + slide-up animation

class _Entrance extends StatelessWidget {
  final Animation<double> fade;
  final Animation<Offset> slide;
  final Widget child;

  const _Entrance({
    required this.fade,
    required this.slide,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Animation<double> waveAnim;
  const _Header({required this.waveAnim});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Welcome Back 👋"
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Welcome Back ',
              style: GoogleFonts.poppins(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0D0D0D),
                height: 1.08,
                letterSpacing: -1.0,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: AnimatedBuilder(
                animation: waveAnim,
                builder: (_, __) => Transform.rotate(
                  angle: waveAnim.value,
                  alignment: const Alignment(0.7, 0.8),
                  child: Text('👋', style: GoogleFonts.poppins(fontSize: 34)),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Subtitle
        Text(
          'Login to Continue',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF8C8C9A),
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

// ─── Input field ──────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final String placeholder;
  final bool obscure;
  final TextInputType keyboardType;
  final Widget? suffixWidget;

  const _InputField({
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    required this.placeholder,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.suffixWidget,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDuration.normal,
      curve: AppCurve.enter,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFocused
              ? StayNestColors.primary.withAlpha((0.55 * 255).round())
              : const Color(0xFFE5E7EB),
          width: isFocused ? 1.8 : 1.0,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: StayNestColors.primary.withAlpha((0.08 * 255).round()),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF111827),
        ),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: GoogleFonts.poppins(
            color: const Color(0xFFB0B3BE),
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          suffixIcon: suffixWidget,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

// ─── Eye toggle (password visibility) ────────────────────────────────────────

class _EyeToggle extends StatelessWidget {
  final bool obscure;
  final VoidCallback onToggle;

  const _EyeToggle({required this.obscure, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AnimatedSwitcher(
          duration: AppDuration.fast,
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            key: ValueKey(obscure),
            color: const Color(0xFF9CA3AF),
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ─── Forgot password ──────────────────────────────────────────────────────────

class _ForgotButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ForgotButton({required this.onTap});

  @override
  State<_ForgotButton> createState() => _ForgotButtonState();
}

class _ForgotButtonState extends State<_ForgotButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedDefaultTextStyle(
        duration: AppDuration.fast,
        style: GoogleFonts.poppins(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          color:
              _pressed ? StayNestColors.primaryDark : const Color(0xFF6B7280),
        ),
        child: const Text('Forgot Password?'),
      ),
    );
  }
}

// ─── Login button ─────────────────────────────────────────────────────────────

class _LoginButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _LoginButton({required this.isLoading, required this.onPressed});

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton>
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
    return GestureDetector(
      onTapDown: widget.isLoading ? null : (_) => _pressCtrl.reverse(),
      onTapUp: widget.isLoading
          ? null
          : (_) {
              _pressCtrl.forward();
              widget.onPressed();
            },
      onTapCancel: widget.isLoading ? null : () => _pressCtrl.forward(),
      child: ScaleTransition(
        scale: _pressCtrl,
        child: AnimatedContainer(
          duration: AppDuration.normal,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.button),
            color: StayNestColors.primary,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: AppDuration.fast,
              child: widget.isLoading
                  ? const SizedBox(
                      key: ValueKey('loader'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      'Login',
                      key: const ValueKey('label'),
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

// ─── Or divider ───────────────────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: const Color(0xFFE8E8EE)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Or continue with',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFB0B3BE),
              letterSpacing: 0.1,
            ),
          ),
        ),
        Expanded(
          child: Container(height: 1, color: const Color(0xFFE8E8EE)),
        ),
      ],
    );
  }
}

// ─── Social circles ───────────────────────────────────────────────────────────
// PDF: circular buttons (not rectangular cards), centered side by side

enum _SocialType { google }

class _SocialSvg extends StatelessWidget {
  final _SocialType type;

  const _SocialSvg({required this.type});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/google.svg',
      width: 28,
      height: 28,
    );
  }
}

class _SocialCircle extends StatefulWidget {
  final _SocialType type;
  final VoidCallback onTap;

  const _SocialCircle({required this.type, required this.onTap});

  @override
  State<_SocialCircle> createState() => _SocialCircleState();
}

class _SocialCircleState extends State<_SocialCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppDuration.press,
      lowerBound: 0.92,
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
      onTapDown: (_) {
        _ctrl.reverse();
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        _ctrl.forward();
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () {
        _ctrl.forward();
        setState(() => _pressed = false);
      },
      child: ScaleTransition(
        scale: _ctrl,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _pressed ? const Color(0xFFF3F4F6) : Colors.white,
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Center(
            child: _SocialSvg(type: widget.type),
          ),
        ),
      ),
    );
  }
}

// ─── Sign up link ─────────────────────────────────────────────────────────────

class _SignUpLink extends StatefulWidget {
  final VoidCallback onTap;
  const _SignUpLink({required this.onTap});

  @override
  State<_SignUpLink> createState() => _SignUpLinkState();
}

class _SignUpLinkState extends State<_SignUpLink> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF8C8C9A),
          ),
        ),
        GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedDefaultTextStyle(
            duration: AppDuration.fast,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _pressed
                  ? StayNestColors.primaryDark
                  : StayNestColors.primary,
            ),
            child: const Text('Sign Up'),
          ),
        ),
      ],
    );
  }
}

// ─── Standalone test entry ────────────────────────────────────────────────────

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: LoginView(
      onLogin: () => debugPrint('Login tapped'),
      onRegister: () => debugPrint('Register tapped'),
    ),
  ));
}
