import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Application theme configuration using Material 3
/// Premium, minimal design system with modern aesthetics
class AppTheme {
  // Brand Colors - Premium gradient palette
  static const Color primaryColor = Color(0xFF6366F1); // Indigo - Modern, trustworthy
  static const Color primaryLight = Color(0xFF818CF8); // Light Indigo
  static const Color primaryDark = Color(0xFF4F46E5); // Dark Indigo
  static const Color secondaryColor = Color(0xFF8B5CF6); // Purple
  static const Color accentColor = Color(0xFF10B981); // Emerald Green
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color successColor = Color(0xFF10B981); // Green
  static const Color warningColor = Color(0xFFF59E0B); // Amber

  // Context Colors - Softer, more refined
  static const Color timeColor = Color(0xFF3B82F6); // Blue
  static const Color locationColor = Color(0xFFEC4899); // Pink
  static const Color wifiColor = Color(0xFF06B6D4); // Cyan
  static const Color activityColor = Color(0xFF8B5CF6); // Purple

  // Neutral Colors - Subtle grays for premium feel
  static const Color backgroundColor = Color(0xFFFAFBFC); // Soft white
  static const Color surfaceColor = Colors.white;
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A); // Deep charcoal
  static const Color textSecondary = Color(0xFF64748B); // Muted gray
  static const Color textTertiary = Color(0xFF94A3B8); // Light gray
  
  // Border and Divider Colors
  static const Color borderColor = Color(0xFFE2E8F0); // Very light gray
  static const Color dividerColor = Color(0xFFF1F5F9); // Subtle divider
  
  // Dark Mode Colors - Material 3 baseline
  static const Color darkBackground = Color(0xFF000000); // Pure black for maximum contrast
  static const Color darkSurface = Color(0xFF0F0F0F); // Card surface - slightly lighter than background
  static const Color darkSurfaceElevated = Color(0xFF1A1A1A); // Elevated cards
  static const Color darkTextPrimary = Color(0xFFFFFFFF); // White with 87% opacity in practice
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Muted text (60% opacity)
  static const Color darkTextTertiary = Color(0xFF64748B); // Very muted (38% opacity)
  static const Color darkBorder = Color(0xFF2A2A2A); // Subtle border
  static const Color darkDivider = Color(0xFF1A1A1A); // Divider
  
  // Shadow Colors - Soft, modern shadows
  static const Color shadowColor = Color(0x1A000000); // 10% opacity
  
  // Spacing Constants - Consistent spacing system
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;
  
  // Border Radius - Modern rounded corners
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusRound = 999.0;

  /// Light theme - Premium, minimal design
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme().apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        error: errorColor,
        surface: surfaceColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        displayMedium: textTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(
          color: textPrimary,
          size: 24,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLG),
          side: const BorderSide(color: borderColor, width: 1),
        ),
        color: surfaceColor,
        shadowColor: shadowColor,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 8,
        highlightElevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLG),
        ),
        iconSize: 24,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMD,
          vertical: spacingMD,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: textTertiary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingXL,
            vertical: spacingMD,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMD),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingXL,
            vertical: spacingMD,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMD),
          ),
          side: const BorderSide(color: primaryColor, width: 1.5),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSM),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: backgroundColor,
        deleteIconColor: textSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusRound),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Dark theme - Premium dark mode (Material 3 baseline)
  static ThemeData get darkTheme {
    // Use static constants defined above
    
    // Neon accent colors for highlights
    const neonBlue = Color(0xFF3B82F6);
    const neonPurple = Color(0xFF8B5CF6);
    const neonMint = Color(0xFF10B981);
    
    final textTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: AppTheme.darkTextPrimary,
      displayColor: AppTheme.darkTextPrimary,
    );
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryLight,
        secondary: secondaryColor,
        tertiary: accentColor,
        error: errorColor,
        surface: AppTheme.darkSurface,
        background: AppTheme.darkBackground, // Ensure background is set
      ),
      scaffoldBackgroundColor: AppTheme.darkBackground, // Force dark background
      canvasColor: AppTheme.darkBackground, // Canvas color
      cardColor: AppTheme.darkSurface, // Card color
      dialogBackgroundColor: AppTheme.darkSurface, // Dialog background
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: AppTheme.darkTextPrimary.withOpacity(0.87), // 87% opacity
        ),
        displayMedium: textTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: darkTextPrimary.withOpacity(0.87),
        ),
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: darkTextPrimary.withOpacity(0.87),
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: darkTextPrimary.withOpacity(0.87),
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w400,
          color: darkTextPrimary.withOpacity(0.87),
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w400,
          color: AppTheme.darkTextSecondary, // 60% opacity
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w400,
          color: AppTheme.darkTextTertiary, // 38% opacity
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.darkTextPrimary,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppTheme.darkTextPrimary,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(
          color: AppTheme.darkTextPrimary,
          size: 24,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLG),
          side: BorderSide(color: AppTheme.darkBorder.withOpacity(0.5), width: 1),
        ),
        color: AppTheme.darkSurface,
        shadowColor: Colors.black.withOpacity(0.3),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 8,
        highlightElevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLG),
        ),
        iconSize: 24,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTheme.darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMD,
          vertical: spacingMD,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: AppTheme.darkBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: AppTheme.darkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: darkTextSecondary,
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppTheme.darkTextSecondary.withOpacity(0.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingXL,
            vertical: spacingMD,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMD),
          ),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryLight,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingXL,
            vertical: spacingMD,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMD),
          ),
          side: const BorderSide(color: primaryLight, width: 1.5),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppTheme.darkDivider,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppTheme.darkSurface,
        deleteIconColor: AppTheme.darkTextSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusRound),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  /// Helper method to get shadow for elevated surfaces
  static List<BoxShadow> getElevationShadow(int level, {bool isDark = false}) {
    // Clamp level to valid range
    final clampedLevel = level.clamp(0, 4);
    
    if (isDark) {
      // Dark mode shadows - softer, more subtle
      switch (clampedLevel) {
        case 0:
          return <BoxShadow>[];
        case 1:
          return [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ];
        case 2:
          return [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ];
        case 3:
          return [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ];
        case 4:
          return [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ];
        default:
          return [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ];
      }
    } else {
      // Light mode shadows
      switch (clampedLevel) {
        case 0:
          return <BoxShadow>[];
        case 1:
          return const [
            BoxShadow(
              color: shadowColor,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ];
        case 2:
          return const [
            BoxShadow(
              color: shadowColor,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ];
        case 3:
          return const [
            BoxShadow(
              color: shadowColor,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ];
        case 4:
          return const [
            BoxShadow(
              color: shadowColor,
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ];
        default:
          return const [
            BoxShadow(
              color: shadowColor,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ];
      }
    }
  }
  
  /// Get gradient for cards (subtle, never flat)
  static LinearGradient getCardGradient({bool isDark = false}) {
    if (isDark) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF1A1A1A),
          const Color(0xFF0F0F0F),
        ],
      );
    } else {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          const Color(0xFFFAFBFC),
        ],
      );
    }
  }
  
  /// Get neon accent color for highlights
  static Color getNeonAccent({String type = 'blue'}) {
    switch (type) {
      case 'blue':
        return const Color(0xFF3B82F6);
      case 'purple':
        return const Color(0xFF8B5CF6);
      case 'mint':
        return const Color(0xFF10B981);
      default:
        return primaryColor;
    }
  }
}
