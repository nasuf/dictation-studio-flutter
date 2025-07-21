import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

class AppLogger {
  static final Logger _logger = Logger('DictationStudio');
  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;

    // Configure logging
    Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;
    Logger.root.onRecord.listen((record) {
      if (kDebugMode) {
        // In debug mode, print to console with emoji prefixes
        final emoji = _getEmojiForLevel(record.level);
        print('$emoji ${record.loggerName}: ${record.message}');
        if (record.error != null) {
          print('❌ Error: ${record.error}');
        }
        if (record.stackTrace != null) {
          print('📚 Stack trace: ${record.stackTrace}');
        }
      }
    });

    _initialized = true;
  }

  static String _getEmojiForLevel(Level level) {
    switch (level) {
      case Level.SEVERE:
        return '🚨';
      case Level.WARNING:
        return '⚠️';
      case Level.INFO:
        return 'ℹ️';
      case Level.CONFIG:
        return '⚙️';
      case Level.FINE:
        return '🔍';
      case Level.FINER:
        return '🔬';
      case Level.FINEST:
        return '🔎';
      default:
        return '📝';
    }
  }

  // Convenience methods for different log levels
  static void severe(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.severe(message, error, stackTrace);
  }

  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.warning(message, error, stackTrace);
  }

  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.info(message, error, stackTrace);
  }

  static void config(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.config(message, error, stackTrace);
  }

  static void fine(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.fine(message, error, stackTrace);
  }

  static void finer(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.finer(message, error, stackTrace);
  }

  static void finest(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.finest(message, error, stackTrace);
  }

  // Specialized logging methods for different app components
  static void auth(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.info('🔐 AUTH: $message', error, stackTrace);
  }

  static void api(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.info('📡 API: $message', error, stackTrace);
  }

  static void video(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.info('🎬 VIDEO: $message', error, stackTrace);
  }

  static void channel(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.info('📺 CHANNEL: $message', error, stackTrace);
  }

  static void navigation(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    _logger.info('🧭 NAV: $message', error, stackTrace);
  }

  static void token(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.info('🔑 TOKEN: $message', error, stackTrace);
  }

  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.fine('🔍 DEBUG: $message', error, stackTrace);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.severe('❌ ERROR: $message', error, stackTrace);
  }

  static void success(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.info('✅ SUCCESS: $message', error, stackTrace);
  }
}
