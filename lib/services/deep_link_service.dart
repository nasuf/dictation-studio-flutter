import 'dart:async';
import 'package:app_links/app_links.dart';
import '../utils/logger.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  bool _isInitialized = false;

  // Initialize deep link handling
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.info('🔗 Deep link service already initialized, skipping...');
      return;
    }

    try {
      AppLogger.info('🔗 Initializing deep link service...');

      // Handle app links when app is already running
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) {
          AppLogger.info('📱 Received deep link: $uri');
          _handleDeepLink(uri);
        },
        onError: (err) {
          AppLogger.error('❌ Deep link error: $err');
        },
      );

      // Handle the initial link if app was opened via deep link
      try {
        final initialUri = await _appLinks.getInitialLink();
        if (initialUri != null) {
          AppLogger.info('🚀 App opened with deep link: $initialUri');
          _handleDeepLink(initialUri);
        }
      } catch (e) {
        AppLogger.warning('⚠️ Failed to get initial link: $e');
        // Don't fail initialization if getting initial link fails
      }

      _isInitialized = true;
      AppLogger.success('✅ Deep link service initialized');
    } catch (e) {
      AppLogger.error('❌ Failed to initialize deep link service: $e');
      rethrow;
    }
  }

  // Handle incoming deep links
  void _handleDeepLink(Uri uri) {
    AppLogger.info('🔗 Processing deep link: ${uri.toString()}');

    // Check if this is an OAuth callback
    if (uri.scheme == 'dictationstudioflutter' && uri.host == 'auth-callback') {
      AppLogger.info('🔑 OAuth callback detected');
      _handleOAuthCallback(uri);
    } else {
      AppLogger.info('ℹ️ Unknown deep link format: ${uri.toString()}');
    }
  }

  // Handle OAuth callback
  void _handleOAuthCallback(Uri uri) {
    try {
      AppLogger.info('🔑 Processing OAuth callback...');

      // Extract query parameters
      final params = uri.queryParameters;
      AppLogger.info('📝 OAuth params: $params');

      // Check for error
      if (params.containsKey('error')) {
        final error = params['error'];
        final errorDescription = params['error_description'];
        AppLogger.error('❌ OAuth error: $error - $errorDescription');
        return;
      }

      // Check for access token or code
      if (params.containsKey('access_token') || params.containsKey('code')) {
        AppLogger.info('✅ OAuth success - tokens received');

        // Supabase will automatically handle the session
        // The auth state listener will pick up the change
      } else {
        AppLogger.warning('⚠️ OAuth callback missing expected parameters');
      }
    } catch (e) {
      AppLogger.error('❌ Error processing OAuth callback: $e');
    }
  }

  // Dispose resources
  void dispose() {
    _linkSubscription?.cancel();
    AppLogger.info('🧹 Deep link service disposed');
  }
}
