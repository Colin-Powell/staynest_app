from pathlib import Path

# patch app_session
path = Path('lib/session/app_session.dart')
text = path.read_text(encoding='utf-8')
old = "  static String currentRole = 'tenant';\n  static String? currentUserId;"
new = "  static String currentRole = 'tenant';\n  static final ValueNotifier<String> currentRoleNotifier = ValueNotifier(currentRole);\n\n  static void setRole(String role) {\n    currentRole = role;\n    currentRoleNotifier.value = role;\n  }\n\n  static String? currentUserId;"
if old not in text:
    raise SystemExit('app_session block not found')
text = text.replace(old, new)
path.write_text(text, encoding='utf-8')
print('patched app_session')

# patch theme.dart
path = Path('lib/theme.dart')
text = path.read_text(encoding='utf-8')
if "import 'session/app_session.dart';" not in text:
    text = text.replace("import 'package:flutter/material.dart';\n\n", "import 'package:flutter/material.dart';\nimport 'session/app_session.dart';\n\n")
old = "abstract class AppColors {\n  static const primary = StayNestColors.primary;\n  static const primaryLight = StayNestColors.primaryLight;\n  static const background = StayNestColors.backgroundLight;\n  static const white = Color(0xFFFFFFFF);"
new = "abstract class AppColors {\n  static Color get primary => AppSession.isLandlord ? const Color(0xFF059669) : StayNestColors.primary;\n  static Color get primaryLight => AppSession.isLandlord ? const Color(0xFFDDF6E8) : StayNestColors.primaryLight;\n  static Color get background => AppSession.isLandlord ? const Color(0xFFE8F6EF) : StayNestColors.backgroundLight;\n  static const Color white = Color(0xFFFFFFFF);"
if old not in text:
    raise SystemExit('AppColors block not found')
text = text.replace(old, new)
path.write_text(text, encoding='utf-8')
print('patched theme')

# patch app_theme.dart
path = Path('lib/app_theme.dart')
text = path.read_text(encoding='utf-8')
if 'static ThemeData get light => _build(Brightness.light);' not in text or 'static ThemeData get dark => _build(Brightness.dark);' not in text:
    raise SystemExit('AppTheme getters not found')
text = text.replace('  static ThemeData get light => _build(Brightness.light);\n  static ThemeData get dark => _build(Brightness.dark);', '  static ThemeData get light => themeForRole(AppSession.currentRole);\n  static ThemeData get dark => themeForRole(AppSession.currentRole);\n  static ThemeData themeForRole(String role) => _build(Brightness.light, role);')
if 'static ThemeData _build(Brightness brightness) {' not in text:
    raise SystemExit('AppTheme _build signature not found')
text = text.replace('static ThemeData _build(Brightness brightness) {', 'static ThemeData _build(Brightness brightness, String role) {')
text = text.replace('final isDark = brightness == Brightness.dark;\n\n    final colorScheme = isDark ? _darkScheme : _lightScheme;', 'final isDark = brightness == Brightness.dark;\n\n    final colorScheme = role.contains(\'landlord\') ? _landlordScheme : _lightScheme;')
if 'static const _landlordScheme =' not in text:
    insert_at = text.index('static const _darkScheme = ColorScheme.dark(')
    theme_def = "\n  static const _landlordScheme = ColorScheme.light(\n    brightness: Brightness.light,\n    primary: Color(0xFF059669),\n    onPrimary: Colors.white,\n    primaryContainer: Color(0xFFD8F6E3),\n    onPrimaryContainer: Color(0xFF054E2C),\n    secondary: Color(0xFF22C55E),\n    onSecondary: Colors.white,\n    secondaryContainer: Color(0xFFE6F9EA),\n    onSecondaryContainer: Color(0xFF0F3F1D),\n    tertiary: Color(0xFF4A7B6D),\n    onTertiary: Colors.white,\n    surface: Colors.white,\n    onSurface: Color(0xFF0F172A),\n    background: Color(0xFFE8F6EF),\n    onBackground: Color(0xFF0F172A),\n    error: Color(0xFFEF4444),\n    onError: Colors.white,\n    surfaceVariant: Color(0xFFF0F8F1),\n    onSurfaceVariant: Color(0xFF4B5563),\n    outline: Color(0xFF9CA3AF),\n    shadow: Colors.black,\n    inverseSurface: Color(0xFF0F172A),\n    onInverseSurface: Colors.white,\n    inversePrimary: Color(0xFF7EE2B8),\n  );\n\n"
    text = text[:insert_at] + theme_def + text[insert_at:]
if "import 'package:property_app/session/app_session.dart';" not in text:
    text = text.replace("import 'package:flutter/services.dart';\nimport 'theme.dart';", "import 'package:flutter/services.dart';\nimport 'package:property_app/session/app_session.dart';\nimport 'theme.dart';")
path.write_text(text, encoding='utf-8')
print('patched app_theme')

# patch main.dart
path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
if 'class PropertyApp extends StatelessWidget {' in text:
    text = text.replace('class PropertyApp extends StatelessWidget {', 'class PropertyApp extends StatefulWidget {')
    text = text.replace('  const PropertyApp({super.key});\n\n  @override\n  Widget build(BuildContext context) {', '  const PropertyApp({super.key});\n\n  @override\n  State<PropertyApp> createState() => _PropertyAppState();\n}\n\nclass _PropertyAppState extends State<PropertyApp> {\n  late String _role;\n\n  @override\n  void initState() {\n    super.initState();\n    _role = AppSession.currentRole;\n    AppSession.currentRoleNotifier.addListener(_handleRoleChange);\n  }\n\n  @override\n  void dispose() {\n    AppSession.currentRoleNotifier.removeListener(_handleRoleChange);\n    super.dispose();\n  }\n\n  void _handleRoleChange() {\n    if (mounted) {\n      setState(() {\n        _role = AppSession.currentRole;\n      });\n    }\n  }\n\n  @override\n  Widget build(BuildContext context) {')
if 'theme: ThemeData(\n        useMaterial3: true,\n        colorScheme: ColorScheme.fromSeed(\n          seedColor: AppColors.primary,\n          primary: AppColors.primary,\n        ),\n        scaffoldBackgroundColor: AppColors.background,\n        splashFactory: NoSplash.splashFactory,\n        highlightColor: Colors.transparent,\n      ),' in text:
    text = text.replace('theme: ThemeData(\n        useMaterial3: true,\n        colorScheme: ColorScheme.fromSeed(\n          seedColor: AppColors.primary,\n          primary: AppColors.primary,\n        ),\n        scaffoldBackgroundColor: AppColors.background,\n        splashFactory: NoSplash.splashFactory,\n        highlightColor: Colors.transparent,\n      ),', 'theme: AppTheme.themeForRole(_role),')
else:
    raise SystemExit('theme block not found')
if "AppSession.currentRole = r;" in text:
    text = text.replace("AppSession.currentRole = r;", "AppSession.setRole(r);")
path.write_text(text, encoding='utf-8')
print('patched main')

# patch home_view.dart
path = Path('lib/screens/home/home_view.dart')
text = path.read_text(encoding='utf-8')
if 'const _primary = Color(0xFF3B46F1);' in text:
    text = text.replace('const _primary = Color(0xFF3B46F1);\n', '')
    text = text.replace('_primary', 'AppColors.primary')
    if "import 'package:property_app/theme.dart';" not in text:
        text = text.replace("import 'package:flutter/material.dart';\n", "import 'package:flutter/material.dart';\nimport 'package:property_app/theme.dart';\n")
    path.write_text(text, encoding='utf-8')
    print('patched home_view')
else:
    print('home_view not patched, no local primary')
