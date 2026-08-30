import re

with open(r'lib/screens/auth/otp_view.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove _requestOtpCode from initState
target_init = """    AnalyticsService.logAuthEvent(AnalyticsEvents.otpScreenViewed, method: 'email');
    
    _startTimers();
    unawaited(_requestOtpCode());"""
replacement_init = """    AnalyticsService.logAuthEvent(AnalyticsEvents.otpScreenViewed, method: 'email');
    
    // START WITH RESEND ACTIVE SO USER CONTROLS THE SEND IF NEEDED
    _resendSeconds = 0;
    _expireSeconds = 600;
    _expireTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_expireSeconds > 0) {
        setState(() => _expireSeconds--);
      } else {
        timer.cancel();
        _handleExpiration();
      }
    });"""
content = content.replace(target_init, replacement_init)

# 2. Modify _startTimers to only start resend timer when actually requested
target_timers = """  void _startTimers() {
    _resendTimer?.cancel();
    _expireTimer?.cancel();
    
    _resendSeconds = 30;
    _expireSeconds = 600;
    
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
    
    _expireTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_expireSeconds > 0) {
        setState(() => _expireSeconds--);
      } else {
        timer.cancel();
        _handleExpiration();
      }
    });
  }"""
replacement_timers = """  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendSeconds = 30;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }"""
content = content.replace(target_timers, replacement_timers)

# 3. Update _onResend to use _startResendTimer
target_onresend = """  Future<void> _onResend() async {
    if (_resendSeconds > 0) return;
    _otpInputKey.currentState?.clear();
    setState(() => _hasError = false);
    
    AnalyticsService.logAuthEvent(AnalyticsEvents.otpResendRequested);
    
    _startTimers();
    await _requestOtpCode();
  }"""
replacement_onresend = """  Future<void> _onResend() async {
    if (_resendSeconds > 0) return;
    _otpInputKey.currentState?.clear();
    setState(() => _hasError = false);
    
    AnalyticsService.logAuthEvent(AnalyticsEvents.otpResendRequested);
    
    _startResendTimer();
    await _requestOtpCode();
  }"""
content = content.replace(target_onresend, replacement_onresend)

with open(r'lib/screens/auth/otp_view.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated OTP View")
