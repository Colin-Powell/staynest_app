import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  StayNest — AppTheme
//  Centralises ThemeData construction. Use AppTheme.light in MaterialApp.
//
//  Usage:
//    MaterialApp(
//      theme: AppTheme.light,
//      darkTheme: AppTheme.dark,
//      ...
//    )
// ─────────────────────────────────────────────────────────────────────────────

abstract class AppTheme {
  // ── Public entry-points ──────────────────────────────────────────────────

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  // ── Core builder ────────────────────────────────────────────────────────

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = isDark ? _darkScheme : _lightScheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,

      // ── Typography ──────────────────────────────────────────────
      fontFamily: 'Poppins',
      textTheme: GoogleFonts.poppinsTextTheme(_textTheme(colorScheme)),

      // ── Scaffold ────────────────────────────────────────────────
      scaffoldBackgroundColor: colorScheme.surface,

      // ── AppBar ──────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          color: colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),

      // ── ElevatedButton ──────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: StayNestColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: StayNestColors.primary.withOpacity(0.4),
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // ── OutlinedButton ──────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: StayNestColors.primary,
          side: const BorderSide(color: StayNestColors.primary, width: 1.5),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // ── TextButton ──────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: StayNestColors.primary,
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // ── InputDecoration (text fields) ────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? StayNestColors.surfaceVariantDark
            : StayNestColors.surfaceVariantLight,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(
            color: isDark
                ? StayNestColors.outlineDark
                : StayNestColors.outlineLight,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide:
              const BorderSide(color: StayNestColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: colorScheme.error, width: 1.8),
        ),
        hintStyle: TextStyle(
          color: isDark
              ? StayNestColors.textMutedDark
              : StayNestColors.textMutedLight,
          fontSize: 14.5,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: TextStyle(
          color: isDark
              ? StayNestColors.textSecondaryDark
              : StayNestColors.textSecondaryLight,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: StayNestColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),

      // ── Card ─────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: isDark ? StayNestColors.cardDark : StayNestColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: isDark
                ? StayNestColors.outlineDark
                : StayNestColors.outlineLight,
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── BottomNavigationBar ──────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: StayNestColors.primary,
        unselectedItemColor: isDark
            ? StayNestColors.textMutedDark
            : StayNestColors.textMutedLight,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),

      // ── Chip ─────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? StayNestColors.surfaceVariantDark
            : StayNestColors.surfaceVariantLight,
        selectedColor: StayNestColors.primaryLight,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDark
              ? StayNestColors.textPrimaryDark
              : StayNestColors.textPrimaryLight,
        ),
        side: BorderSide(
          color:
              isDark ? StayNestColors.outlineDark : StayNestColors.outlineLight,
          width: 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // ── Divider ──────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color:
            isDark ? StayNestColors.outlineDark : StayNestColors.outlineLight,
        thickness: 1,
        space: 1,
      ),

      // ── FloatingActionButton ─────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: StayNestColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // ── SnackBar ─────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDark ? StayNestColors.cardDark : StayNestColors.textPrimaryLight,
        contentTextStyle: TextStyle(
          color: isDark ? StayNestColors.textPrimaryDark : Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),

      // ── ListTile ─────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        iconColor: isDark
            ? StayNestColors.textSecondaryDark
            : StayNestColors.textSecondaryLight,
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDark
              ? StayNestColors.textPrimaryDark
              : StayNestColors.textPrimaryLight,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 13,
          color: isDark
              ? StayNestColors.textMutedDark
              : StayNestColors.textMutedLight,
        ),
      ),
    );
  }

  // ── Color schemes ────────────────────────────────────────────────────────

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: StayNestColors.primary,
    onPrimary: Colors.white,
    primaryContainer: StayNestColors.primaryLight,
    onPrimaryContainer: StayNestColors.primaryDark,
    secondary: StayNestColors.accent,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFFFF3E0),
    onSecondaryContainer: Color(0xFF7A4100),
    surface: Color(0xFFFFFFFF),
    onSurface: StayNestColors.textPrimaryLight,
    surfaceContainerHighest: Color(0xFFF5F5F5),
    onSurfaceVariant: StayNestColors.textSecondaryLight,
    outline: StayNestColors.outlineLight,
    outlineVariant: Color(0xFFE5E7EB),
    error: Color(0xFFDC2626),
    onError: Colors.white,
    errorContainer: Color(0xFFFFEDED),
    onErrorContainer: Color(0xFF7F1D1D),
    shadow: Color(0x1A000000),
    scrim: Color(0x80000000),
    inverseSurface: Color(0xFF1C1C1E),
    onInverseSurface: Color(0xFFF5F5F5),
    inversePrimary: Color(0xFF8B8DFF),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF8B8DFF),
    onPrimary: Color(0xFF0D0D2B),
    primaryContainer: Color(0xFF1E1F5E),
    onPrimaryContainer: Color(0xFFCCCDFF),
    secondary: Color(0xFFFFB74D),
    onSecondary: Color(0xFF3D1F00),
    secondaryContainer: Color(0xFF5C3000),
    onSecondaryContainer: Color(0xFFFFDDB3),
    surface: StayNestColors.backgroundDark,
    onSurface: StayNestColors.textPrimaryDark,
    surfaceContainerHighest: Color(0xFF1E2534),
    onSurfaceVariant: StayNestColors.textSecondaryDark,
    outline: StayNestColors.outlineDark,
    outlineVariant: Color(0xFF2B3F55),
    error: Color(0xFFFF6B6B),
    onError: Color(0xFF4A0000),
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: Color(0xFFFFCDD2),
    shadow: Color(0x40000000),
    scrim: Color(0x80000000),
    inverseSurface: Color(0xFFF4F1EC),
    onInverseSurface: Color(0xFF0D1B2A),
    inversePrimary: StayNestColors.primary,
  );

  // ── TextTheme ────────────────────────────────────────────────────────────

  static TextTheme _textTheme(ColorScheme cs) {
    final primary = cs.onSurface;
    final secondary = cs.onSurfaceVariant;

    return TextTheme(
      // Display
      displayLarge: _ts(57, FontWeight.w900, primary, -1.5),
      displayMedium: _ts(45, FontWeight.w800, primary, -1.0),
      displaySmall: _ts(36, FontWeight.w800, primary, -0.8),
      // Headline
      headlineLarge: _ts(32, FontWeight.w700, primary, -0.5),
      headlineMedium: _ts(28, FontWeight.w700, primary, -0.4),
      headlineSmall: _ts(24, FontWeight.w700, primary, -0.3),
      // Title
      titleLarge: _ts(20, FontWeight.w700, primary, -0.2),
      titleMedium: _ts(16, FontWeight.w600, primary, 0.1),
      titleSmall: _ts(14, FontWeight.w600, primary, 0.1),
      // Body
      bodyLarge: _ts(16, FontWeight.w400, primary, 0.1),
      bodyMedium: _ts(14, FontWeight.w400, secondary, 0.1),
      bodySmall: _ts(12, FontWeight.w400, secondary, 0.2),
      // Label
      labelLarge: _ts(14, FontWeight.w600, primary, 0.3),
      labelMedium: _ts(12, FontWeight.w600, secondary, 0.4),
      labelSmall: _ts(11, FontWeight.w500, secondary, 0.5),
    );
  }

  static TextStyle _ts(
    double size,
    FontWeight weight,
    Color color,
    double spacing,
  ) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
        height: 1.4,
        fontFamily: 'Poppins',
      );
}
