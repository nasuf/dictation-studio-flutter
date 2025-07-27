import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

/// A floating action button for toggling between light and dark themes
class ThemeToggleButton extends StatelessWidget {
  final bool mini;
  final String? tooltip;
  
  const ThemeToggleButton({
    super.key,
    this.mini = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDark = themeService.isDarkMode(context);
        
        return FloatingActionButton(
          mini: mini,
          tooltip: tooltip ?? (isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode'),
          onPressed: () => themeService.toggleTheme(),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return RotationTransition(
                turns: animation,
                child: child,
              );
            },
            child: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              key: ValueKey(isDark),
            ),
          ),
        );
      },
    );
  }
}

/// An icon button version of the theme toggle
class ThemeToggleIconButton extends StatelessWidget {
  final String? tooltip;
  
  const ThemeToggleIconButton({
    super.key,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDark = themeService.isDarkMode(context);
        
        return IconButton(
          tooltip: tooltip ?? (isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode'),
          onPressed: () => themeService.toggleTheme(),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return RotationTransition(
                turns: animation,
                child: child,
              );
            },
            child: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              key: ValueKey(isDark),
            ),
          ),
        );
      },
    );
  }
}

/// A more detailed theme selector dialog
class ThemeSettingsDialog extends StatelessWidget {
  const ThemeSettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.palette),
              SizedBox(width: 8),
              Text('Theme Settings'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppThemeMode.values.map((mode) {
              return RadioListTile<AppThemeMode>(
                title: Row(
                  children: [
                    Icon(mode.icon),
                    const SizedBox(width: 12),
                    Text(mode.displayName),
                  ],
                ),
                subtitle: Text(_getThemeModeDescription(mode)),
                value: mode,
                groupValue: themeService.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    themeService.setThemeMode(value);
                  }
                },
                contentPadding: EdgeInsets.zero,
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
  
  String _getThemeModeDescription(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'Always use light theme';
      case AppThemeMode.dark:
        return 'Always use dark theme';
      case AppThemeMode.system:
        return 'Follow system setting';
    }
  }
}

/// A list tile for theme settings in settings pages
class ThemeSettingsListTile extends StatelessWidget {
  const ThemeSettingsListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDark = themeService.isDarkMode(context);
        
        return ListTile(
          leading: Icon(
            isDark ? Icons.dark_mode : Icons.light_mode,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: const Text('Theme Mode'),
          subtitle: Text(themeService.themeMode.displayName),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => const ThemeSettingsDialog(),
            );
          },
        );
      },
    );
  }
}