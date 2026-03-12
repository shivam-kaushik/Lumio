import 'package:flutter/material.dart';

/// Lumio Design System - Border Radius
/// Based on Stitch AI mockups with modern rounded corners
///
/// Usage:
/// ```dart
/// Container(
///   decoration: BoxDecoration(
///     borderRadius: LumioRadius.lg,
///   ),
/// )
/// ```
class LumioRadius {
  LumioRadius._(); // Private constructor

  // ============================================================
  // RADIUS VALUES
  // ============================================================

  /// 4px - Extra small radius
  static const double xs = 4.0;

  /// 8px - Small radius
  static const double sm = 8.0;

  /// 12px - Medium radius (default for most components)
  static const double md = 12.0;

  /// 16px - Large radius (cards, inputs)
  static const double lg = 16.0;

  /// 20px - Extra large radius
  static const double xl = 20.0;

  /// 24px - 2XL radius (goal cards in Stitch)
  static const double xxl = 24.0;

  /// 32px - 3XL radius (large cards, profile cards)
  static const double xxxl = 32.0;

  /// Full radius for pills/circles
  static const double full = 9999.0;

  // ============================================================
  // BORDER RADIUS PRESETS
  // ============================================================

  /// No radius
  static const BorderRadius none = BorderRadius.zero;

  /// Extra small - 4px all corners
  static BorderRadius get radiusXS => BorderRadius.circular(xs);

  /// Small - 8px all corners
  static BorderRadius get radiusSM => BorderRadius.circular(sm);

  /// Medium - 12px all corners (default)
  static BorderRadius get radiusMD => BorderRadius.circular(md);

  /// Large - 16px all corners
  static BorderRadius get radiusLG => BorderRadius.circular(lg);

  /// Extra large - 20px all corners
  static BorderRadius get radiusXL => BorderRadius.circular(xl);

  /// 2XL - 24px all corners (goal cards)
  static BorderRadius get radiusXXL => BorderRadius.circular(xxl);

  /// 3XL - 32px all corners (profile cards)
  static BorderRadius get radiusXXXL => BorderRadius.circular(xxxl);

  /// Full - pill shape
  static BorderRadius get radiusFull => BorderRadius.circular(full);

  // ============================================================
  // COMPONENT-SPECIFIC RADII
  // ============================================================

  /// Card radius - 24px (matches Stitch goal cards)
  static BorderRadius get card => BorderRadius.circular(xxl);

  /// Card compact radius - 16px
  static BorderRadius get cardCompact => BorderRadius.circular(lg);

  /// Task item radius - 16px
  static BorderRadius get taskItem => BorderRadius.circular(lg);

  /// Button radius - 12px
  static BorderRadius get button => BorderRadius.circular(md);

  /// Button large radius - 16px
  static BorderRadius get buttonLarge => BorderRadius.circular(lg);

  /// Button pill - full radius
  static BorderRadius get buttonPill => BorderRadius.circular(full);

  /// Input field radius - 12px
  static BorderRadius get input => BorderRadius.circular(md);

  /// Input field large radius - 16px
  static BorderRadius get inputLarge => BorderRadius.circular(lg);

  /// Chip/badge radius - full
  static BorderRadius get chip => BorderRadius.circular(full);

  /// Bottom sheet radius - top corners only, 24px
  static BorderRadius get bottomSheet => const BorderRadius.only(
    topLeft: Radius.circular(24.0),
    topRight: Radius.circular(24.0),
  );

  /// Bottom sheet large radius - top corners only, 32px
  static BorderRadius get bottomSheetLarge => const BorderRadius.only(
    topLeft: Radius.circular(32.0),
    topRight: Radius.circular(32.0),
  );

  /// Bottom nav radius - top corners only, 24px
  static BorderRadius get bottomNav => const BorderRadius.only(
    topLeft: Radius.circular(24.0),
    topRight: Radius.circular(24.0),
  );

  /// Dialog radius - 24px
  static BorderRadius get dialog => BorderRadius.circular(xxl);

  /// Avatar radius - full (circle)
  static BorderRadius get avatar => BorderRadius.circular(full);

  /// Progress bar radius - full
  static BorderRadius get progressBar => BorderRadius.circular(full);

  /// Badge indicator radius - full
  static BorderRadius get badgeIndicator => BorderRadius.circular(full);

  /// Calendar date button radius - full
  static BorderRadius get calendarDate => BorderRadius.circular(full);

  /// FAB radius - full
  static BorderRadius get fab => BorderRadius.circular(full);

  /// Category badge radius - 4px
  static BorderRadius get categoryBadge => BorderRadius.circular(xs);

  /// Phase badge radius - full
  static BorderRadius get phaseBadge => BorderRadius.circular(full);

  /// Filter button radius - full
  static BorderRadius get filterButton => BorderRadius.circular(full);

  /// Search bar radius - 12px
  static BorderRadius get searchBar => BorderRadius.circular(md);

  /// Icon button radius - 8px
  static BorderRadius get iconButton => BorderRadius.circular(sm);

  /// Icon button circle - full
  static BorderRadius get iconButtonCircle => BorderRadius.circular(full);

  /// Stats card radius - 24px
  static BorderRadius get statsCard => BorderRadius.circular(xxl);

  /// Timeline connector radius - full
  static BorderRadius get timelineConnector => BorderRadius.circular(full);

  /// Activity bar radius - top only, full
  static BorderRadius get activityBar => const BorderRadius.only(
    topLeft: Radius.circular(9999.0),
    topRight: Radius.circular(9999.0),
  );

  // ============================================================
  // DIRECTIONAL RADII (for specific corners)
  // ============================================================

  /// Top corners only - large
  static BorderRadius get topLG => const BorderRadius.only(
    topLeft: Radius.circular(16.0),
    topRight: Radius.circular(16.0),
  );

  /// Top corners only - extra large
  static BorderRadius get topXL => const BorderRadius.only(
    topLeft: Radius.circular(24.0),
    topRight: Radius.circular(24.0),
  );

  /// Bottom corners only - large
  static BorderRadius get bottomLG => const BorderRadius.only(
    bottomLeft: Radius.circular(16.0),
    bottomRight: Radius.circular(16.0),
  );

  /// Left corners only - large
  static BorderRadius get leftLG => const BorderRadius.only(
    topLeft: Radius.circular(16.0),
    bottomLeft: Radius.circular(16.0),
  );

  /// Right corners only - large
  static BorderRadius get rightLG => const BorderRadius.only(
    topRight: Radius.circular(16.0),
    bottomRight: Radius.circular(16.0),
  );

  /// Left side indicator bar (right corners rounded)
  static BorderRadius get indicatorBar => const BorderRadius.only(
    topRight: Radius.circular(9999.0),
    bottomRight: Radius.circular(9999.0),
  );

  // ============================================================
  // SHAPE BORDERS (for Material components)
  // ============================================================

  /// Rounded rectangle shape - card
  static RoundedRectangleBorder get cardShape => RoundedRectangleBorder(
    borderRadius: card,
  );

  /// Rounded rectangle shape - button
  static RoundedRectangleBorder get buttonShape => RoundedRectangleBorder(
    borderRadius: button,
  );

  /// Rounded rectangle shape - dialog
  static RoundedRectangleBorder get dialogShape => RoundedRectangleBorder(
    borderRadius: dialog,
  );

  /// Stadium border shape (pill)
  static const StadiumBorder stadiumShape = StadiumBorder();

  /// Circle shape
  static const CircleBorder circleShape = CircleBorder();

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Create custom BorderRadius with all corners same
  static BorderRadius circular(double radius) => BorderRadius.circular(radius);

  /// Create custom BorderRadius with different corners
  static BorderRadius only({
    double topLeft = 0,
    double topRight = 0,
    double bottomLeft = 0,
    double bottomRight = 0,
  }) => BorderRadius.only(
    topLeft: Radius.circular(topLeft),
    topRight: Radius.circular(topRight),
    bottomLeft: Radius.circular(bottomLeft),
    bottomRight: Radius.circular(bottomRight),
  );
}
