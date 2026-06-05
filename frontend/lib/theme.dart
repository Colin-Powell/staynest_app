import 'package:flutter/material.dart';
import 'session/app_session.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  StayNest — theme.dart
//  Single source of truth for every design token used across the app.
//
//  Import this file wherever you need colors, spacing, radius, or shadows.
//  Never hard-code hex values outside this file.
// ─────────────────────────────────────────────────────────────────────────────

// ─── Color palette ───────────────────────────────────────────────────────────

abstract class StayNestColors {
  // ── Brand primaries ───────────────────────────────────────────
  /// Primary indigo — buttons, active dots, links, focused borders
  static const primary = Color(0xFF3D3EDB);
  static const primaryLight = Color(0xFFEEEEFC); // tinted bg, chip selected
  static const primaryDark = Color(0xFF1A1BAA); // pressed states

  /// Accent amber — location pin, door, highlights, warm accents
  static const accent = Color(0xFFE8A94D);
  static const accentLight = Color(0xFFFFF3E0);
  static const accentDark = Color(0xFFB47D2A);

  /// Teal — used in splash/dark theme only; not in onboarding light screens
  static const teal = Color(0xFF2BBFB3);
  static const tealLight = Color(0xFFE0F7F5);

  // ── Semantic ──────────────────────────────────────────────────
  static const success = Color(0xFF16A34A);
  static const successLight = Color(0xFFDCFCE7);
  static const warning = Color(0xFFD97706);
  static const warningLight = Color(0xFFFEF3C7);
  static const error = Color(0xFFDC2626);
  static const errorLight = Color(0xFFFFEDED);
  static const info = Color(0xFF0EA5E9);
  static const infoLight = Color(0xFFE0F2FE);

  // ── Light surface tokens ──────────────────────────────────────
  static const backgroundLight = Color(0xFFFFFFFF);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceVariantLight = Color(0xFFF9FAFB);
  static const cardLight = Color(0xFFFFFFFF);
  static const outlineLight = Color(0xFFE5E7EB);

  // ── Dark surface tokens ───────────────────────────────────────
  static const backgroundDark = Color(0xFF0D1B2A); // splash bg
  static const surfaceDark = Color(0xFF0D1B2A);
  static const surfaceVariantDark = Color(0xFF162236);
  static const cardDark = Color(0xFF162236);
  static const outlineDark = Color(0xFF2B3F55);

  // ── Text — light mode ─────────────────────────────────────────
  static const textPrimaryLight = Color(0xFF0D0D0D);
  static const textSecondaryLight = Color(0xFF4B5563);
  static const textMutedLight = Color(0xFF8C8C9A);
  static const textDisabledLight = Color(0xFFD1D5DB);

  // ── Text — dark mode ──────────────────────────────────────────
  static const textPrimaryDark = Color(0xFFF4F1EC);
  static const textSecondaryDark = Color(0xFF8FA3B8);
  static const textMutedDark = Color(0xFF6B7D8F);
  static const textDisabledDark = Color(0xFF3A4F63);

  // ── Miscellaneous ─────────────────────────────────────────────
  static const divider = Color(0xFFE5E7EB);
  static const dividerDark = Color(0xFF2B3F55);
  static const shimmerBase = Color(0xFFF3F3F3);
  static const shimmerHigh = Color(0xFFE8E8E8);
  static const overlay = Color(0x80000000);
  static const overlayLight = Color(0x1A000000);
}

// ─── Spacing scale (8pt grid) ────────────────────────────────────────────────

abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
  static const double epic = 64;

  /// Standard horizontal page padding (matches design: 24–28px)
  static const double pagePadH = 24;
  static const double pagePadV = 28;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: pagePadH,
    vertical: pagePadV,
  );

  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(
    horizontal: pagePadH,
  );

  static const EdgeInsets cardPadding = EdgeInsets.all(base);
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: pagePadH,
    vertical: md,
  );
}

// ─── Border radius ───────────────────────────────────────────────────────────

abstract class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double card = 16;
  static const double input = 14;
  static const double button = 16;
  static const double chip = 20;
  static const double image = 20;
  static const double dialog = 24;
  static const double full = 999; // pill / circle

  static const cardBorderRadius = BorderRadius.all(Radius.circular(card));
  static const buttonBorderRadius = BorderRadius.all(Radius.circular(button));
  static const inputBorderRadius = BorderRadius.all(Radius.circular(input));
  static const chipBorderRadius = BorderRadius.all(Radius.circular(chip));
  static const imageBorderRadius = BorderRadius.all(Radius.circular(image));
  static const dialogBorderRadius = BorderRadius.all(Radius.circular(dialog));
}

// ─── Elevation / shadow presets ──────────────────────────────────────────────

abstract class AppShadow {
  /// Soft card lift
  static List<BoxShadow> get sm => [
        const BoxShadow(
          color: StayNestColors.overlayLight,
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ];

  /// Standard card shadow
  static List<BoxShadow> get md => [
        const BoxShadow(
          color: Color(0x14000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ];

  /// Elevated panel / modal
  static List<BoxShadow> get lg => [
        const BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 32,
          offset: Offset(0, 8),
        ),
      ];

  /// Primary button glow
  static List<BoxShadow> get primaryGlow => [
        BoxShadow(
          color: StayNestColors.primary.withOpacity(0.32),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  /// Accent/amber glow (location pins, highlights)
  static List<BoxShadow> get accentGlow => [
        BoxShadow(
          color: StayNestColors.accent.withOpacity(0.30),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];
}

// ─── Duration constants ──────────────────────────────────────────────────────

abstract class AppDuration {
  static const press = Duration(milliseconds: 80);
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slide = Duration(milliseconds: 380);
  static const slow = Duration(milliseconds: 500);
  static const verySlow = Duration(milliseconds: 700);
  static const float = Duration(seconds: 3); // looping animations
}

// ─── Animation curves ────────────────────────────────────────────────────────

abstract class AppCurve {
  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeIn;
  static const inOut = Curves.easeInOut;
  static const spring = Curves.elasticOut;
  static const bounce = Curves.bounceOut;
  static const smooth = Curves.fastOutSlowIn;
}

// ─── Typography helpers ──────────────────────────────────────────────────────
//
//  These are raw TextStyle presets independent of ThemeData.
//  Use Theme.of(context).textTheme when inside a widget tree.
//  Use these for CustomPaint labels or contexts without a BuildContext.

abstract class AppTextStyle {
  // Display
  static const display1 = TextStyle(
      fontSize: 40,
      fontWeight: FontWeight.w900,
      color: StayNestColors.textPrimaryLight,
      letterSpacing: -1.0,
      height: 1.08);
  static const display2 = TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      color: StayNestColors.textPrimaryLight,
      letterSpacing: -0.8,
      height: 1.10);

  // Headline
  static const h1 = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: StayNestColors.textPrimaryLight,
      letterSpacing: -0.5,
      height: 1.20);
  static const h2 = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: StayNestColors.textPrimaryLight,
      letterSpacing: -0.3,
      height: 1.25);
  static const h3 = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: StayNestColors.textPrimaryLight,
      letterSpacing: -0.2,
      height: 1.30);

  // Body
  static const body1 = TextStyle(
      fontSize: 15.5,
      fontWeight: FontWeight.w400,
      color: StayNestColors.textSecondaryLight,
      letterSpacing: 0.1,
      height: 1.55);
  static const body2 = TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w400,
      color: StayNestColors.textMutedLight,
      letterSpacing: 0.1,
      height: 1.50);

  // Label / caption
  static const label = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: StayNestColors.textSecondaryLight,
      letterSpacing: 0.5,
      height: 1.4);
  static const caption = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: StayNestColors.textMutedLight,
      letterSpacing: 0.3,
      height: 1.4);

  // Button
  static const button = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      letterSpacing: 0.3,
      height: 1.0);
  static const buttonSm = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      letterSpacing: 0.3,
      height: 1.0);

  // Tagline (splash screen dot-separated)
  static const tagline = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: StayNestColors.textSecondaryLight,
      letterSpacing: 2.8,
      height: 1.0);
}

abstract class AppTextStyles {
  static const heading1 = AppTextStyle.h1;
  static const heading2 = AppTextStyle.h2;
  static const heading3 = AppTextStyle.h3;
  static const body = AppTextStyle.body1;
  static const body2 = AppTextStyle.body2;
  static const label = AppTextStyle.label;
  static const caption = AppTextStyle.caption;
}

abstract class AppShadows {
  static const button = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
}

abstract class AppColors {
  static Color get primary => AppSession.isLandlord ? const Color(0xFF059669) : StayNestColors.primary;
  static Color get primaryLight => AppSession.isLandlord ? const Color(0xFFDDF6E8) : StayNestColors.primaryLight;
  static Color get background => AppSession.isLandlord ? const Color(0xFFE8F6EF) : StayNestColors.backgroundLight;
  static const Color white = Color(0xFFFFFFFF);

  static const gray900 = Color(0xFF111827);
  static const gray700 = Color(0xFF374151);
  static const gray600 = Color(0xFF4B5563);
  static const gray500 = Color(0xFF6B7280);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray100 = Color(0xFFF3F4F6);
  static const gray50 = Color(0xFFF9FAFB);

  static const green600 = StayNestColors.success;
  static const greenBg = StayNestColors.successLight;

  static const red500 = StayNestColors.error;
  static const redBg = StayNestColors.errorLight;

  static const mapBg = Color(0xFFF4F6F9);
}

// ─── Gradient presets ────────────────────────────────────────────────────────

abstract class AppGradient {
  /// Primary button gradient
  static const primary = LinearGradient(
    colors: [Color(0xFF5557E8), Color(0xFF3D3EDB)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Teal gradient (splash, dark-mode CTAs)
  static const teal = LinearGradient(
    colors: [Color(0xFF23B5AC), Color(0xFF1DD6C8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dark-mode background
  static const darkBg = LinearGradient(
    colors: [Color(0xFF0D1B2A), Color(0xFF0A1520)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Card overlay (bottom fade for property cards)
  static const cardScrim = LinearGradient(
    colors: [Colors.transparent, Color(0xCC000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Shimmer sweep (skeleton loading)
  static const shimmer = LinearGradient(
    colors: [
      StayNestColors.shimmerBase,
      StayNestColors.shimmerHigh,
      StayNestColors.shimmerBase,
    ],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

// ─── Icon size constants ─────────────────────────────────────────────────────

abstract class AppIconSize {
  static const double xs = 14;
  static const double sm = 16;
  static const double md = 20;
  static const double base = 24;
  static const double lg = 28;
  static const double xl = 32;
  static const double xxl = 40;
  static const double hero = 64;
}
