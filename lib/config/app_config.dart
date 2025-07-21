import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

enum Environment { development, production }

class AppConfig {
  final String uiHost;
  final String serviceHost;
  final String servicePath;
  final String appName;
  final bool debug;
  final int apiTimeout;

  const AppConfig({
    required this.uiHost,
    required this.serviceHost,
    required this.servicePath,
    required this.appName,
    required this.debug,
    required this.apiTimeout,
  });

  // Get base URL for API calls
  String get baseUrl => '$serviceHost$servicePath';
}

class AppEnvironment {
  static const Map<Environment, AppConfig> _configs = {
    Environment.development: AppConfig(
      uiHost: 'http://localhost:5173',
      serviceHost: 'https://www.dictationstudio.com',
      servicePath: '/ds',
      appName: 'Dictation Studio (Dev)',
      debug: true,
      apiTimeout: 120000, // 2 minutes for development
    ),
    Environment.production: AppConfig(
      uiHost: 'https://www.dictationstudio.com',
      serviceHost: 'https://www.dictationstudio.com',
      servicePath: '/ds',
      appName: 'Dictation Studio',
      debug: false,
      apiTimeout: 120000, // 2 minutes for production
    ),
  };

  // Current environment - always use production for HTTPS
  static Environment get currentEnvironment {
    // Always use production environment for HTTPS
    return Environment.production;
  }

  // Get current config based on environment
  static AppConfig get config => _configs[currentEnvironment]!;

  // Print environment info in debug mode
  static void printEnvironmentInfo() {
    if (kDebugMode) {
      final env = currentEnvironment;
      final cfg = config;

      AppLogger.info('🚀 Current environment: ${env.name}');
      AppLogger.info('📱 App name: ${cfg.appName}');
      AppLogger.info('📡 Service host: ${cfg.serviceHost}');
      AppLogger.info('🔗 Service path: ${cfg.servicePath}');
      AppLogger.info('🌐 Base URL: ${cfg.baseUrl}');
      AppLogger.info('🐛 Debug mode: ${cfg.debug}');
      AppLogger.info('⏱️ API timeout: ${cfg.apiTimeout}ms');
    }
  }

  // Get base URL for different environments and platforms
  static String getBaseUrlForPlatform() {
    final cfg = config;

    if (currentEnvironment == Environment.development) {
      // For development, we need different URLs for different platforms
      if (kIsWeb) {
        // Web can access localhost directly
        return 'https://www.dictationstudio.com/ds';
      } else {
        // Mobile platforms need special handling
        return _getMobileDevUrl();
      }
    } else {
      // Production uses the same URL for all platforms
      return cfg.baseUrl;
    }
  }

  // Get appropriate URL for mobile development
  static String _getMobileDevUrl() {
    // Check if we're running on Android emulator
    // Android emulator uses 10.0.2.2 to access host machine's localhost
    // iOS simulator can use localhost directly

    // For now, default to Android emulator format
    // Users can override this if needed for physical devices
    return 'https://www.dictationstudio.com/ds';

    // For physical device testing, users would need to use their local IP:
    // return 'http://192.168.1.XXX:4001/dictation-studio';
  }

  // Override base URL for testing with physical devices
  static String? _overrideBaseUrl;

  static void setOverrideBaseUrl(String? url) {
    _overrideBaseUrl = url;
    if (kDebugMode && url != null) {
      AppLogger.info('🔧 Base URL overridden to: $url');
    }
  }

  static String get effectiveBaseUrl {
    return _overrideBaseUrl ?? getBaseUrlForPlatform();
  }
}
