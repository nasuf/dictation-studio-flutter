import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// Theme mode options
enum AppThemeMode {
  light,
  dark,
  system,
}

/// Theme service for managing light/dark mode throughout the app
class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';
  static ThemeService? _instance;
  
  AppThemeMode _themeMode = AppThemeMode.light;
  SharedPreferences? _prefs;
  
  ThemeService._();
  
  static ThemeService get instance {
    _instance ??= ThemeService._();
    return _instance!;
  }
  
  /// Get current theme mode
  AppThemeMode get themeMode => _themeMode;
  
  /// Get effective brightness based on current theme mode
  Brightness getEffectiveBrightness(BuildContext context) {
    switch (_themeMode) {
      case AppThemeMode.light:
        return Brightness.light;
      case AppThemeMode.dark:
        return Brightness.dark;
      case AppThemeMode.system:
        return MediaQuery.of(context).platformBrightness;
    }
  }
  
  /// Check if current theme is dark
  bool isDarkMode(BuildContext context) {
    return getEffectiveBrightness(context) == Brightness.dark;
  }
  
  /// Initialize theme service from stored preferences
  Future<void> initialize() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final storedTheme = _prefs!.getString(_themeKey);
      
      if (storedTheme != null) {
        _themeMode = AppThemeMode.values.firstWhere(
          (mode) => mode.name == storedTheme,
          orElse: () => AppThemeMode.system,
        );
      }
      
      AppLogger.info('Theme service initialized with theme: $_themeMode');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Failed to initialize theme service: $e');
      _themeMode = AppThemeMode.system;
    }
  }
  
  /// Set theme mode and persist to storage
  Future<void> setThemeMode(AppThemeMode mode) async {
    try {
      _themeMode = mode;
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_themeKey, mode.name);
      
      AppLogger.info('Theme mode changed to: $mode');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Failed to save theme mode: $e');
    }
  }
  
  /// Toggle between light and dark modes (skips system mode)
  Future<void> toggleTheme() async {
    switch (_themeMode) {
      case AppThemeMode.light:
        await setThemeMode(AppThemeMode.dark);
        break;
      case AppThemeMode.dark:
      case AppThemeMode.system:
        await setThemeMode(AppThemeMode.light);
        break;
    }
  }
}

/// Extension for theme mode display names
extension AppThemeModeExtension on AppThemeMode {
  String get displayName {
    switch (this) {
      case AppThemeMode.light:
        return 'Light Mode';
      case AppThemeMode.dark:
        return 'Dark Mode';
      case AppThemeMode.system:
        return 'Follow System';
    }
  }
  
  IconData get icon {
    switch (this) {
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.system:
        return Icons.brightness_auto;
    }
  }
}