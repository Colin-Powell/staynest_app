import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/session/app_session.dart';
import 'theme.dart';

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

  static ThemeData get light => themeForRole(AppSession.currentRole);
  static ThemeData get dark => themeForRole(AppSession.currentRole);
  static ThemeData themeForRole(String role) => _build(Brightness.light, role);

  // ── Legacy palette aliases for existing screen styles ────────────────────

  static const Color accent = StayNestColors.accent;
  static Color get background => AppColors.background;
  static const Color border = StayNestColors.outlineLight;
  static const Color borderMid = Color(0xFFD1D5DB);
  static const Color green = StayNestColors.success;
  static const Color greenLight = StayNestColors.successLight;
  static const Color greenText = StayNestColors.success;
  static const Color orange = StayNestColors.warning;
  static Color get primary => AppColors.primary;
  static Color get primaryLight => AppColors.primaryLight;
  static const Color textMuted = StayNestColors.textMutedLight;
  static const Color textPrimary = StayNestColors.textPrimaryLight;
  static const Color textSecondary = StayNestColors.textSecondaryLight;

  // ── Core builder ────────────────────────────────────────────────────────

  static ThemeData _build(Brightness brightness, String role) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = isDark
        ? _darkScheme(role)
        : role.contains('landlord')
            ? _landlordScheme
            : _lightScheme(role);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,

      // ── Typography ──────────────────────────────────────────────────────
      fontFamily: 'Poppins',
      textTheme: GoogleFonts.poppinsTextTheme(_textTheme(colorScheme)),

      // ── Scaffold ────────────────────────────────────────────────────────
      scaffoldBackgroundColor: colorScheme.surface,

      // ── AppBar ─────────────────────────────────────────────────────────
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

      // ── ElevatedButton ──────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
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

      // ── OutlinedButton ──────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary, width: 1.5),
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

      // ── TextButton ──────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // ── InputDecoration (text fields) ────────────────────────────────────
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
          borderSide: BorderSide(color: AppColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: colorScheme.error, width: 1.8),
        ),
        hintStyle: GoogleFonts.poppins(
          color: isDark
              ? StayNestColors.textMutedDark
              : StayNestColors.textMutedLight,
          fontSize: 14.5,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: GoogleFonts.poppins(
          color: isDark
              ? StayNestColors.textSecondaryDark
              : StayNestColors.textSecondaryLight,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: GoogleFonts.poppins(
          color: AppColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),

      // ── Card ─────────────────────────────────────────────────────────────
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

      // ── BottomNavigationBar ─────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: isDark
            ? StayNestColors.textMutedDark
            : StayNestColors.textMutedLight,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),

      // ── Chip ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? StayNestColors.surfaceVariantDark
            : StayNestColors.surfaceVariantLight,
        selectedColor: AppColors.primaryLight,
        labelStyle: GoogleFonts.poppins(
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    final primaryColor = scheme.onSurface;
    final secondaryColor = scheme.onSurface.withOpacity(0.78);

    return ThemeData.light().textTheme.copyWith(
          // Hero / Primary display used on HomeView
          displayLarge: GoogleFonts.poppins(
            color: primaryColor,
            fontSize: 36,
            fontWeight: FontWeight.w800,
          ),
          displayMedium: GoogleFonts.poppins(
            color: primaryColor,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
          displaySmall: GoogleFonts.poppins(
            color: primaryColor,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
          // Section headings (e.g., 'Nearby You', 'Recommended For You')
          headlineLarge: GoogleFonts.poppins(
            color: primaryColor,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: GoogleFonts.poppins(
            color: primaryColor,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: GoogleFonts.poppins(
            color: primaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          // Titles used for greeting and medium-sized labels
          titleLarge: GoogleFonts.poppins(
            color: primaryColor,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: GoogleFonts.poppins(
            color: primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          titleSmall: GoogleFonts.poppins(
            color: primaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          // Body text matching HomeView (search input, card bodies)
          bodyLarge: GoogleFonts.poppins(
            color: primaryColor,
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
          bodyMedium: GoogleFonts.poppins(
            color: secondaryColor,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
          bodySmall: GoogleFonts.poppins(
            color: secondaryColor,
            fontSize: 12,
            height: 1.3,
            fontWeight: FontWeight.w400,
          ),
          labelLarge: GoogleFonts.poppins(
            color: primaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          labelSmall: GoogleFonts.poppins(
            color: secondaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        );
  }

  static ColorScheme _lightScheme(String role) => ColorScheme.light(
        primary: AppColors.primary,
        secondary: StayNestColors.accent,
        surface: StayNestColors.surfaceLight,
        error: StayNestColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: StayNestColors.textPrimaryLight,
        onError: Colors.white,
      );

  static const _landlordScheme = ColorScheme.light(
    brightness: Brightness.light,
    primary: Color(0xFF059669),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFD8F6E3),
    onPrimaryContainer: Color(0xFF054E2C),
    secondary: Color(0xFF22C55E),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE6F9EA),
    onSecondaryContainer: Color(0xFF0F3F1D),
    tertiary: Color(0xFF4A7B6D),
    onTertiary: Colors.white,
    surface: Color(0xFFE8F6EF),
    onSurface: Color(0xFF0F172A),
    error: Color(0xFFEF4444),
    onError: Colors.white,
    surfaceContainerHighest: Color(0xFFF0F8F1),
    onSurfaceVariant: Color(0xFF4B5563),
    outline: Color(0xFF9CA3AF),
    shadow: Colors.black,
    inverseSurface: Color(0xFF0F172A),
    onInverseSurface: Colors.white,
    inversePrimary: Color(0xFF7EE2B8),
  );

  static ColorScheme _darkScheme(String role) => ColorScheme.dark(
        primary: AppColors.primary,
        secondary: StayNestColors.accent,
        surface: StayNestColors.surfaceDark,
        error: StayNestColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: StayNestColors.textPrimaryDark,
        onError: Colors.white,
      );
}
