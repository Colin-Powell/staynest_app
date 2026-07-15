import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/core/responsive/breakpoints.dart';
import 'package:property_app/utils/api_result.dart';
import 'package:property_app/utils/responsive_layout.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView>
    with TickerProviderStateMixin {
  // ── Form ──────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _businessDescriptionController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _yearsInBusinessController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  bool get _isLandlord => AppSession.isLandlord;

  // ── Animation controllers ─────────────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final AnimationController _buttonCtrl;

  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _field1Fade;
  late final Animation<Offset> _field1Slide;
  late final Animation<double> _field2Fade;
  late final Animation<Offset> _field2Slide;
  late final Animation<double> _field3Fade;
  late final Animation<Offset> _field3Slide;
  late final Animation<double> _field4Fade;
  late final Animation<Offset> _field4Slide;
  late final Animation<double> _bottomFade;
  late final Animation<Offset> _bottomSlide;
  late final Animation<double> _buttonScale;

  // ── Colors (straight from PDF) ────────────────────────────────────────────
  static const _primary = Color(0xFF3D36E8);
  static const _bg = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E6EF);
  static const _hint = Color(0xFFB0B3C6);
  static const _label = Color(0xFF14162C);
  static const _subtext = Color(0xFF9395A5);

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    Animation<double> fade(double s, double e) => CurvedAnimation(
          parent: _entranceCtrl,
          curve: Interval(s, e, curve: Curves.easeOut),
        );

    Animation<Offset> slide(double s, double e) =>
        Tween<Offset>(begin: const Offset(0, 0.22), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceCtrl,
            curve: Interval(s, e, curve: Curves.easeOutCubic),
          ),
        );

    _headerFade = fade(0.00, 0.40);
    _headerSlide = slide(0.00, 0.45);
    _field1Fade = fade(0.15, 0.52);
    _field1Slide = slide(0.15, 0.52);
    _field2Fade = fade(0.25, 0.60);
    _field2Slide = slide(0.25, 0.60);
    _field3Fade = fade(0.35, 0.68);
    _field3Slide = slide(0.35, 0.68);
    _field4Fade = fade(0.45, 0.76);
    _field4Slide = slide(0.45, 0.76);
    _bottomFade = fade(0.60, 1.00);
    _bottomSlide = slide(0.60, 1.00);

    _buttonCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _buttonScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _buttonCtrl, curve: Curves.easeInOut),
    );

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _businessNameController.dispose();
    _businessTypeController.dispose();
    _businessDescriptionController.dispose();
    _taxIdController.dispose();
    _yearsInBusinessController.dispose();
    _entranceCtrl.dispose();
    _buttonCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSignUp() async {
    FocusScope.of(context).unfocus();
    await _buttonCtrl.forward();
    await _buttonCtrl.reverse();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final repo = RemoteDatabaseRepository();
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final user = await repo.register(
        name,
        phone,
        email,
        password,
        AppSession.currentRole,
        businessFields: _isLandlord
            ? {
                'business_name': _businessNameController.text.trim(),
                'business_type': _businessTypeController.text.trim(),
                'business_description':
                    _businessDescriptionController.text.trim(),
                'tax_id': _taxIdController.text.trim(),
                'years_in_business':
                    int.tryParse(_yearsInBusinessController.text.trim()),
              }
            : null,
      );
      if (user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Registration failed. Please check your information and try again.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Registration succeeded
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful. Please enter the OTP.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Populate session with returned user and token
      AppSession.updateCurrentUser(user);
      AppSession.apiToken = user['token']?.toString() ?? AppSession.apiToken;

      if (mounted) {
        setState(() => _isLoading = false);
        // Landlords go directly to OTP after registration; tenants continue to the survey
        if (AppSession.isLandlord) {
          Navigator.pushReplacementNamed(context, '/otp');
        } else {
          Navigator.pushReplacementNamed(context, '/survey');
        }
      }
    } catch (err) {
      if (mounted) {
        setState(() => _isLoading = false);
        final message = ApiResult.mapError(err);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isCompactScreen = ResponsiveLayout.isCompact(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isCompactScreen ? 24 : 32,
              vertical: isCompactScreen ? 16 : 24,
            ),
            child: ResponsiveLayout.authShell(
              context: context,
              maxWidth: AppBreakpoints.signupMaxWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Back arrow
                  FadeTransition(
                    opacity: _headerFade,
                    child: SlideTransition(
                      position: _headerSlide,
                      child: GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        child: const Icon(
                          Icons.arrow_back,
                          size: 24,
                          color: _label,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Title + subtitle
                  FadeTransition(
                    opacity: _headerFade,
                    child: SlideTransition(
                      position: _headerSlide,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Account',
                            style: GoogleFonts.poppins(
                              fontSize: isCompactScreen ? 36 : 48,
                              fontWeight: FontWeight.w800,
                              color: _label,
                              letterSpacing: -0.5,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sign up to get started',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: _subtext,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _AnimatedField(
                          fade: _field1Fade,
                          slide: _field1Slide,
                          child: _InputField(
                            controller: _nameController,
                            hint: 'Full name',
                            keyboardType: TextInputType.name,
                            textInputAction: TextInputAction.next,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter your full name'
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _AnimatedField(
                          fade: _field2Fade,
                          slide: _field2Slide,
                          child: _InputField(
                            controller: _phoneController,
                            hint: 'Phone number',
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter your phone number'
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _AnimatedField(
                          fade: _field3Fade,
                          slide: _field3Slide,
                          child: _InputField(
                            controller: _emailController,
                            hint: 'Email Address',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Enter your email';
                              }
                              if (!v.contains('@')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        _AnimatedField(
                          fade: _field4Fade,
                          slide: _field4Slide,
                          child: _InputField(
                            controller: _passwordController,
                            hint: 'Password',
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _onSignUp(),
                            suffixIcon: GestureDetector(
                              onTap: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  key: ValueKey(_obscurePassword),
                                  size: 20,
                                  color: _hint,
                                ),
                              ),
                            ),
                            validator: (v) => (v == null || v.length < 6)
                                ? 'Password must be 6+ characters'
                                : null,
                          ),
                        ),
                        if (_isLandlord) ...[
                          const SizedBox(height: 16),
                          _AnimatedField(
                            fade: _bottomFade,
                            slide: _bottomSlide,
                            child: _InputField(
                              controller: _businessNameController,
                              hint: 'Business name',
                              keyboardType: TextInputType.name,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Enter your business name'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _AnimatedField(
                            fade: _bottomFade,
                            slide: _bottomSlide,
                            child: _InputField(
                              controller: _businessTypeController,
                              hint: 'Business type',
                              keyboardType: TextInputType.text,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Enter your business type'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _AnimatedField(
                            fade: _bottomFade,
                            slide: _bottomSlide,
                            child: _InputField(
                              controller: _taxIdController,
                              hint: 'Business tax ID',
                              keyboardType: TextInputType.text,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Enter your tax ID'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _AnimatedField(
                            fade: _bottomFade,
                            slide: _bottomSlide,
                            child: _InputField(
                              controller: _yearsInBusinessController,
                              hint: 'Years in business',
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Enter years in business';
                                }
                                final parsed = int.tryParse(v);
                                if (parsed == null || parsed < 0) {
                                  return 'Enter a valid number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          _AnimatedField(
                            fade: _bottomFade,
                            slide: _bottomSlide,
                            child: _InputField(
                              controller: _businessDescriptionController,
                              hint: 'Business description',
                              keyboardType: TextInputType.text,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Enter a short description'
                                  : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Sign Up button
                  FadeTransition(
                    opacity: _bottomFade,
                    child: SlideTransition(
                      position: _bottomSlide,
                      child: ScaleTransition(
                        scale: _buttonScale,
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _onSignUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: _isLoading
                                  ? const SizedBox(
                                      key: ValueKey('loader'),
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      'Sign Up',
                                      key: const ValueKey('label'),
                                      style: GoogleFonts.poppins(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Divider
                  FadeTransition(
                    opacity: _bottomFade,
                    child: Row(
                      children: [
                        const Expanded(
                          child: Divider(
                            color: _border,
                            thickness: 1,
                            endIndent: 12,
                          ),
                        ),
                        Text(
                          'Or continue with',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: _subtext,
                          ),
                        ),
                        const Expanded(
                          child: Divider(
                            color: _border,
                            thickness: 1,
                            indent: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Social buttons
                  FadeTransition(
                    opacity: _bottomFade,
                    child: SlideTransition(
                      position: _bottomSlide,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _SocialButton(
                            onTap: () {},
                            child: SvgPicture.asset(
                              'assets/images/google.svg',
                              width: 28,
                              height: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Login prompt
                  FadeTransition(
                    opacity: _bottomFade,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style:
                              GoogleFonts.poppins(fontSize: 14, color: _subtext),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/login'),
                          child: Text(
                            'Login',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: _primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Animated wrapper ───────────────────────────────────────────────────────

class _AnimatedField extends StatelessWidget {
  const _AnimatedField({
    required this.fade,
    required this.slide,
    required this.child,
  });

  final Animation<double> fade;
  final Animation<Offset> slide;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

// ── Input field ────────────────────────────────────────────────────────────

class _InputField extends StatefulWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.suffixIcon,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
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
        fontSize: 15,
        color: _RegisterViewState._label,
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: GoogleFonts.poppins(
          color: _RegisterViewState._hint,
          fontSize: 15,
        ),
        suffixIcon: widget.suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: _RegisterViewState._border,
            width: 1.4,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: _RegisterViewState._border,
            width: 1.4,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: _RegisterViewState._primary,
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE53935),
            width: 1.8,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE53935),
            width: 1.8,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        errorStyle: GoogleFonts.poppins(height: 0, fontSize: 0),
      ),
      validator: widget.validator,
    );
  }
}

// ── Social button ──────────────────────────────────────────────────────────

class _SocialButton extends StatefulWidget {
  const _SocialButton({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
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
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) async {
        await _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _RegisterViewState._border, width: 1.4),
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}
