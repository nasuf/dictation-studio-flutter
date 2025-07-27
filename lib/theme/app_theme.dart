import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// App theme configuration providing both light and dark themes
class AppTheme {
  // Color constants for light green theme
  static const Color _lightPrimary = Color(0xFF4CAF50);        // Green 500
  static const Color _lightPrimaryContainer = Color(0xFFE8F5E8); // Very light green
  static const Color _lightSecondary = Color(0xFF8BC34A);       // Light green 500
  static const Color _lightSecondaryContainer = Color(0xFFF1F8E9); // Very light lime
  static const Color _lightTertiary = Color(0xFF009688);        // Teal 500
  static const Color _lightSurface = Colors.white;
  static const Color _lightSurfaceContainerHighest = Color(0xFFF1F8E9);
  static const Color _lightOnSurface = Color(0xFF1B5E20);       // Dark green for text
  static const Color _lightOutline = Color(0xFF81C784);         // Medium green for borders
  
  // Color constants for dark green theme (complementary to light theme)
  static const Color _darkPrimary = Color(0xFF81C784);          // Light green 300 
  static const Color _darkPrimaryContainer = Color(0xFF2E7D32); // Green 800
  static const Color _darkSecondary = Color(0xFFA5D6A7);        // Light green 200
  static const Color _darkSecondaryContainer = Color(0xFF388E3C); // Green 700
  static const Color _darkTertiary = Color(0xFF4DB6AC);         // Teal 300
  static const Color _darkSurface = Color(0xFF0F1419);          // Very dark blue-gray
  static const Color _darkSurfaceContainer = Color(0xFF1A1F24); // Dark blue-gray
  static const Color _darkSurfaceContainerHighest = Color(0xFF2A2F34); // Medium dark gray
  static const Color _darkOnSurface = Color(0xFFE8F5E8);        // Very light green for text
  static const Color _darkOnSurfaceVariant = Color(0xFFA5D6A7); // Light green for secondary text
  static const Color _darkOutline = Color(0xFF4CAF50);          // Green for borders
  static const Color _darkShadow = Color(0xFF000000);

  /// Create light theme with light green color scheme
  static ThemeData lightTheme() {
    final lightGreenColorScheme = ColorScheme.fromSeed(
      seedColor: _lightPrimary,
      brightness: Brightness.light,
      primary: _lightPrimary,
      primaryContainer: _lightPrimaryContainer,
      secondary: _lightSecondary,
      secondaryContainer: _lightSecondaryContainer,
      tertiary: _lightTertiary,
      surface: _lightSurface,
      surfaceContainerHighest: _lightSurfaceContainerHighest,
      onSurface: _lightOnSurface,
      outline: _lightOutline,
      shadow: Colors.black.withValues(alpha: 0.1),
    );

    return _buildTheme(lightGreenColorScheme, Brightness.light);
  }

  /// Create dark theme with dark green color scheme
  static ThemeData darkTheme() {
    final darkGreenColorScheme = ColorScheme.fromSeed(
      seedColor: _darkPrimary,
      brightness: Brightness.dark,
      // Custom overrides for cohesive dark green theme
      primary: _darkPrimary,
      primaryContainer: _darkPrimaryContainer,
      secondary: _darkSecondary,
      secondaryContainer: _darkSecondaryContainer,
      tertiary: _darkTertiary,
      surface: _darkSurface,
      surfaceContainer: _darkSurfaceContainer,
      surfaceContainerHighest: _darkSurfaceContainerHighest,
      onSurface: _darkOnSurface,
      onSurfaceVariant: _darkOnSurfaceVariant,
      outline: _darkOutline,
      shadow: _darkShadow.withValues(alpha: 0.3),
      // Ensure proper contrast for dark theme
      onPrimary: Color(0xFF003300),        // Very dark green for text on primary
      onPrimaryContainer: Color(0xFFE8F5E8), // Light green for text on primary container
      onSecondary: Color(0xFF003300),      // Very dark green for text on secondary
      onSecondaryContainer: Color(0xFFE8F5E8), // Light green for text on secondary container
      onTertiary: Color(0xFF003300),       // Very dark green for text on tertiary
      error: Color(0xFFCF6679),            // Soft red for errors in dark theme
      onError: Color(0xFF000000),          // Black text on error
      inverseSurface: Color(0xFFE8F5E8),   // Light green for inverse elements
      onInverseSurface: Color(0xFF1B5E20), // Dark green for text on inverse surface
    );

    return _buildTheme(darkGreenColorScheme, Brightness.dark);
  }

  /// Build theme with shared component styling
  static ThemeData _buildTheme(ColorScheme colorScheme, Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      
      // AppBar theme
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: isDark ? 2 : 1,
        shadowColor: colorScheme.shadow,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.primary,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.0,
        ),
        iconTheme: IconThemeData(
          color: colorScheme.primary,
          size: 24,
        ),
        actionsIconTheme: IconThemeData(
          color: colorScheme.primary,
          size: 24,
        ),
        systemOverlayStyle: isDark 
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: colorScheme.surface,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: colorScheme.surface,
            ),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: isDark ? 2 : 1,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.outline.withValues(alpha: 0.12),
          disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),
      
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
          side: BorderSide(color: colorScheme.outline),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),

      // FAB theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: isDark ? 4 : 3,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        elevation: isDark ? 2 : 1,
        shadowColor: colorScheme.shadow,
        surfaceTintColor: colorScheme.surfaceContainerHighest,
        color: isDark ? colorScheme.surfaceContainer : colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        deleteIconColor: colorScheme.onSurfaceVariant,
        disabledColor: colorScheme.onSurface.withValues(alpha: 0.12),
        selectedColor: colorScheme.secondaryContainer,
        secondarySelectedColor: colorScheme.secondary,
        shadowColor: colorScheme.shadow,
        labelStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(
          color: colorScheme.onSecondaryContainer,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        brightness: brightness,
        elevation: 0,
        pressElevation: isDark ? 2 : 1,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 16,
        ),
        labelStyle: TextStyle(
          color: colorScheme.primary,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: colorScheme.outline,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: colorScheme.outline,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // Navigation theme
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
        elevation: isDark ? 3 : 0,
        shadowColor: colorScheme.shadow,
        surfaceTintColor: colorScheme.surfaceContainerHighest,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: colorScheme.onSecondaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            );
          }
          return TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: colorScheme.onSecondaryContainer,
              size: 24,
            );
          }
          return IconThemeData(
            color: colorScheme.onSurfaceVariant,
            size: 24,
          );
        }),
      ),

      // SnackBar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: colorScheme.onInverseSurface,
          fontSize: 14,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: isDark ? 4 : 3,
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceContainerHighest,
        elevation: isDark ? 6 : 3,
        shadowColor: colorScheme.shadow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w400,
        ),
        contentTextStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Progress indicator theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
        circularTrackColor: colorScheme.surfaceContainerHighest,
      ),

      // Scaffold background
      scaffoldBackgroundColor: colorScheme.surface,
      
      // Drawer theme for better dark mode support
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceContainerHighest,
        elevation: isDark ? 4 : 1,
        shadowColor: colorScheme.shadow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
      ),

      // Bottom sheet theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceContainerHighest,
        elevation: isDark ? 4 : 1,
        shadowColor: colorScheme.shadow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
      ),

      // List tile theme
      listTileTheme: ListTileThemeData(
        textColor: colorScheme.onSurface,
        iconColor: colorScheme.onSurfaceVariant,
        selectedColor: colorScheme.primary,
        selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      
      // Typography
      fontFamily: 'Roboto',
      textTheme: TextTheme(
        displayLarge: TextStyle(color: colorScheme.onSurface),
        displayMedium: TextStyle(color: colorScheme.onSurface),
        displaySmall: TextStyle(color: colorScheme.onSurface),
        headlineLarge: TextStyle(color: colorScheme.onSurface),
        headlineMedium: TextStyle(color: colorScheme.onSurface),
        headlineSmall: TextStyle(color: colorScheme.onSurface),
        titleLarge: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
        titleMedium: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
        labelLarge: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: colorScheme.onSurface),
        bodyMedium: TextStyle(color: colorScheme.onSurface),
        bodySmall: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      
      // Icon theme
      iconTheme: IconThemeData(
        color: colorScheme.onSurfaceVariant,
        size: 24,
      ),
      
      primaryIconTheme: IconThemeData(
        color: colorScheme.onPrimary,
        size: 24,
      ),
    );
  }
}