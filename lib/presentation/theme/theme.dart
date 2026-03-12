/// Lumio Design System
///
/// A comprehensive theme system for the Lumio app based on Stitch AI mockups.
///
/// Import this file to access all theme components:
/// ```dart
/// import 'package:lumio/presentation/theme/theme.dart';
/// ```
///
/// ## Components
///
/// ### Colors
/// ```dart
/// Container(color: LumioColors.primary)
/// Container(color: LumioColors.background(context)) // Context-aware
/// ```
///
/// ### Typography
/// ```dart
/// Text('Hello', style: LumioTypography.headlineLarge)
/// Text('World', style: LumioTypography.bodyMediumSecondary(context))
/// ```
///
/// ### Spacing
/// ```dart
/// Padding(padding: LumioSpacing.paddingMD)
/// SizedBox(height: LumioSpacing.lg)
/// LumioSpacing.verticalGap16 // Pre-built SizedBox
/// ```
///
/// ### Shadows
/// ```dart
/// Container(
///   decoration: BoxDecoration(
///     boxShadow: LumioShadows.getSoft(context),
///   ),
/// )
/// ```
///
/// ### Border Radius
/// ```dart
/// Container(
///   decoration: BoxDecoration(
///     borderRadius: LumioRadius.card,
///   ),
/// )
/// ```
///
/// ### Complete Theme
/// ```dart
/// MaterialApp(
///   theme: LumioTheme.light,
///   darkTheme: LumioTheme.dark,
///   themeMode: ThemeMode.system,
/// )
/// ```
///
/// ### Theme Extension
/// ```dart
/// final ext = LumioThemeExtension.of(context);
/// Container(
///   decoration: BoxDecoration(
///     gradient: ext.profileGradient,
///     boxShadow: ext.cardShadow,
///   ),
/// )
/// ```

library lumio_theme;

export 'lumio_colors.dart';
export 'lumio_typography.dart';
export 'lumio_spacing.dart';
export 'lumio_shadows.dart';
export 'lumio_radius.dart';
export 'lumio_theme.dart';

// Legacy support (deprecated)
export 'app_theme.dart' show AppTheme;
