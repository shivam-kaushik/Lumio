import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lumio_colors.dart';
import 'lumio_typography.dart';
import 'lumio_spacing.dart';
import 'lumio_shadows.dart';
import 'lumio_radius.dart';

/// Lumio Design System - Complete Theme
/// Based on Stitch AI mockups with Material 3 support
///
/// Usage:
/// ```dart
/// MaterialApp(
///   theme: LumioTheme.light,
///   darkTheme: LumioTheme.dark,
///   themeMode: ThemeMode.system,
/// )
/// ```
class LumioTheme {
  LumioTheme._(); // Private constructor

  // ============================================================
  // LIGHT THEME
  // ============================================================

  /// Light theme for the app
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: LumioColors.primary,
        brightness: Brightness.light,
        primary: LumioColors.primary,
        onPrimary: Colors.white,
        primaryContainer: LumioColors.primaryLight,
        onPrimaryContainer: LumioColors.primaryDark,
        secondary: LumioColors.primaryAlt,
        onSecondary: Colors.white,
        secondaryContainer: LumioColors.primaryLighter,
        onSecondaryContainer: LumioColors.primaryDark,
        tertiary: LumioColors.categoryBusiness,
        error: LumioColors.error,
        onError: Colors.white,
        errorContainer: LumioColors.errorLight,
        onErrorContainer: LumioColors.errorDark,
        surface: LumioColors.surfaceLight,
        onSurface: LumioColors.textPrimaryLight,
        surfaceContainerHighest: LumioColors.backgroundLight,
        onSurfaceVariant: LumioColors.textSecondaryLight,
        outline: LumioColors.borderLight,
        outlineVariant: LumioColors.borderLightSubtle,
      ),

      // Scaffold
      scaffoldBackgroundColor: LumioColors.backgroundLight,

      // Text Theme
      textTheme: LumioTypography.lightTextTheme,

      // App Bar Theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: LumioColors.textPrimaryLight,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: LumioTypography.headlineMedium.copyWith(
          color: LumioColors.textPrimaryLight,
        ),
        iconTheme: const IconThemeData(
          color: LumioColors.textPrimaryLight,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: LumioColors.textPrimaryLight,
          size: 24,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.card,
          side: const BorderSide(
            color: LumioColors.borderLight,
            width: 1,
          ),
        ),
        color: LumioColors.surfaceLight,
        shadowColor: Colors.transparent,
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: LumioColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: LumioSpacing.buttonPadding,
          minimumSize: Size(0, LumioSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: LumioRadius.buttonPill,
          ),
          textStyle: LumioTypography.labelLarge,
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LumioColors.primary,
          padding: LumioSpacing.buttonPaddingCompact,
          shape: RoundedRectangleBorder(
            borderRadius: LumioRadius.button,
          ),
          textStyle: LumioTypography.labelLarge,
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LumioColors.primary,
          padding: LumioSpacing.buttonPadding,
          minimumSize: Size(0, LumioSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: LumioRadius.buttonPill,
          ),
          side: const BorderSide(
            color: LumioColors.primary,
            width: 1.5,
          ),
          textStyle: LumioTypography.labelLarge,
        ),
      ),

      // Icon Button Theme
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: LumioColors.textPrimaryLight,
          shape: RoundedRectangleBorder(
            borderRadius: LumioRadius.iconButtonCircle,
          ),
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: LumioColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.fab,
        ),
        extendedPadding: LumioSpacing.buttonPadding,
        extendedTextStyle: LumioTypography.labelLarge,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LumioColors.surfaceLight,
        contentPadding: LumioSpacing.inputPadding,
        border: OutlineInputBorder(
          borderRadius: LumioRadius.input,
          borderSide: const BorderSide(color: LumioColors.borderLight, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: LumioRadius.input,
          borderSide: const BorderSide(color: LumioColors.borderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: LumioRadius.input,
          borderSide: const BorderSide(color: LumioColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: LumioRadius.input,
          borderSide: const BorderSide(color: LumioColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: LumioRadius.input,
          borderSide: const BorderSide(color: LumioColors.error, width: 2),
        ),
        labelStyle: LumioTypography.bodyMedium.copyWith(
          color: LumioColors.textSecondaryLight,
        ),
        hintStyle: LumioTypography.bodyMedium.copyWith(
          color: LumioColors.textTertiaryLight,
        ),
        prefixIconColor: LumioColors.textSecondaryLight,
        suffixIconColor: LumioColors.textSecondaryLight,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: LumioColors.backgroundLight,
        selectedColor: LumioColors.primaryLight,
        checkmarkColor: LumioColors.primary,
        labelStyle: LumioTypography.labelMedium.copyWith(
          color: LumioColors.textPrimaryLight,
        ),
        padding: LumioSpacing.chipPadding,
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.chip,
          side: const BorderSide(color: LumioColors.borderLight, width: 1),
        ),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: LumioColors.surfaceLight,
        selectedItemColor: LumioColors.primary,
        unselectedItemColor: LumioColors.textSecondaryLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: LumioTypography.navLabelActive,
        unselectedLabelStyle: LumioTypography.navLabel,
      ),

      // Navigation Bar Theme (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: LumioColors.surfaceLight,
        indicatorColor: LumioColors.primaryLight,
        elevation: 0,
        height: LumioSpacing.bottomNavHeight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return LumioTypography.navLabelActive.copyWith(color: LumioColors.primary);
          }
          return LumioTypography.navLabel.copyWith(color: LumioColors.textSecondaryLight);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: LumioColors.primary, size: 24);
          }
          return const IconThemeData(color: LumioColors.textSecondaryLight, size: 24);
        }),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: LumioColors.surfaceLight,
        modalBackgroundColor: LumioColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.bottomSheet,
        ),
        dragHandleColor: LumioColors.borderLight,
        dragHandleSize: const Size(40, 4),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: LumioColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.dialog,
        ),
        titleTextStyle: LumioTypography.headlineSmall.copyWith(
          color: LumioColors.textPrimaryLight,
        ),
        contentTextStyle: LumioTypography.bodyMedium.copyWith(
          color: LumioColors.textSecondaryLight,
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: LumioColors.dividerLight,
        thickness: 1,
        space: 1,
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: LumioColors.primary,
        linearTrackColor: LumioColors.borderLight,
        circularTrackColor: LumioColors.borderLight,
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: LumioColors.primary,
        inactiveTrackColor: LumioColors.borderLight,
        thumbColor: LumioColors.primary,
        overlayColor: LumioColors.primary.withOpacity(0.1),
        trackHeight: 4,
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return LumioColors.primary;
          }
          return LumioColors.textSecondaryLight;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return LumioColors.primaryLight;
          }
          return LumioColors.borderLight;
        }),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return LumioColors.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        side: const BorderSide(color: LumioColors.borderLight, width: 2),
      ),

      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return LumioColors.primary;
          }
          return LumioColors.textSecondaryLight;
        }),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: LumioColors.textPrimaryLight,
        contentTextStyle: LumioTypography.bodyMedium.copyWith(
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.radiusMD,
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: LumioColors.primary,
        unselectedLabelColor: LumioColors.textSecondaryLight,
        labelStyle: LumioTypography.labelLarge,
        unselectedLabelStyle: LumioTypography.labelMedium,
        indicator: UnderlineTabIndicator(
          borderSide: const BorderSide(color: LumioColors.primary, width: 2),
          borderRadius: LumioRadius.radiusFull,
        ),
        dividerColor: Colors.transparent,
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        contentPadding: LumioSpacing.listTilePadding,
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.radiusLG,
        ),
        titleTextStyle: LumioTypography.titleSmall.copyWith(
          color: LumioColors.textPrimaryLight,
        ),
        subtitleTextStyle: LumioTypography.bodySmall.copyWith(
          color: LumioColors.textSecondaryLight,
        ),
      ),

      // Badge Theme
      badgeTheme: const BadgeThemeData(
        backgroundColor: LumioColors.badge,
        textColor: Colors.white,
      ),

      // Tooltip Theme
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: LumioColors.textPrimaryLight,
          borderRadius: LumioRadius.radiusSM,
        ),
        textStyle: LumioTypography.bodySmall.copyWith(
          color: Colors.white,
        ),
      ),

      // Date Picker Theme
      datePickerTheme: DatePickerThemeData(
        backgroundColor: LumioColors.surfaceLight,
        headerBackgroundColor: LumioColors.primary,
        headerForegroundColor: Colors.white,
        dayForegroundColor: WidgetStateProperty.all(LumioColors.textPrimaryLight),
        todayForegroundColor: WidgetStateProperty.all(LumioColors.primary),
        todayBackgroundColor: WidgetStateProperty.all(LumioColors.primaryLight),
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.dialog,
        ),
      ),

      // Time Picker Theme
      timePickerTheme: TimePickerThemeData(
        backgroundColor: LumioColors.surfaceLight,
        hourMinuteColor: LumioColors.primaryLight,
        hourMinuteTextColor: LumioColors.primary,
        dialBackgroundColor: LumioColors.backgroundLight,
        dialHandColor: LumioColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.dialog,
        ),
      ),

      // Popup Menu Theme
      popupMenuTheme: PopupMenuThemeData(
        color: LumioColors.surfaceLight,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.radiusMD,
        ),
        textStyle: LumioTypography.bodyMedium.copyWith(
          color: LumioColors.textPrimaryLight,
        ),
      ),

      // Drawer Theme
      drawerTheme: DrawerThemeData(
        backgroundColor: LumioColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.only(
            topRight: LumioRadius.xl,
            bottomRight: LumioRadius.xl,
          ),
        ),
      ),

      // Extensions
      extensions: const <ThemeExtension<dynamic>>[
        LumioThemeExtension.light,
      ],
    );
  }

  // ============================================================
  // DARK THEME
  // ============================================================

  /// Dark theme for the app
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: LumioColors.primary,
        brightness: Brightness.dark,
        primary: LumioColors.primary,
        onPrimary: Colors.white,
        primaryContainer: LumioColors.primaryDark,
        onPrimaryContainer: LumioColors.primaryLight,
        secondary: LumioColors.primaryAlt,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFF3D2B14),
        onSecondaryContainer: LumioColors.primaryLight,
        tertiary: LumioColors.categoryBusiness,
        error: LumioColors.error,
        onError: Colors.white,
        errorContainer: LumioColors.errorDark,
        onErrorContainer: LumioColors.errorLight,
        surface: LumioColors.surfaceDark,
        onSurface: LumioColors.textPrimaryDark,
        surfaceContainerHighest: LumioColors.backgroundDark,
        onSurfaceVariant: LumioColors.textSecondaryDark,
        outline: LumioColors.borderDark,
        outlineVariant: LumioColors.borderDarkSubtle,
      ),

      // Scaffold
      scaffoldBackgroundColor: LumioColors.backgroundDark,

      // Canvas Color
      canvasColor: LumioColors.backgroundDark,
      cardColor: LumioColors.surfaceDark,
      dialogBackgroundColor: LumioColors.surfaceDark,

      // Text Theme
      textTheme: LumioTypography.darkTextTheme,

      // App Bar Theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: LumioColors.textPrimaryDark,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: LumioTypography.headlineMedium.copyWith(
          color: LumioColors.textPrimaryDark,
        ),
        iconTheme: const IconThemeData(
          color: LumioColors.textPrimaryDark,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: LumioColors.textPrimaryDark,
          size: 24,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.card,
          side: BorderSide(
            color: LumioColors.borderDark.withOpacity(0.5),
            width: 1,
          ),
        ),
        color: LumioColors.surfaceDark,
        shadowColor: Colors.transparent,
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: LumioColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: LumioSpacing.buttonPadding,
          minimumSize: Size(0, LumioSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: LumioRadius.buttonPill,
          ),
          textStyle: LumioTypography.labelLarge,
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LumioColors.primary,
          padding: LumioSpacing.buttonPaddingCompact,
          shape: RoundedRectangleBorder(
            borderRadius: LumioRadius.button,
          ),
          textStyle: LumioTypography.labelLarge,
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LumioColors.primary,
          padding: LumioSpacing.buttonPadding,
          minimumSize: Size(0, LumioSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: LumioRadius.buttonPill,
          ),
          side: const BorderSide(
            color: LumioColors.primary,
            width: 1.5,
          ),
          textStyle: LumioTypography.labelLarge,
        ),
      ),

      // Icon Button Theme
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: LumioColors.textPrimaryDark,
          shape: RoundedRectangleBorder(
            borderRadius: LumioRadius.iconButtonCircle,
          ),
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: LumioColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.fab,
        ),
        extendedPadding: LumioSpacing.buttonPadding,
        extendedTextStyle: LumioTypography.labelLarge,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LumioColors.surfaceDark,
        contentPadding: LumioSpacing.inputPadding,
        border: OutlineInputBorder(
          borderRadius: LumioRadius.input,
          borderSide: const BorderSide(color: LumioColors.borderDark, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: LumioRadius.input,
          borderSide: const BorderSide(color: LumioColors.borderDark, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: LumioRadius.input,
          borderSide: const BorderSide(color: LumioColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: LumioRadius.input,
          borderSide: const BorderSide(color: LumioColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: LumioRadius.input,
          borderSide: const BorderSide(color: LumioColors.error, width: 2),
        ),
        labelStyle: LumioTypography.bodyMedium.copyWith(
          color: LumioColors.textSecondaryDark,
        ),
        hintStyle: LumioTypography.bodyMedium.copyWith(
          color: LumioColors.textTertiaryDark,
        ),
        prefixIconColor: LumioColors.textSecondaryDark,
        suffixIconColor: LumioColors.textSecondaryDark,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: LumioColors.surfaceDark,
        selectedColor: LumioColors.primaryDark,
        checkmarkColor: LumioColors.primary,
        labelStyle: LumioTypography.labelMedium.copyWith(
          color: LumioColors.textPrimaryDark,
        ),
        padding: LumioSpacing.chipPadding,
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.chip,
          side: const BorderSide(color: LumioColors.borderDark, width: 1),
        ),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: LumioColors.surfaceDark,
        selectedItemColor: LumioColors.primary,
        unselectedItemColor: LumioColors.textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: LumioTypography.navLabelActive,
        unselectedLabelStyle: LumioTypography.navLabel,
      ),

      // Navigation Bar Theme (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: LumioColors.surfaceDark,
        indicatorColor: LumioColors.primary.withOpacity(0.2),
        elevation: 0,
        height: LumioSpacing.bottomNavHeight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return LumioTypography.navLabelActive.copyWith(color: LumioColors.primary);
          }
          return LumioTypography.navLabel.copyWith(color: LumioColors.textSecondaryDark);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: LumioColors.primary, size: 24);
          }
          return const IconThemeData(color: LumioColors.textSecondaryDark, size: 24);
        }),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: LumioColors.surfaceDark,
        modalBackgroundColor: LumioColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.bottomSheet,
        ),
        dragHandleColor: LumioColors.borderDark,
        dragHandleSize: const Size(40, 4),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: LumioColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.dialog,
        ),
        titleTextStyle: LumioTypography.headlineSmall.copyWith(
          color: LumioColors.textPrimaryDark,
        ),
        contentTextStyle: LumioTypography.bodyMedium.copyWith(
          color: LumioColors.textSecondaryDark,
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: LumioColors.dividerDark,
        thickness: 1,
        space: 1,
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: LumioColors.primary,
        linearTrackColor: LumioColors.borderDark,
        circularTrackColor: LumioColors.borderDark,
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: LumioColors.primary,
        inactiveTrackColor: LumioColors.borderDark,
        thumbColor: LumioColors.primary,
        overlayColor: LumioColors.primary.withOpacity(0.1),
        trackHeight: 4,
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return LumioColors.primary;
          }
          return LumioColors.textSecondaryDark;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return LumioColors.primary.withOpacity(0.4);
          }
          return LumioColors.borderDark;
        }),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return LumioColors.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        side: const BorderSide(color: LumioColors.borderDark, width: 2),
      ),

      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return LumioColors.primary;
          }
          return LumioColors.textSecondaryDark;
        }),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: LumioColors.surfaceDarkElevated,
        contentTextStyle: LumioTypography.bodyMedium.copyWith(
          color: LumioColors.textPrimaryDark,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.radiusMD,
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: LumioColors.primary,
        unselectedLabelColor: LumioColors.textSecondaryDark,
        labelStyle: LumioTypography.labelLarge,
        unselectedLabelStyle: LumioTypography.labelMedium,
        indicator: UnderlineTabIndicator(
          borderSide: const BorderSide(color: LumioColors.primary, width: 2),
          borderRadius: LumioRadius.radiusFull,
        ),
        dividerColor: Colors.transparent,
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        contentPadding: LumioSpacing.listTilePadding,
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.radiusLG,
        ),
        titleTextStyle: LumioTypography.titleSmall.copyWith(
          color: LumioColors.textPrimaryDark,
        ),
        subtitleTextStyle: LumioTypography.bodySmall.copyWith(
          color: LumioColors.textSecondaryDark,
        ),
      ),

      // Badge Theme
      badgeTheme: const BadgeThemeData(
        backgroundColor: LumioColors.badge,
        textColor: Colors.white,
      ),

      // Tooltip Theme
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: LumioColors.surfaceDarkElevated,
          borderRadius: LumioRadius.radiusSM,
        ),
        textStyle: LumioTypography.bodySmall.copyWith(
          color: LumioColors.textPrimaryDark,
        ),
      ),

      // Date Picker Theme
      datePickerTheme: DatePickerThemeData(
        backgroundColor: LumioColors.surfaceDark,
        headerBackgroundColor: LumioColors.primary,
        headerForegroundColor: Colors.white,
        dayForegroundColor: WidgetStateProperty.all(LumioColors.textPrimaryDark),
        todayForegroundColor: WidgetStateProperty.all(LumioColors.primary),
        todayBackgroundColor: WidgetStateProperty.all(LumioColors.primaryDark),
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.dialog,
        ),
      ),

      // Time Picker Theme
      timePickerTheme: TimePickerThemeData(
        backgroundColor: LumioColors.surfaceDark,
        hourMinuteColor: LumioColors.primaryDark,
        hourMinuteTextColor: LumioColors.primary,
        dialBackgroundColor: LumioColors.backgroundDark,
        dialHandColor: LumioColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.dialog,
        ),
      ),

      // Popup Menu Theme
      popupMenuTheme: PopupMenuThemeData(
        color: LumioColors.surfaceDark,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.radiusMD,
        ),
        textStyle: LumioTypography.bodyMedium.copyWith(
          color: LumioColors.textPrimaryDark,
        ),
      ),

      // Drawer Theme
      drawerTheme: DrawerThemeData(
        backgroundColor: LumioColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: LumioRadius.only(
            topRight: LumioRadius.xl,
            bottomRight: LumioRadius.xl,
          ),
        ),
      ),

      // Extensions
      extensions: const <ThemeExtension<dynamic>>[
        LumioThemeExtension.dark,
      ],
    );
  }
}

// ============================================================
// THEME EXTENSION - For custom properties not in ThemeData
// ============================================================

/// Custom theme extension for Lumio-specific properties
class LumioThemeExtension extends ThemeExtension<LumioThemeExtension> {
  final Color cardBackground;
  final Color cardBorder;
  final List<BoxShadow> cardShadow;
  final List<BoxShadow> navShadow;
  final List<BoxShadow> fabShadow;
  final LinearGradient warmGradient;
  final LinearGradient profileGradient;

  const LumioThemeExtension({
    required this.cardBackground,
    required this.cardBorder,
    required this.cardShadow,
    required this.navShadow,
    required this.fabShadow,
    required this.warmGradient,
    required this.profileGradient,
  });

  /// Light mode extension
  static const light = LumioThemeExtension(
    cardBackground: LumioColors.surfaceLight,
    cardBorder: LumioColors.borderLight,
    cardShadow: LumioShadows.soft,
    navShadow: LumioShadows.nav,
    fabShadow: [], // Will use LumioShadows.fab dynamically
    warmGradient: LumioColors.warmGradient,
    profileGradient: LumioColors.profileGradientLight,
  );

  /// Dark mode extension
  static const dark = LumioThemeExtension(
    cardBackground: LumioColors.surfaceDark,
    cardBorder: LumioColors.borderDark,
    cardShadow: LumioShadows.softDark,
    navShadow: LumioShadows.navDark,
    fabShadow: [], // Will use LumioShadows.fab dynamically
    warmGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1E1E1E), Color(0xFF121212)],
    ),
    profileGradient: LumioColors.profileGradientDark,
  );

  @override
  LumioThemeExtension copyWith({
    Color? cardBackground,
    Color? cardBorder,
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? navShadow,
    List<BoxShadow>? fabShadow,
    LinearGradient? warmGradient,
    LinearGradient? profileGradient,
  }) {
    return LumioThemeExtension(
      cardBackground: cardBackground ?? this.cardBackground,
      cardBorder: cardBorder ?? this.cardBorder,
      cardShadow: cardShadow ?? this.cardShadow,
      navShadow: navShadow ?? this.navShadow,
      fabShadow: fabShadow ?? this.fabShadow,
      warmGradient: warmGradient ?? this.warmGradient,
      profileGradient: profileGradient ?? this.profileGradient,
    );
  }

  @override
  LumioThemeExtension lerp(ThemeExtension<LumioThemeExtension>? other, double t) {
    if (other is! LumioThemeExtension) {
      return this;
    }
    return LumioThemeExtension(
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
      navShadow: t < 0.5 ? navShadow : other.navShadow,
      fabShadow: t < 0.5 ? fabShadow : other.fabShadow,
      warmGradient: t < 0.5 ? warmGradient : other.warmGradient,
      profileGradient: t < 0.5 ? profileGradient : other.profileGradient,
    );
  }

  /// Get the extension from context
  static LumioThemeExtension of(BuildContext context) {
    return Theme.of(context).extension<LumioThemeExtension>() ?? light;
  }
}
