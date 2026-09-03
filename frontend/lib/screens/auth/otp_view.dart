import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/api_client.dart';
import 'package:property_app/services/verification_api.dart';
import 'package:property_app/widgets/otp_input.dart';
import 'package:property_app/utils/otp_parser.dart';
import 'package:property_app/services/analytics/analytics_service.dart';
import 'package:property_app/utils/auth_validators.dart';

// ─── Design System Constants ──────────────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _primary = Color(0xFF3F37C9); // Tenant Blue Theme

class OtpView extends StatefulWidget {
  const OtpView({super.key});

  @override
  State<OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<OtpView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  final GlobalKey<OtpInputState> _otpInputKey = GlobalKey<OtpInputState>();

  bool _hasError = false;
  bool _isVerifying = false;
  bool _isSendingCode = false;

  int _resendSeconds = 600;
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
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    _emailAddress = AppSession.currentUserEmail?.trim() ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _emailAddress.isEmpty) return;
      _requestOtpOnEntry();
    });

    AnalyticsService.logAuthEvent(AnalyticsEvents.otpScreenViewed, method: 'email');

    _resendSeconds = 600;
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
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _dark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(24),
        content: Row(
          children: [
            const Icon(PhosphorIconsRegular.clipboardText, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Use copied code $otp?',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Use Code',
          textColor: _primary,
          onPressed: () {
            _wasAutofilled = true;
            AnalyticsService.logAuthEvent(AnalyticsEvents.otpAutofillUsed, method: 'clipboard');
            _otpInputKey.currentState?.setCode(otp);
          },
        ),
      ),
    );
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendSeconds = 600;
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
      SnackBar(
        content: Text('This code has expired. Request a new code to continue.', style: GoogleFonts.poppins()),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFEF4444),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Future<bool> _requestOtpCode() async {
    if (_emailAddress.isEmpty) return false;

    setState(() => _isSendingCode = true);
    try {
      final repository = RemoteDatabaseRepository();
      await repository.sendOtpToEmail(_emailAddress);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A verification code was sent to your email.', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        final message = _getFriendlyErrorMessage(error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFEF4444),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _requestOtpOnEntry() async {
    final sent = await _requestOtpCode();
    if (!mounted || sent) return;
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
      final result = await repository.verifyPhoneCode(code); 

      if (result == null || result['error'] != null) {
        throw Exception(result?['error']?.toString() ?? 'Verification failed.');
      }

      if (result['verified'] == true ||
          result['user']?['verified'] == true ||
          result['user'] != null) {
        AppSession.emailVerified = true;
        AppSession.currentUserVerified = result['user']?['verified'] == true || result['verified'] == true;
        if (result['user'] != null) {
          AppSession.updateCurrentUser(result['user']);
        }
        await AppSession.persistSession();
        AnalyticsService.logAuthEvent(AnalyticsEvents.otpVerificationSuccess, method: _wasAutofilled ? 'autofill' : 'manual');
      } else {
        throw Exception('Verification was not successful.');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (AppSession.isLandlord) {
        try {
          final status = await VerificationApi.getVerificationStatus();
          final isApproved = status?['status']?.toString().toLowerCase() == 'approved';
          final target = isApproved || AppSession.currentUserVerified ? '/landlord' : '/verification_center';
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, target);
        } catch (_) {
          final fallback = AppSession.currentUserVerified ? '/landlord' : '/verification_center';
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

      AnalyticsService.logAuthEvent(AnalyticsEvents.otpVerificationFailed, method: _wasAutofilled ? 'autofill' : 'manual');

      if (mounted) {
        final message = _getFriendlyErrorMessage(error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFEF4444),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _wasAutofilled = false; 
        });
      }
    }
  }

  String _getFriendlyErrorMessage(Object error) {
    if (error is TimeoutException) return 'The connection is taking too long. Please try again.';
    if (error is SocketException || error.toString().contains('SocketException') || error.toString().contains('Connection refused')) {
      return 'We can\'t reach our servers. Please check your internet connection.';
    }
    if (error is ApiException) {
      switch (error.statusCode) {
        case 400: return 'That code isn\'t correct. Please check the code and try again.';
        case 401: return 'Your session has expired. Please log in again.';
        case 403: return 'This code has expired. Request a new code to continue.';
        case 429:
          final retryAfter = error.responseBody is Map ? error.responseBody['retryAfterSeconds'] : null;
          final seconds = int.tryParse(retryAfter?.toString() ?? '');
          if (seconds != null && seconds > 0) {
            final minutes = (seconds / 60).ceil();
            return 'A code is already active. Please wait about $minutes minute${minutes == 1 ? '' : 's'} before requesting another.';
          }
          return 'A verification code is already active. Please wait before requesting another.';
        default:
          if (error.statusCode >= 500) return 'We couldn\'t verify your code. Check your connection and try again.';
      }
    }
    return 'Verification failed. Please try again.';
  }

  Future<void> _onResend() async {
    if (_resendSeconds > 0) return;
    _otpInputKey.currentState?.clear();
    setState(() => _hasError = false);

    AnalyticsService.logAuthEvent(AnalyticsEvents.otpResendRequested, method: 'email');

    final sent = await _requestOtpCode();
    if (sent && mounted) {
      setState(() {
        _expireSeconds = 600;
        _hasError = false;
      });
      _startResendTimer();
      _expireTimer?.cancel();
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
  }

  Future<void> _leaveVerification() async {
    final email = _emailAddress;
    try {
      if (email.isNotEmpty) {
        await RemoteDatabaseRepository().revokeOtp(email);
      }
    } catch (_) {}
    if (!mounted) return;
    await AppSession.reset();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> _changeEmail() async {
    final controller = TextEditingController(text: _emailAddress);
    
    final newEmail = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Change Email', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: _dark, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text('Enter your new email address below.', style: GoogleFonts.poppins(fontSize: 14, color: _grey)),
            const SizedBox(height: 24),
            TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              validator: AuthValidators.email,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              style: GoogleFonts.poppins(fontSize: 14, color: _dark, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Email address',
                hintStyle: GoogleFonts.poppins(color: _grey, fontSize: 14),
                filled: true,
                fillColor: _bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _primary)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text('Cancel', style: GoogleFonts.poppins(color: _dark, fontWeight: FontWeight.w600)),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (AuthValidators.email(controller.text) != null) return;
                      Navigator.pop(dialogContext, controller.text.trim());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Update', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            )
          ]
        ),
      ),
    );
    
    controller.dispose();
    if (newEmail == null || !mounted || newEmail == _emailAddress) return;

    setState(() => _isSendingCode = true);
    try {
      final result = await RemoteDatabaseRepository().changeEmail(newEmail);
      final user = result?['user'];
      if (user is Map) {
        AppSession.updateCurrentUser(Map<String, dynamic>.from(user));
        await AppSession.persistSession();
      }
      if (!mounted) return;
      setState(() {
        _emailAddress = newEmail;
        _currentCode = '';
        _hasError = false;
        _expireSeconds = 600;
      });
      _otpInputKey.currentState?.clear();
      _startResendTimer();
      _expireTimer?.cancel();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New verification code sent.', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF10B981),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getFriendlyErrorMessage(error), style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFEF4444),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              
              // ─── Header & Back Button ───
              GestureDetector(
                onTap: _isVerifying ? null : _leaveVerification,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _surface, 
                    shape: BoxShape.circle, 
                    border: Border.all(color: _grey.withOpacity(0.2)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
                  ),
                  child: const Icon(PhosphorIconsRegular.caretLeft, size: 20, color: _dark),
                ),
              ),
              const SizedBox(height: 32),
              
              Text(
                'Verify your email',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please enter the 6-digit verification code sent to your email address.',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: _grey,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 24),

              // ─── Email Pill with Edit ───
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _grey.withOpacity(0.2)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    const Icon(PhosphorIconsRegular.envelopeSimple, color: _grey, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _emailAddress.isNotEmpty ? _emailAddress : 'Loading email...',
                        style: GoogleFonts.poppins(color: _dark, fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: _isSendingCode ? null : _changeEmail,
                      child: Text('Edit', style: GoogleFonts.poppins(color: _primary, fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 48),

              // ─── OTP Input ───
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
              
              const SizedBox(height: 32),

              // ─── Timers & Resend ───
              Center(
                child: Column(
                  children: [
                    Text(
                      'Code expires in ${_formatTime(_expireSeconds)}',
                      style: GoogleFonts.poppins(
                        color: _expireSeconds < 60 ? const Color(0xFFEF4444) : _grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Didn\'t receive the code? ',
                          style: GoogleFonts.poppins(
                            color: _dark,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        GestureDetector(
                          onTap: (_resendSeconds == 0 && !_isSendingCode) ? _onResend : null,
                          child: Text(
                            _resendSeconds > 0 ? 'Wait ${_resendSeconds}s' : 'Resend',
                            style: GoogleFonts.poppins(
                              color: _resendSeconds > 0 ? _grey : _primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const Spacer(),

              // ─── Actions ───
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : () => _verify(_currentCode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    disabledBackgroundColor: _grey.withOpacity(0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)), // Modern Pill
                    elevation: 0,
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(
                          'Verify Account',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Subtle Cancel Action
              Center(
                child: TextButton(
                  onPressed: _isVerifying ? null : _leaveVerification,
                  child: Text(
                    'Cancel Verification',
                    style: GoogleFonts.poppins(
                      color: _grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}