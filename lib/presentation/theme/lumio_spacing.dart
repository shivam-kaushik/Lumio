import 'package:flutter/material.dart';

/// Lumio Design System - Spacing & Sizing
/// Based on Stitch AI mockups with consistent 4px base unit
///
/// Usage:
/// ```dart
/// Padding(padding: LumioSpacing.paddingMD)
/// SizedBox(height: LumioSpacing.md)
/// Container(margin: LumioSpacing.horizontalMD)
/// ```
class LumioSpacing {
  LumioSpacing._(); // Private constructor

  // ============================================================
  // BASE SPACING VALUES (4px base unit)
  // ============================================================

  /// 2px - Extra extra small
  static const double xxs = 2.0;

  /// 4px - Extra small
  static const double xs = 4.0;

  /// 8px - Small
  static const double sm = 8.0;

  /// 12px - Medium small
  static const double ms = 12.0;

  /// 16px - Medium (default)
  static const double md = 16.0;

  /// 20px - Medium large
  static const double ml = 20.0;

  /// 24px - Large
  static const double lg = 24.0;

  /// 32px - Extra large
  static const double xl = 32.0;

  /// 40px - Extra extra large
  static const double xxl = 40.0;

  /// 48px - Triple extra large
  static const double xxxl = 48.0;

  /// 64px - Massive
  static const double huge = 64.0;

  // ============================================================
  // SCREEN PADDING - Consistent horizontal padding
  // ============================================================

  /// Standard screen horizontal padding (24px) - matches Stitch mockups
  static const double screenHorizontal = 24.0;

  /// Screen padding for content areas (16px)
  static const double screenPadding = 16.0;

  /// Screen padding EdgeInsets
  static const EdgeInsets screenPaddingAll = EdgeInsets.all(24.0);

  /// Screen horizontal padding only
  static const EdgeInsets screenHorizontalPadding = EdgeInsets.symmetric(horizontal: 24.0);

  // ============================================================
  // COMMON PADDING PRESETS
  // ============================================================

  /// No padding
  static const EdgeInsets paddingNone = EdgeInsets.zero;

  /// Extra small padding - 4px all
  static const EdgeInsets paddingXS = EdgeInsets.all(4.0);

  /// Small padding - 8px all
  static const EdgeInsets paddingSM = EdgeInsets.all(8.0);

  /// Medium padding - 16px all
  static const EdgeInsets paddingMD = EdgeInsets.all(16.0);

  /// Large padding - 24px all
  static const EdgeInsets paddingLG = EdgeInsets.all(24.0);

  /// Extra large padding - 32px all
  static const EdgeInsets paddingXL = EdgeInsets.all(32.0);

  // ============================================================
  // HORIZONTAL PADDING PRESETS
  // ============================================================

  /// Horizontal XS - 4px
  static const EdgeInsets horizontalXS = EdgeInsets.symmetric(horizontal: 4.0);

  /// Horizontal SM - 8px
  static const EdgeInsets horizontalSM = EdgeInsets.symmetric(horizontal: 8.0);

  /// Horizontal MD - 16px
  static const EdgeInsets horizontalMD = EdgeInsets.symmetric(horizontal: 16.0);

  /// Horizontal LG - 24px
  static const EdgeInsets horizontalLG = EdgeInsets.symmetric(horizontal: 24.0);

  /// Horizontal XL - 32px
  static const EdgeInsets horizontalXL = EdgeInsets.symmetric(horizontal: 32.0);

  // ============================================================
  // VERTICAL PADDING PRESETS
  // ============================================================

  /// Vertical XS - 4px
  static const EdgeInsets verticalXS = EdgeInsets.symmetric(vertical: 4.0);

  /// Vertical SM - 8px
  static const EdgeInsets verticalSM = EdgeInsets.symmetric(vertical: 8.0);

  /// Vertical MD - 16px
  static const EdgeInsets verticalMD = EdgeInsets.symmetric(vertical: 16.0);

  /// Vertical LG - 24px
  static const EdgeInsets verticalLG = EdgeInsets.symmetric(vertical: 24.0);

  /// Vertical XL - 32px
  static const EdgeInsets verticalXL = EdgeInsets.symmetric(vertical: 32.0);

  // ============================================================
  // COMPONENT-SPECIFIC SPACING
  // ============================================================

  /// Card internal padding (20px) - matches Stitch goal cards
  static const EdgeInsets cardPadding = EdgeInsets.all(20.0);

  /// Card padding compact
  static const EdgeInsets cardPaddingCompact = EdgeInsets.all(16.0);

  /// Card padding large
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(24.0);

  /// Button padding
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0);

  /// Button padding compact
  static const EdgeInsets buttonPaddingCompact = EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);

  /// Chip/badge padding
  static const EdgeInsets chipPadding = EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0);

  /// Input field padding
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0);

  /// List tile padding
  static const EdgeInsets listTilePadding = EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);

  /// Bottom sheet padding
  static const EdgeInsets bottomSheetPadding = EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 32.0);

  /// Dialog padding
  static const EdgeInsets dialogPadding = EdgeInsets.all(24.0);

  /// Section header padding
  static const EdgeInsets sectionHeaderPadding = EdgeInsets.only(left: 24.0, right: 24.0, bottom: 16.0);

  // ============================================================
  // GAP SIZES (for Row/Column gaps)
  // ============================================================

  /// Gap 2px
  static const double gap2 = 2.0;

  /// Gap 4px
  static const double gap4 = 4.0;

  /// Gap 6px
  static const double gap6 = 6.0;

  /// Gap 8px
  static const double gap8 = 8.0;

  /// Gap 12px
  static const double gap12 = 12.0;

  /// Gap 16px
  static const double gap16 = 16.0;

  /// Gap 20px
  static const double gap20 = 20.0;

  /// Gap 24px
  static const double gap24 = 24.0;

  /// Gap 32px
  static const double gap32 = 32.0;

  // ============================================================
  // SIZED BOX PRESETS (for convenience)
  // ============================================================

  /// Vertical gap - 4px
  static const SizedBox verticalGap4 = SizedBox(height: 4.0);

  /// Vertical gap - 8px
  static const SizedBox verticalGap8 = SizedBox(height: 8.0);

  /// Vertical gap - 12px
  static const SizedBox verticalGap12 = SizedBox(height: 12.0);

  /// Vertical gap - 16px
  static const SizedBox verticalGap16 = SizedBox(height: 16.0);

  /// Vertical gap - 24px
  static const SizedBox verticalGap24 = SizedBox(height: 24.0);

  /// Vertical gap - 32px
  static const SizedBox verticalGap32 = SizedBox(height: 32.0);

  /// Horizontal gap - 4px
  static const SizedBox horizontalGap4 = SizedBox(width: 4.0);

  /// Horizontal gap - 8px
  static const SizedBox horizontalGap8 = SizedBox(width: 8.0);

  /// Horizontal gap - 12px
  static const SizedBox horizontalGap12 = SizedBox(width: 12.0);

  /// Horizontal gap - 16px
  static const SizedBox horizontalGap16 = SizedBox(width: 16.0);

  /// Horizontal gap - 24px
  static const SizedBox horizontalGap24 = SizedBox(width: 24.0);

  // ============================================================
  // COMPONENT SIZES
  // ============================================================

  /// Avatar size - small (32px)
  static const double avatarSM = 32.0;

  /// Avatar size - medium (40px)
  static const double avatarMD = 40.0;

  /// Avatar size - large (48px)
  static const double avatarLG = 48.0;

  /// Avatar size - extra large (64px)
  static const double avatarXL = 64.0;

  /// Avatar size - profile (96px)
  static const double avatarProfile = 96.0;

  /// Icon size - small (16px)
  static const double iconSM = 16.0;

  /// Icon size - medium (20px)
  static const double iconMD = 20.0;

  /// Icon size - large (24px)
  static const double iconLG = 24.0;

  /// Icon size - extra large (32px)
  static const double iconXL = 32.0;

  /// Button height - standard (48px)
  static const double buttonHeight = 48.0;

  /// Button height - compact (40px)
  static const double buttonHeightCompact = 40.0;

  /// Button height - large (56px)
  static const double buttonHeightLarge = 56.0;

  /// FAB size - standard (56px)
  static const double fabSize = 56.0;

  /// FAB size - small (40px)
  static const double fabSizeSmall = 40.0;

  /// FAB size - large (64px)
  static const double fabSizeLarge = 64.0;

  /// Bottom nav height (including safe area padding)
  static const double bottomNavHeight = 80.0;

  /// Bottom nav content height (without safe area)
  static const double bottomNavContentHeight = 56.0;

  /// App bar height
  static const double appBarHeight = 56.0;

  /// Progress circle size - small (40px)
  static const double progressCircleSM = 40.0;

  /// Progress circle size - medium (48px)
  static const double progressCircleMD = 48.0;

  /// Progress circle size - large (56px)
  static const double progressCircleLG = 56.0;

  /// Progress circle size - extra large (80px)
  static const double progressCircleXL = 80.0;

  /// Calendar date button size (40px)
  static const double calendarDateSize = 40.0;

  /// Badge circle size - small (20px)
  static const double badgeSM = 20.0;

  /// Badge circle size - large (80px)
  static const double badgeLG = 80.0;

  /// Card min height for goals
  static const double goalCardMinHeight = 120.0;

  /// Task item min height
  static const double taskItemMinHeight = 64.0;

  // ============================================================
  // SAFE AREA HELPER
  // ============================================================

  /// Get bottom padding with safe area
  static EdgeInsets bottomSafeArea(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return EdgeInsets.only(bottom: bottomPadding + 16.0);
  }

  /// Get screen padding with safe areas
  static EdgeInsets screenWithSafeArea(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return EdgeInsets.only(
      left: screenHorizontal,
      right: screenHorizontal,
      top: mediaQuery.padding.top + md,
      bottom: mediaQuery.padding.bottom + md,
    );
  }
}
