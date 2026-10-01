import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/services/api_client.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/analytics/analytics_service.dart';
import 'package:property_app/utils/auth_validators.dart';

class LoginView extends StatefulWidget {
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback? onForgotPassword;
  final Future<void> Function()? onGoogleSignIn;

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
  // ─── Theme Constants (Minimalist Style) ──────────────────────────────────────
  static const Color _primary = Color(0xFF3F37C9); // Tenant Blue
  static const Color _textDark = Color(0xFF222222); // Dark Grey/Black
  static const Color _textLight = Color(0xFF717171); // Light Grey
  static const Color _dividerColor = Color(0xFFEBEBEB); // Soft Border Color
  static const Color _errorColor = Color(0xFFE53935);

  // ── Controllers ────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleSigningIn = false;

  // ── Animation controllers ──────────────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final AnimationController _waveCtrl;
  late final AnimationController _shakeCtrl;

  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _waveAnim;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    // ── Entrance Animation ───────────────────────────────────────
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic),
    );

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

    // ── Error Shake Animation ────────────────────────────────────
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 8.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 6.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -4.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    // ── Fire sequences ────────────────────────────────────────────
    _entranceCtrl.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
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
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _handleGoogleSignIn() async {
    if (_isGoogleSigningIn) return;
    setState(() => _isGoogleSigningIn = true);
    try {
      if (widget.onGoogleSignIn != null) {
        await widget.onGoogleSignIn!();
      }
    } catch (e) {
      _triggerErrorShake('Google Sign-In failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isGoogleSigningIn = false);
    }
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      _shakeCtrl.reset();
      _shakeCtrl.forward();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = RemoteDatabaseRepository();
      final user = await repository.authenticate(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );

      if (user == null) {
        _triggerErrorShake('Invalid email or password. Please try again.');
        return;
      }

      AppSession.apiToken = user['token']?.toString() ??
          user['accessToken']?.toString() ??
          AppSession.apiToken;
      AppSession.refreshToken =
          user['refreshToken']?.toString() ?? AppSession.refreshToken;

      AppSession.updateCurrentUser(user);
      try {
        final freshUser = await repository.loadCurrentUser();
        AppSession.updateCurrentUser(freshUser);
      } catch (_) {
        // The auth payload is already enough to continue; fall back to it.
      }
      AnalyticsService.logAuthEvent(AnalyticsEvents.login, method: 'email');
      await AppSession.persistSession();

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
          // Ignore favorites fetch failures
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
        widget.onLogin();
      }
    } catch (err) {
      _triggerErrorShake(_buildErrorMessage(err));
    }
  }

  void _triggerErrorShake(String message) {
    _shakeCtrl.reset();
    _shakeCtrl.forward();
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: _errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _buildErrorMessage(Object err) {
    if (err is TimeoutException) {
      return 'Server taking too long. Check your internet.';
    }
    if (err is ApiException) {
      if (err.statusCode == 401) return 'Invalid email or password.';
      if (err.statusCode == 400) return 'Invalid login request.';
    }
    return 'Unable to login right now. Please try again later.';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Back Button (Optional context pop) ---
                    if (Navigator.canPop(context)) ...[
                      GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: _dividerColor, width: 1.2),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: _textDark,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ] else
                      const SizedBox(height: 48), // Padding if no back button

                    // --- Header ---
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        Text(
                          'Welcome Back ',
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: AnimatedBuilder(
                            animation: _waveAnim,
                            builder: (_, __) => Transform.rotate(
                              angle: _waveAnim.value,
                              alignment: const Alignment(0.7, 0.8),
                              child: Text('👋',
                                  style: GoogleFonts.poppins(fontSize: 28)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Log in to your StayNest account.',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: _textLight,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // --- Form ---
                    AnimatedBuilder(
                      animation: _shakeAnim,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(_shakeAnim.value, 0),
                        child: child,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _InputField(
                              controller: _emailCtrl,
                              label: 'Email Address',
                              keyboardType: TextInputType.emailAddress,
                              validator: AuthValidators.email,
                            ),
                            const SizedBox(height: 16),
                            _InputField(
                              controller: _passwordCtrl,
                              label: 'Password',
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _handleLogin(),
                              suffixIcon: GestureDetector(
                                onTap: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                                child: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 22,
                                  color: _textLight,
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Enter your password'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // --- Forgot Password ---
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: widget.onForgotPassword ?? () {},
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // --- Login Button ---
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _primary.withOpacity(0.5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : Text(
                                'Login',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // --- Divider ---
                    Row(
                      children: [
                        const Expanded(
                            child:
                                Divider(color: _dividerColor, thickness: 1.2)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'or',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: _textLight,
                            ),
                          ),
                        ),
                        const Expanded(
                            child:
                                Divider(color: _dividerColor, thickness: 1.2)),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // --- Google Button ---
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed:
                            _isGoogleSigningIn ? null : _handleGoogleSignIn,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textDark,
                          side: const BorderSide(color: _textDark, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isGoogleSigningIn
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation(_textDark),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    'assets/images/google.svg',
                                    width: 24,
                                    height: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      'Continue with Google',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: _textDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // --- Sign Up Prompt ---
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: GoogleFonts.poppins(
                              fontSize: 15, color: _textLight),
                        ),
                        GestureDetector(
                          onTap: widget.onRegister,
                          child: Text(
                            'Sign Up',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              color: _textDark,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Input field ────────────────────────────────────────────────────────────

class _InputField extends StatefulWidget {
  const _InputField({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.suffixIcon,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  final _focus = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      setState(() => _isFocused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focus,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      style: GoogleFonts.poppins(
        fontSize: 16,
        color: _LoginViewState._textDark,
        fontWeight: FontWeight.w500,
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: GoogleFonts.poppins(
          color: _isFocused
              ? _LoginViewState._textDark
              : _LoginViewState._textLight,
          fontSize: 15,
        ),
        floatingLabelStyle: GoogleFonts.poppins(
          color: _LoginViewState._textDark,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        suffixIcon: widget.suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: _LoginViewState._dividerColor,
            width: 1.2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: _LoginViewState._dividerColor,
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: _LoginViewState._textDark,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: _LoginViewState._errorColor,
            width: 1.2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: _LoginViewState._errorColor,
            width: 1.5,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        errorStyle: GoogleFonts.poppins(
          color: _LoginViewState._errorColor,
          fontSize: 12,
        ),
      ),
      validator: widget.validator,
    );
  }
}
