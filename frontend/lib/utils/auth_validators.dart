class AuthValidators {
  static final RegExp _namePattern = RegExp(r"^[\p{L}][\p{L} .'-]{1,79}$", unicode: true);
  static final RegExp _emailPattern = RegExp(
    r'^[A-Z0-9.!#$%&\'*+/=?^_`{|}~-]+@[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?(?:\.[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?)+$',
    caseSensitive: false,
  );
  static final RegExp _phonePattern = RegExp(r'^(?:\+254|0)(?:7|1)\d{8}$');
  static final RegExp _uppercasePattern = RegExp(r'[A-Z]');
  static final RegExp _lowercasePattern = RegExp(r'[a-z]');
  static final RegExp _digitPattern = RegExp(r'\d');
  static final RegExp _specialPattern = RegExp(r'[^A-Za-z0-9]');

  static String? name(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Enter your full name';
    if (!_namePattern.hasMatch(name) || !name.contains(RegExp(r'\s'))) {
      return 'Enter a valid full name';
    }
    return null;
  }

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email';
    if (email.length > 254 || !_emailPattern.hasMatch(email)) {
      return 'Enter a valid email';
    }
    return null;
  }

  static String? phone(String? value) {
    final phone = value?.trim().replaceAll(RegExp(r'[\s()-]'), '') ?? '';
    if (phone.isEmpty) return 'Enter your phone number';
    if (!_phonePattern.hasMatch(phone)) {
      return 'Use a valid Kenyan number, e.g. 0712345678';
    }
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.length < 8) return 'Password must be at least 8 characters';
    if (!_uppercasePattern.hasMatch(password) ||
        !_lowercasePattern.hasMatch(password) ||
        !_digitPattern.hasMatch(password) ||
        !_specialPattern.hasMatch(password)) {
      return 'Use upper, lower, number and special character';
    }
    return null;
  }
}
