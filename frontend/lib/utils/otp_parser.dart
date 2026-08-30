class OtpParser {
  static final RegExp _otpRegex = RegExp(r'\b\d{6}\b');
  
  static String? extractOtp(String? text) {
    if (text == null) return null;
    final match = _otpRegex.firstMatch(text);
    return match?.group(0);
  }
}
