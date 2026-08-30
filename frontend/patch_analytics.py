import re

with open('lib/services/analytics/analytics_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = """class AnalyticsEvents {
  static const String signUp = 'sign_up';"""

replacement = """class AnalyticsEvents {
  static const String otpScreenViewed = 'otp_screen_viewed';
  static const String otpVerificationStarted = 'otp_verification_started';
  static const String otpVerificationSuccess = 'otp_verification_success';
  static const String otpVerificationFailed = 'otp_verification_failed';
  static const String otpResendRequested = 'otp_resend_requested';
  static const String otpAutofillUsed = 'otp_autofill_used';
  static const String otpManualEntryUsed = 'otp_manual_entry_used';

  static const String signUp = 'sign_up';"""

content = content.replace(target, replacement)

with open('lib/services/analytics/analytics_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated analytics_service.dart")
