import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import 'logger.dart';

/// Development tools for easy API endpoint configuration
class DevTools {
  // Common development URLs
  static const String androidEmulator = 'http://10.0.2.2:4001/dictation-studio';
  static const String iOSSimulator = 'http://localhost:4001/dictation-studio';

  // For physical device testing, replace with your local IP
  static const String physicalDevice =
      'http://192.168.1.100:4001/dictation-studio';

  /// Switch to Android emulator URL (default)
  static void useAndroidEmulator() {
    if (kDebugMode) {
      AppEnvironment.setOverrideBaseUrl(androidEmulator);
      AppLogger.info('Switched to Android emulator URL: $androidEmulator');
    }
  }

  /// Switch to iOS simulator URL
  static void useIOSSimulator() {
    if (kDebugMode) {
      AppEnvironment.setOverrideBaseUrl(iOSSimulator);
      AppLogger.info('Switched to iOS simulator URL: $iOSSimulator');
    }
  }

  /// Switch to physical device URL (requires manual IP configuration)
  static void usePhysicalDevice([String? customIP]) {
    if (kDebugMode) {
      final url = customIP != null
          ? 'http://$customIP:4001/dictation-studio'
          : physicalDevice;
      AppEnvironment.setOverrideBaseUrl(url);
      AppLogger.info('Switched to physical device URL: $url');
      if (customIP == null) {
        AppLogger.info(
          '💡 To use your own IP, call: DevTools.usePhysicalDevice("YOUR_IP")',
        );
      }
    }
  }

  /// Reset to default environment-based URL
  static void resetToDefault() {
    if (kDebugMode) {
      AppEnvironment.setOverrideBaseUrl(null);
      AppLogger.info('Reset to default environment URL');
    }
  }

  /// Use custom URL for testing
  static void useCustomUrl(String baseUrl) {
    if (kDebugMode) {
      AppEnvironment.setOverrideBaseUrl(baseUrl);
      AppLogger.info('Using custom URL: $baseUrl');
    }
  }

  /// Print current configuration
  static void printCurrentConfig() {
    if (kDebugMode) {
      AppLogger.info('\n📱 === Current API Configuration ===');
      AppLogger.info('Environment: ${AppEnvironment.currentEnvironment.name}');
      AppLogger.info('Base URL: ${AppEnvironment.effectiveBaseUrl}');
      AppLogger.info('Timeout: ${AppEnvironment.config.apiTimeout}ms');
      AppLogger.info('App Name: ${AppEnvironment.config.appName}');
      AppLogger.info('===================================\n');
    }
  }
}
