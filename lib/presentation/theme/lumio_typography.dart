import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'lumio_colors.dart';

/// Lumio Design System - Typography
/// Based on Stitch AI mockups using Plus Jakarta Sans / Inter font
///
/// Usage:
/// ```dart
/// Text('Hello', style: LumioTypography.headlineLarge)
/// Text('Hello', style: LumioTypography.headlineLarge.copyWith(color: Colors.red))
/// ```
class LumioTypography {
  LumioTypography._(); // Private constructor

  // ============================================================
  // FONT FAMILY
  // ============================================================

  /// Primary font family - Plus Jakarta Sans (matches Stitch mockups)
  /// Falls back to Inter which is already in the project
  static String get fontFamily => GoogleFonts.plusJakartaSans().fontFamily!;

  /// Get base text theme with Plus Jakarta Sans
  static TextTheme getTextTheme({bool isDark = false}) {
    final baseColor = isDark ? LumioColors.textPrimaryDark : LumioColors.textPrimaryLight;
    return GoogleFonts.plusJakartaSansTextTheme().apply(
      bodyColor: baseColor,
      displayColor: baseColor,
    );
  }

  // ============================================================
  // DISPLAY STYLES - For large hero text
  // ============================================================

  /// Display Large - 57px, Extra Bold
  /// Use for: App name, hero sections
  static TextStyle get displayLarge => GoogleFonts.plusJakartaSans(
        fontSize: 57,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
        height: 1.1,
      );

  /// Display Medium - 45px, Extra Bold
  /// Use for: Large headings
  static TextStyle get displayMedium => GoogleFonts.plusJakartaSans(
        fontSize: 45,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        height: 1.15,
      );

  /// Display Small - 36px, Bold
  /// Use for: Section titles, welcome text
  static TextStyle get displaySmall => GoogleFonts.plusJakartaSans(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.2,
      );

  // ============================================================
  // HEADLINE STYLES - For section headers
  // ============================================================

  /// Headline Large - 32px, Bold
  /// Use for: Main screen titles
  static TextStyle get headlineLarge => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.25,
      );

  /// Headline Medium - 28px, Bold
  /// Use for: Secondary headers
  static TextStyle get headlineMedium => GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.3,
      );

  /// Headline Small - 24px, Semi-Bold
  /// Use for: Card headers, dialog titles
  static TextStyle get headlineSmall => GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.35,
      );

  // ============================================================
  // TITLE STYLES - For card titles, list items
  // ============================================================

  /// Title Large - 22px, Semi-Bold
  /// Use for: Goal titles, section titles
  static TextStyle get titleLarge => GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.35,
      );

  /// Title Medium - 18px, Bold
  /// Use for: Card titles, task names
  static TextStyle get titleMedium => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.4,
      );

  /// Title Small - 16px, Semi-Bold
  /// Use for: Subtitles, navigation items
  static TextStyle get titleSmall => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.4,
      );

  // ============================================================
  // BODY STYLES - For paragraphs, descriptions
  // ============================================================

  /// Body Large - 16px, Regular
  /// Use for: Main content text
  static TextStyle get bodyLarge => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        height: 1.5,
      );

  /// Body Medium - 14px, Regular
  /// Use for: Secondary content, descriptions
  static TextStyle get bodyMedium => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        height: 1.5,
      );

  /// Body Small - 12px, Regular
  /// Use for: Captions, helper text
  static TextStyle get bodySmall => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        height: 1.5,
      );

  // ============================================================
  // LABEL STYLES - For buttons, chips, badges
  // ============================================================

  /// Label Large - 14px, Bold
  /// Use for: Primary buttons
  static TextStyle get labelLarge => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        height: 1.4,
      );

  /// Label Medium - 12px, Semi-Bold
  /// Use for: Secondary buttons, chips
  static TextStyle get labelMedium => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        height: 1.4,
      );

  /// Label Small - 10px, Bold
  /// Use for: Badges, nav labels, phase indicators
  static TextStyle get labelSmall => GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        height: 1.4,
      );

  // ============================================================
  // SPECIAL STYLES - For specific UI components
  // ============================================================

  /// Greeting text - "Hi, Sarah"
  static TextStyle get greeting => GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.3,
      );

  /// Streak counter text
  static TextStyle get streakCounter => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.4,
      );

  /// Level badge text
  static TextStyle get levelBadge => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.4,
      );

  /// Progress percentage text
  static TextStyle get progressPercent => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.4,
      );

  /// Phase indicator text - "Phase 1 of 3"
  static TextStyle get phaseIndicator => GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        height: 1.4,
      );

  /// Time duration text - "30m", "1h"
  static TextStyle get duration => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.4,
      );

  /// Date text in calendar
  static TextStyle get calendarDate => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.4,
      );

  /// Day label in calendar - "Mon", "Tue"
  static TextStyle get calendarDayLabel => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        height: 1.4,
      );

  /// Stats number - "14", "128h", "452"
  static TextStyle get statsNumber => GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.2,
      );

  /// Stats label - "Day Streak", "Focus Time"
  static TextStyle get statsLabel => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.4,
      );

  /// Nav label - "Home", "Goals", etc.
  static TextStyle get navLabel => GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.4,
      );

  /// Nav label active
  static TextStyle get navLabelActive => GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.4,
      );

  /// Category badge text - "BUSINESS", "HEALTH"
  static TextStyle get categoryBadge => GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        height: 1.4,
      );

  /// CTA button text - "Get Started"
  static TextStyle get ctaButton => GoogleFonts.plusJakartaSans(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        height: 1.4,
      );

  /// Premium badge text
  static TextStyle get premiumBadge => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        height: 1.4,
      );

  // ============================================================
  // CONTEXT-AWARE HELPERS
  // ============================================================

  /// Get text style with context-aware color
  static TextStyle withColor(TextStyle style, BuildContext context, {bool secondary = false, bool tertiary = false}) {
    Color color;
    if (tertiary) {
      color = LumioColors.textTertiary(context);
    } else if (secondary) {
      color = LumioColors.textSecondary(context);
    } else {
      color = LumioColors.textPrimary(context);
    }
    return style.copyWith(color: color);
  }

  /// Get body medium with secondary color (common pattern)
  static TextStyle bodyMediumSecondary(BuildContext context) {
    return bodyMedium.copyWith(color: LumioColors.textSecondary(context));
  }

  /// Get body small with tertiary color (common pattern)
  static TextStyle bodySmallTertiary(BuildContext context) {
    return bodySmall.copyWith(color: LumioColors.textTertiary(context));
  }

  // ============================================================
  // COMPLETE TEXT THEME FOR MATERIAL
  // ============================================================

  /// Get complete Material TextTheme
  static TextTheme get textTheme => TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        displaySmall: displaySmall,
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        headlineSmall: headlineSmall,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
      );

  /// Get text theme with colors applied for light mode
  static TextTheme get lightTextTheme => textTheme.apply(
        bodyColor: LumioColors.textPrimaryLight,
        displayColor: LumioColors.textPrimaryLight,
      );

  /// Get text theme with colors applied for dark mode
  static TextTheme get darkTextTheme => textTheme.apply(
        bodyColor: LumioColors.textPrimaryDark,
        displayColor: LumioColors.textPrimaryDark,
      );
}
