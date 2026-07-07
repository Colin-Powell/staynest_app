import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/api_client.dart';

class OtpView extends StatefulWidget {
  const OtpView({super.key});

  @override
  State<OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<OtpView> with SingleTickerProviderStateMixin {
  // Exact design colors based on the screenshot
  static const _primary = Color(0xFF3D36E8);
  static const _border = Color(0xFFE4E6EF);
  static const _text = Color(0xFF14162C);
  static const _hint = Color(0xFF9395A5);

  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _hasError = false;
  bool _isVerifying = false;
  bool _isSendingCode = false;
  int _remainingSeconds = 30;
  Timer? _timer;
  String _emailAddress = '';

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
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
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));

    _emailAddress = AppSession.currentUserEmail?.trim() ?? '';
    _startCountdown();
    unawaited(_requestOtpCode());

    for (final focusNode in _focusNodes) {
      focusNode.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _remainingSeconds = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds == 0) {
        timer.cancel();
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _timer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _resetError() {
    if (_hasError) {
      setState(() => _hasError = false);
    }
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
                'We could not resend the verification code. Please try again.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFFE53935),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _verify() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length < 6) return;

    setState(() {
      _hasError = false;
      _isVerifying = true;
    });

    try {
      final repository = RemoteDatabaseRepository();
      final result = await repository.verifyPhoneCode(code);
      if (result == null) {
        throw Exception('Verification failed.');
      }

      AppSession.currentUserVerified = true;
      await AppSession.persistSession();

      if (!mounted) return;
      // Role-based routing after verification
      if (AppSession.isLandlord) {
        // Landlord: always continue to the verification center after phone OTP
        Navigator.pushReplacementNamed(context, '/verification_center');
      } else {
        // Tenant: route to home
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (error) {
      setState(() {
        _hasError = true;
      });
      _shakeController.forward(from: 0);

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
        setState(() => _isVerifying = false);
      }
    }
  }

  String _getFriendlyErrorMessage(Object error) {
    if (error is TimeoutException) {
      return 'The connection is taking too long. Please try again.';
    }
    if (error is SocketException ||
        error.toString().contains('SocketException') ||
        error.toString().contains('Connection refused')) {
      return 'We can\'t reach our servers. Please check your internet connection.';
    }
    if (error is ApiException) {
      switch (error.statusCode) {
        case 400:
          return 'The code you entered is invalid. Please double check and try again.';
        case 401:
          return 'Your session has expired. Please log in again.';
        case 403:
          return 'This code is incorrect or has already expired.';
        case 429:
          return 'Too many attempts. Please wait a bit before trying again.';
        default:
          if (error.statusCode >= 500) {
            return 'Our server is having a moment. Please try again in a few minutes.';
          }
      }
    }
    return 'Verification failed. Please try again.';
  }

  Future<void> _onResend() async {
    if (_remainingSeconds > 0) return;
    for (final controller in _controllers) {
      controller.clear();
    }
    _resetError();
    _startCountdown();
    await _requestOtpCode();
    _focusNodes[0].requestFocus();
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 52, // Perfectly scaled box width
      height: 64, // Taller structure mirroring the screenshot
      child: KeyboardListener(
        focusNode:
            FocusNode(skipTraversal: true), // Catch raw backspace keys safely
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _controllers[index].text.isEmpty &&
              index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 26, // Large, clean, elegant font weight
            fontWeight: FontWeight.w700,
            color: _text,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _hasError ? Colors.red : _border,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _hasError ? Colors.red : _primary,
                width: 2.0,
              ),
            ),
          ),
          onChanged: (value) {
            _resetError();
            if (value.isNotEmpty) {
              if (index < _controllers.length - 1) {
                _focusNodes[index + 1].requestFocus();
              } else {
                _focusNodes[index].unfocus();
                _verify(); // Auto-trigger verification once entry finishes
              }
            }
            setState(() {});
          },
        ),
      ),
    );
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
              // Accurate Back Arrow Icon
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: const Icon(
                  Icons.arrow_back,
                  size: 28,
                  color: _text,
                ),
              ),
              const SizedBox(height: 36),
              Text(
                'Verify Your Email',
                style: GoogleFonts.poppins(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: _text,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Enter the 6 digit code sent to:',
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
              // Input Box row layout containing modern spacing padding rules
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_controllers.length, (index) {
                        return _buildOtpBox(index);
                      }),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              Center(
                child: TextButton(
                  onPressed: (_remainingSeconds == 0 && !_isSendingCode)
                      ? _onResend
                      : null,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(1, 1),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _remainingSeconds > 0
                        ? 'Resend code in 00:${_remainingSeconds.toString().padLeft(2, '0')}'
                        : 'Resend code',
                    style: GoogleFonts.poppins(
                      color: _remainingSeconds > 0 ? _hint : _primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Styled Accent Bottom Verify Button Block
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verify,
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
