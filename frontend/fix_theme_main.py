from pathlib import Path

# Fix app_theme with dynamic schemes and const removal
path = Path('lib/app_theme.dart')
text = path.read_text(encoding='utf-8')

light_old = '''  static const _lightScheme = ColorScheme.light(
    primary: AppColors.primary,
    secondary: StayNestColors.accent,
    surface: StayNestColors.surfaceLight,
    error: StayNestColors.error,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: StayNestColors.textPrimaryLight,
    onError: Colors.white,
  );
'''
light_new = '''  static ColorScheme _lightScheme(String role) => ColorScheme.light(
    primary: AppColors.primary,
    secondary: StayNestColors.accent,
    surface: StayNestColors.surfaceLight,
    error: StayNestColors.error,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: StayNestColors.textPrimaryLight,
    onError: Colors.white,
  );
'''
if light_old in text:
    text = text.replace(light_old, light_new)
else:
    print('WARNING: light scheme pattern not found')


dark_old = '''static const _darkScheme = ColorScheme.dark(
    primary: AppColors.primary,
    secondary: StayNestColors.accent,
    surface: StayNestColors.surfaceDark,
    error: StayNestColors.error,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: StayNestColors.textPrimaryDark,
    onError: Colors.white,
  );'''
dark_new = '''static ColorScheme _darkScheme(String role) => ColorScheme.dark(
    primary: AppColors.primary,
    secondary: StayNestColors.accent,
    surface: StayNestColors.surfaceDark,
    error: StayNestColors.error,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: StayNestColors.textPrimaryDark,
    onError: Colors.white,
  );'''
if dark_old in text:
    text = text.replace(dark_old, dark_new)
else:
    print('WARNING: dark scheme pattern not found')

if "final colorScheme = role.contains('landlord') ? _landlordScheme : _lightScheme;" in text:
    text = text.replace("final colorScheme = role.contains('landlord') ? _landlordScheme : _lightScheme;", "final colorScheme = isDark ? _darkScheme(role) : role.contains('landlord') ? _landlordScheme : _lightScheme(role);")
else:
    print('WARNING: build colorScheme selection not found')

path.write_text(text, encoding='utf-8')
print('patched app_theme schemes')

# fix main.dart import for AppTheme
path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
if "import 'package:property_app/session/app_session.dart';" in text and "import 'package:property_app/app_theme.dart';" not in text:
    text = text.replace("import 'package:property_app/session/app_session.dart';\n", "import 'package:property_app/session/app_session.dart';\nimport 'package:property_app/app_theme.dart';\n")
path.write_text(text, encoding='utf-8')
print('patched main import')
