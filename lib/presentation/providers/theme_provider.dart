import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing app theme (Light/Dark/System)
class ThemeProvider with ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  
  ThemeMode _themeMode = ThemeMode.light;
  
  ThemeProvider() {
    _loadThemeMode();
  }
  
  ThemeMode get themeMode => _themeMode;
  
  /// Load saved theme preference
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_themeModeKey);
      
      if (savedMode != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.toString() == savedMode,
          orElse: () => ThemeMode.light,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading theme mode: $e');
    }
  }
  
  /// Set theme mode and save preference
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.toString());
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }
  
  /// Toggle between light and dark (ignoring system)
  Future<void> toggleTheme() async {
    final newMode = _themeMode == ThemeMode.light 
        ? ThemeMode.dark 
        : ThemeMode.light;
    await setThemeMode(newMode);
  }
  
  /// Check if dark mode is currently active
  bool isDarkMode(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark;
  }
}

