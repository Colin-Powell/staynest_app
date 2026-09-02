import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/api_client.dart';
import 'package:property_app/services/verification_api.dart';
import 'package:property_app/widgets/otp_input.dart';
import 'package:property_app/utils/otp_parser.dart';
import 'package:property_app/services/analytics/analytics_service.dart';

class OtpView extends StatefulWidget {
  const OtpView({super.key});

  @override
  State<OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<OtpView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _primary = Color(0xFF3D36E8);
  static const _border = Color(0xFFE4E6EF);
  static const _text = Color(0xFF14162C);
  static const _hint = Color(0xFF9395A5);

  final GlobalKey<OtpInputState> _otpInputKey = GlobalKey<OtpInputState>();

  bool _hasError = false;
  bool _isVerifying = false;
  bool _isSendingCode = false;

  int _resendSeconds = 30;
  int _expireSeconds = 600; // 10 minutes
  Timer? _resendTimer;
  Timer? _expireTimer;

  String _emailAddress = '';
  String _currentCode = '';
  bool _wasAutofilled = false;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: 0), weight: 1),
    ]).animate(
        CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    _emailAddress = AppSession.currentUserEmail?.trim() ?? '';

    AnalyticsService.logAuthEvent(AnalyticsEvents.otpScreenViewed,
        method: 'email');

    // START WITH RESEND ACTIVE SO USER CONTROLS THE SEND IF NEEDED
    _resendSeconds = 0;
    _expireSeconds = 600;
    _expireTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_expireSeconds > 0) {
        setState(() => _expireSeconds--);
      } else {
        timer.cancel();
        _handleExpiration();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboardForOtp();
    }
  }

  Future<void> _checkClipboardForOtp() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text;
      if (text != null) {
        final otp = OtpParser.extractOtp(text);
        if (otp != null && otp != _currentCode) {
          if (!mounted) return;
          _showClipboardSuggestion(otp);
        }
      }
    } catch (_) {}
  }

  void _showClipboardSuggestion(String otp) {
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(
          'Use copied code $otp?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: const Icon(Icons.paste, color: _primary),
        backgroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text('DISMISS', style: TextStyle(color: _hint)),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              _wasAutofilled = true;
              AnalyticsService.logAuthEvent(AnalyticsEvents.otpAutofillUsed,
                  method: 'clipboard');
              _otpInputKey.currentState?.setCode(otp);
            },
            child: const Text('USE CODE', style: TextStyle(color: _primary)),
          ),
        ],
      ),
    );
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendSeconds = 30;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  void _handleExpiration() {
    setState(() => _hasError = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This code has expired. Request a new code to continue.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFFE53935),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resendTimer?.cancel();
    _expireTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _requestOtpCode() async {
    if (_emailAddress.isEmpty) return;

    setState(() => _isSendingCode = true);
    try {
      final repository = RemoteDatabaseRepository();
      await repository.sendOtpToEmail(_emailAddress);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A verification code was sent to your email.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'We could not send the verification code. Please try again.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFFE53935),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _verify(String code) async {
    if (code.length < 6 || _expireSeconds == 0) return;

    setState(() {
      _hasError = false;
      _isVerifying = true;
    });

    AnalyticsService.logAuthEvent(AnalyticsEvents.otpVerificationStarted,
        method: _wasAutofilled ? 'autofill' : 'manual');

    try {
      final repository = RemoteDatabaseRepository();
      final result = await repository.verifyPhoneCode(
          code); // actually verifying email code but backend API uses same endpoint or name

      if (result == null || result['error'] != null) {
        throw Exception(result?['error']?.toString() ?? 'Verification failed.');
      }

      if (result['verified'] == true ||
          result['user']?['verified'] == true ||
          result['user'] != null) {
        AppSession.emailVerified = true;
        AppSession.currentUserVerified =
            result['user']?['verified'] == true || result['verified'] == true;
        if (result['user'] != null) {
          AppSession.updateCurrentUser(result['user']);
        }
        await AppSession.persistSession();
        AnalyticsService.logAuthEvent(AnalyticsEvents.otpVerificationSuccess,
            method: _wasAutofilled ? 'autofill' : 'manual');
      } else {
        throw Exception('Verification was not successful.');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();

      if (AppSession.isLandlord) {
        try {
          final status = await VerificationApi.getVerificationStatus();
          final isApproved =
              status?['status']?.toString().toLowerCase() == 'approved';
          final target = isApproved || AppSession.currentUserVerified
              ? '/landlord'
              : '/verification_center';
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, target);
        } catch (_) {
          final fallback = AppSession.currentUserVerified
              ? '/landlord'
              : '/verification_center';
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, fallback);
        }
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _hasError = true);
      _shakeController.forward(from: 0);

      AnalyticsService.logAuthEvent(AnalyticsEvents.otpVerificationFailed,
          method: _wasAutofilled ? 'autofill' : 'manual');

      if (mounted) {
        final message = _getFriendlyErrorMessage(error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _wasAutofilled = false; // reset
        });
      }
    }
  }

  String _getFriendlyErrorMessage(Object error) {
    if (error is TimeoutException)
      return 'The connection is taking too long. Please try again.';
    if (error is SocketException ||
        error.toString().contains('SocketException') ||
        error.toString().contains('Connection refused')) {
      return 'We can\'t reach our servers. Please check your internet connection.';
    }
    if (error is ApiException) {
      switch (error.statusCode) {
        case 400:
          return 'That code isn\'t correct. Please check the code and try again.';
        case 401:
          return 'Your session has expired. Please log in again.';
        case 403:
          return 'This code has expired. Request a new code to continue.';
        case 429:
          return 'Too many attempts. Please wait before trying again.';
        default:
          if (error.statusCode >= 500) {
            return 'We couldn\'t verify your code. Check your connection and try again.';
          }
      }
    }
    return 'Verification failed. Please try again.';
  }

  Future<void> _onResend() async {
    if (_resendSeconds > 0) return;
    _otpInputKey.currentState?.clear();
    setState(() => _hasError = false);

    AnalyticsService.logAuthEvent(AnalyticsEvents.otpResendRequested,
        method: 'email');

    _startResendTimer();
    await _requestOtpCode();
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                  Navigator.maybePop(context);
                },
                child: const Icon(Icons.arrow_back, size: 28, color: _text),
              ),
              const SizedBox(height: 36),
              Text(
                'Verify your email',
                style: GoogleFonts.poppins(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: _text,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Code sent to:',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: _hint,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _emailAddress.isNotEmpty ? _emailAddress : 'your email',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
              const SizedBox(height: 40),
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: OtpInput(
                      key: _otpInputKey,
                      length: 6,
                      hasError: _hasError,
                      isLoading: _isVerifying,
                      onChanged: (val) {
                        if (_hasError) setState(() => _hasError = false);
                        _currentCode = val;
                      },
                      onCompleted: _verify,
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Code expires in ${_formatTime(_expireSeconds)}',
                  style: GoogleFonts.poppins(
                    color: _expireSeconds < 60 ? Colors.red : _hint,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Text(
                      'Didn\'t receive the code?',
                      style: GoogleFonts.poppins(
                        color: _text,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextButton(
                      onPressed: (_resendSeconds == 0 && !_isSendingCode)
                          ? _onResend
                          : null,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: const Size(1, 1),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _resendSeconds > 0
                            ? 'Resend in ${_resendSeconds}s'
                            : 'Send code',
                        style: GoogleFonts.poppins(
                          color: _resendSeconds > 0 ? _hint : _primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : () => _verify(_currentCode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Verify',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
