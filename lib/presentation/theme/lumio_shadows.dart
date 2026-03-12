import 'package:flutter/material.dart';
import 'lumio_colors.dart';

/// Lumio Design System - Shadows & Elevation
/// Based on Stitch AI mockups with soft, modern shadows
///
/// Usage:
/// ```dart
/// Container(
///   decoration: BoxDecoration(
///     boxShadow: LumioShadows.soft,
///   ),
/// )
/// ```
class LumioShadows {
  LumioShadows._(); // Private constructor

  // ============================================================
  // LIGHT MODE SHADOWS
  // ============================================================

  /// No shadow
  static const List<BoxShadow> none = [];

  /// Soft shadow - default for cards (matches Stitch: 0 4px 20px -2px rgba(0,0,0,0.05))
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x0D000000), // 5% opacity
      blurRadius: 20,
      offset: Offset(0, 4),
      spreadRadius: -2,
    ),
  ];

  /// Extra soft shadow - very subtle
  static const List<BoxShadow> extraSoft = [
    BoxShadow(
      color: Color(0x08000000), // 3% opacity
      blurRadius: 12,
      offset: Offset(0, 2),
      spreadRadius: -1,
    ),
  ];

  /// Medium shadow - for elevated cards
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x14000000), // 8% opacity
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: -4,
    ),
  ];

  /// Strong shadow - for modals, dialogs
  static const List<BoxShadow> strong = [
    BoxShadow(
      color: Color(0x1A000000), // 10% opacity
      blurRadius: 32,
      offset: Offset(0, 12),
      spreadRadius: -6,
    ),
  ];

  /// Navigation shadow - bottom nav (upward shadow)
  static const List<BoxShadow> nav = [
    BoxShadow(
      color: Color(0x0D000000), // 5% opacity
      blurRadius: 20,
      offset: Offset(0, -4),
      spreadRadius: -2,
    ),
  ];

  /// FAB shadow with primary color glow
  static List<BoxShadow> get fab => [
    BoxShadow(
      color: LumioColors.primary.withOpacity(0.4),
      blurRadius: 20,
      offset: const Offset(0, 8),
      spreadRadius: -4,
    ),
  ];

  /// FAB shadow light (less prominent)
  static List<BoxShadow> get fabLight => [
    BoxShadow(
      color: LumioColors.primary.withOpacity(0.3),
      blurRadius: 16,
      offset: const Offset(0, 6),
      spreadRadius: -2,
    ),
  ];

  /// Button pressed shadow
  static const List<BoxShadow> buttonPressed = [
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 4,
      offset: Offset(0, 1),
      spreadRadius: 0,
    ),
  ];

  /// Card hover shadow
  static const List<BoxShadow> cardHover = [
    BoxShadow(
      color: Color(0x14000000), // 8% opacity
      blurRadius: 28,
      offset: Offset(0, 6),
      spreadRadius: -2,
    ),
  ];

  // ============================================================
  // DARK MODE SHADOWS
  // ============================================================

  /// Soft shadow for dark mode
  static const List<BoxShadow> softDark = [
    BoxShadow(
      color: Color(0x33000000), // 20% opacity
      blurRadius: 20,
      offset: Offset(0, 4),
      spreadRadius: -2,
    ),
  ];

  /// Medium shadow for dark mode
  static const List<BoxShadow> mediumDark = [
    BoxShadow(
      color: Color(0x40000000), // 25% opacity
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: -4,
    ),
  ];

  /// Strong shadow for dark mode
  static const List<BoxShadow> strongDark = [
    BoxShadow(
      color: Color(0x4D000000), // 30% opacity
      blurRadius: 32,
      offset: Offset(0, 12),
      spreadRadius: -6,
    ),
  ];

  /// Navigation shadow for dark mode
  static const List<BoxShadow> navDark = [
    BoxShadow(
      color: Color(0x33000000), // 20% opacity
      blurRadius: 20,
      offset: Offset(0, -4),
      spreadRadius: -2,
    ),
  ];

  // ============================================================
  // CONTEXT-AWARE SHADOW GETTERS
  // ============================================================

  /// Get soft shadow based on theme brightness
  static List<BoxShadow> getSoft(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? softDark : soft;
  }

  /// Get medium shadow based on theme brightness
  static List<BoxShadow> getMedium(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? mediumDark : medium;
  }

  /// Get strong shadow based on theme brightness
  static List<BoxShadow> getStrong(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? strongDark : strong;
  }

  /// Get nav shadow based on theme brightness
  static List<BoxShadow> getNav(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? navDark : nav;
  }

  // ============================================================
  // ELEVATION LEVELS (Material Design inspired)
  // ============================================================

  /// Elevation level 0 - flat
  static List<BoxShadow> elevation0(BuildContext context) => none;

  /// Elevation level 1 - subtle
  static List<BoxShadow> elevation1(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Color(isDark ? 0x33000000 : 0x0A000000),
        blurRadius: 4,
        offset: const Offset(0, 2),
        spreadRadius: 0,
      ),
    ];
  }

  /// Elevation level 2 - card default
  static List<BoxShadow> elevation2(BuildContext context) {
    return getSoft(context);
  }

  /// Elevation level 3 - elevated card
  static List<BoxShadow> elevation3(BuildContext context) {
    return getMedium(context);
  }

  /// Elevation level 4 - modal/dialog
  static List<BoxShadow> elevation4(BuildContext context) {
    return getStrong(context);
  }

  // ============================================================
  // INNER SHADOWS (for pressed states)
  // ============================================================

  /// Inner shadow for pressed buttons
  static const List<BoxShadow> innerSoft = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 4,
      offset: Offset(0, 2),
      spreadRadius: -1,
      blurStyle: BlurStyle.inner,
    ),
  ];

  // ============================================================
  // GLOW EFFECTS
  // ============================================================

  /// Primary color glow
  static List<BoxShadow> get primaryGlow => [
    BoxShadow(
      color: LumioColors.primary.withOpacity(0.3),
      blurRadius: 24,
      offset: Offset.zero,
      spreadRadius: 0,
    ),
  ];

  /// Success color glow
  static List<BoxShadow> get successGlow => [
    BoxShadow(
      color: LumioColors.success.withOpacity(0.3),
      blurRadius: 24,
      offset: Offset.zero,
      spreadRadius: 0,
    ),
  ];

  /// Error color glow
  static List<BoxShadow> get errorGlow => [
    BoxShadow(
      color: LumioColors.error.withOpacity(0.3),
      blurRadius: 24,
      offset: Offset.zero,
      spreadRadius: 0,
    ),
  ];

  // ============================================================
  // PROGRESS BAR SHADOW
  // ============================================================

  /// Shadow for progress indicator current day highlight
  static List<BoxShadow> get progressHighlight => [
    BoxShadow(
      color: LumioColors.primary.withOpacity(0.3),
      blurRadius: 8,
      offset: Offset.zero,
      spreadRadius: 0,
    ),
  ];
}
