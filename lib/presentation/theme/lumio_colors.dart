import 'package:flutter/material.dart';

/// Lumio Design System - Color Palette
/// Based on Stitch AI mockups with warm amber/gold tones
///
/// Usage:
/// ```dart
/// Container(color: LumioColors.primary)
/// Text(style: TextStyle(color: LumioColors.textPrimary(context)))
/// ```
class LumioColors {
  LumioColors._(); // Private constructor to prevent instantiation

  // ============================================================
  // PRIMARY COLORS - Warm Amber/Gold Brand Colors
  // ============================================================

  /// Primary brand color - Warm amber/gold
  static const Color primary = Color(0xFFD99330);

  /// Primary color for hover states
  static const Color primaryHover = Color(0xFFE5A03D);

  /// Primary color pressed/active state
  static const Color primaryPressed = Color(0xFFC48528);

  /// Primary light variant - for backgrounds and subtle highlights
  static const Color primaryLight = Color(0xFFFDF6E9);

  /// Primary lighter - very subtle background
  static const Color primaryLighter = Color(0xFFFEFBF5);

  /// Primary dark variant - for text on light backgrounds
  static const Color primaryDark = Color(0xFF3D2B14);

  /// Alternative primary - slightly more orange
  static const Color primaryAlt = Color(0xFFEE992B);

  // ============================================================
  // SEMANTIC COLORS
  // ============================================================

  /// Success color - Green
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color successDark = Color(0xFF059669);

  /// Error color - Red
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFFDC2626);

  /// Warning color - Amber
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFFD97706);

  /// Info color - Blue
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);
  static const Color infoDark = Color(0xFF2563EB);

  // ============================================================
  // CATEGORY COLORS - For goal categories
  // ============================================================

  /// Business category
  static const Color categoryBusiness = Color(0xFFFF8C42);
  static const Color categoryBusinessLight = Color(0xFFFFF3E6);

  /// Health category
  static const Color categoryHealth = Color(0xFF3B82F6);
  static const Color categoryHealthLight = Color(0xFFEFF6FF);

  /// Personal category
  static const Color categoryPersonal = Color(0xFF8B5CF6);
  static const Color categoryPersonalLight = Color(0xFFF3E8FF);

  /// Finance category
  static const Color categoryFinance = Color(0xFF10B981);
  static const Color categoryFinanceLight = Color(0xFFECFDF5);

  /// Learning category
  static const Color categoryLearning = Color(0xFFF59E0B);
  static const Color categoryLearningLight = Color(0xFFFFFBEB);

  // ============================================================
  // LIGHT MODE COLORS
  // ============================================================

  /// Light mode background - Soft warm beige
  static const Color backgroundLight = Color(0xFFF8F8F6);

  /// Light mode alternative background
  static const Color backgroundLightAlt = Color(0xFFFCFAF8);

  /// Light mode surface/card color - Pure white
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// Light mode elevated surface
  static const Color surfaceLightElevated = Color(0xFFFFFFFF);

  /// Light mode primary text
  static const Color textPrimaryLight = Color(0xFF1C1917);

  /// Light mode secondary text
  static const Color textSecondaryLight = Color(0xFF78716C);

  /// Light mode tertiary/muted text
  static const Color textTertiaryLight = Color(0xFFA1A1AA);

  /// Light mode border color
  static const Color borderLight = Color(0xFFF3EEE7);

  /// Light mode border subtle
  static const Color borderLightSubtle = Color(0xFFF0F0F0);

  /// Light mode divider
  static const Color dividerLight = Color(0xFFE5E5E5);

  // ============================================================
  // DARK MODE COLORS
  // ============================================================

  /// Dark mode background - Rich dark
  static const Color backgroundDark = Color(0xFF18181B);

  /// Dark mode alternative background - Warm dark
  static const Color backgroundDarkAlt = Color(0xFF121212);

  /// Dark mode surface/card color
  static const Color surfaceDark = Color(0xFF27272A);

  /// Dark mode elevated surface
  static const Color surfaceDarkElevated = Color(0xFF2C241B);

  /// Dark mode primary text
  static const Color textPrimaryDark = Color(0xFFFAFAFA);

  /// Dark mode secondary text
  static const Color textSecondaryDark = Color(0xFFA1A1AA);

  /// Dark mode tertiary/muted text
  static const Color textTertiaryDark = Color(0xFF71717A);

  /// Dark mode border color
  static const Color borderDark = Color(0xFF3F3F46);

  /// Dark mode border subtle
  static const Color borderDarkSubtle = Color(0xFF27272A);

  /// Dark mode divider
  static const Color dividerDark = Color(0xFF3F3F46);

  // ============================================================
  // SPECIAL COLORS
  // ============================================================

  /// Online/Active indicator
  static const Color online = Color(0xFF22C55E);

  /// Notification badge
  static const Color badge = Color(0xFFEF4444);

  /// Streak fire color
  static const Color streak = Color(0xFFF97316);

  /// Premium badge color
  static const Color premium = Color(0xFFD99330);

  /// Shimmer base color
  static const Color shimmerBase = Color(0xFFE5E5E5);

  /// Shimmer highlight color
  static const Color shimmerHighlight = Color(0xFFF5F5F5);

  // ============================================================
  // GRADIENT DEFINITIONS
  // ============================================================

  /// Primary gradient for buttons and accents
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEE992B), Color(0xFFD99330)],
  );

  /// Warm background gradient (light mode)
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFCFAF8), Color(0xFFF4EFE9)],
  );

  /// Profile card gradient (light mode)
  static const LinearGradient profileGradientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x80FDF6E9), Color(0xFFFFFFFF)],
  );

  /// Profile card gradient (dark mode)
  static const LinearGradient profileGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x4D3D2B14), Color(0xFF1E1E1E)],
  );

  // ============================================================
  // CONTEXT-AWARE COLOR GETTERS
  // ============================================================

  /// Get background color based on brightness
  static Color background(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? backgroundDark
        : backgroundLight;
  }

  /// Get surface/card color based on brightness
  static Color surface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? surfaceDark
        : surfaceLight;
  }

  /// Get primary text color based on brightness
  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textPrimaryDark
        : textPrimaryLight;
  }

  /// Get secondary text color based on brightness
  static Color textSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textSecondaryDark
        : textSecondaryLight;
  }

  /// Get tertiary/muted text color based on brightness
  static Color textTertiary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textTertiaryDark
        : textTertiaryLight;
  }

  /// Get border color based on brightness
  static Color border(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? borderDark
        : borderLight;
  }

  /// Get divider color based on brightness
  static Color divider(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? dividerDark
        : dividerLight;
  }

  /// Get elevated surface color based on brightness
  static Color surfaceElevated(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? surfaceDarkElevated
        : surfaceLightElevated;
  }

  /// Get profile gradient based on brightness
  static LinearGradient profileGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? profileGradientDark
        : profileGradientLight;
  }

  // ============================================================
  // ALPHA/OPACITY HELPERS
  // ============================================================

  /// Get primary color with specified opacity
  static Color primaryWithOpacity(double opacity) {
    return primary.withOpacity(opacity);
  }

  /// Get overlay color for modals/sheets
  static Color overlay(BuildContext context, {double opacity = 0.5}) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withOpacity(opacity)
        : Colors.black.withOpacity(opacity * 0.8);
  }

  /// Get scrim color for drawers/navigation
  static Color scrim(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withOpacity(0.6)
        : Colors.black.withOpacity(0.4);
  }

  // ============================================================
  // MATERIAL COLOR SWATCH
  // ============================================================

  /// Primary MaterialColor swatch for Material components
  static const MaterialColor primarySwatch = MaterialColor(
    0xFFD99330,
    <int, Color>{
      50: Color(0xFFFDF6E9),
      100: Color(0xFFFBEDD3),
      200: Color(0xFFF7DBA7),
      300: Color(0xFFF3C97B),
      400: Color(0xFFEFB74F),
      500: Color(0xFFD99330),
      600: Color(0xFFC48528),
      700: Color(0xFFAF7720),
      800: Color(0xFF9A6918),
      900: Color(0xFF855B10),
    },
  );
}
