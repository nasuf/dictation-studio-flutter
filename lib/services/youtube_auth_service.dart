import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// Enhanced YouTube authentication service with multiple login methods
class YouTubeAuthService {
  static const String _authStateKey = 'youtube_auth_state';
  static const String _authTokenKey = 'youtube_auth_token';
  static const String _authMethodKey = 'youtube_auth_method';

  // Singleton pattern
  static final YouTubeAuthService _instance = YouTubeAuthService._internal();
  factory YouTubeAuthService() => _instance;
  YouTubeAuthService._internal();

  bool _isAuthenticated = false;
  String? _accessToken;
  String? _userInfo;
  AuthMethod _currentMethod = AuthMethod.none;

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  String? get accessToken => _accessToken;
  String? get userInfo => _userInfo;
  AuthMethod get currentMethod => _currentMethod;

  /// Initialize the service
  Future<void> initialize() async {
    await _loadStoredAuthState();
  }

  /// Load stored authentication state
  Future<void> _loadStoredAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAuthenticated = prefs.getBool(_authStateKey) ?? false;
      _accessToken = prefs.getString(_authTokenKey);
      _userInfo = prefs.getString('youtube_user_info');

      final methodIndex = prefs.getInt(_authMethodKey) ?? 0;
      _currentMethod = AuthMethod.values[methodIndex];

      AppLogger.info(
        'YouTube auth state loaded: $_isAuthenticated via $_currentMethod',
      );
    } catch (e) {
      AppLogger.error('Failed to load YouTube auth state: $e');
    }
  }

  /// Save authentication state
  Future<void> _saveAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_authStateKey, _isAuthenticated);
      if (_accessToken != null) {
        await prefs.setString(_authTokenKey, _accessToken!);
      }
      if (_userInfo != null) {
        await prefs.setString('youtube_user_info', _userInfo!);
      }
      await prefs.setInt(_authMethodKey, _currentMethod.index);

      AppLogger.info(
        'YouTube auth state saved: $_isAuthenticated via $_currentMethod',
      );
    } catch (e) {
      AppLogger.error('Failed to save YouTube auth state: $e');
    }
  }

  /// Method 1: Google Sign-In with YouTube scope
  Future<AuthResult> signInWithGoogle() async {
    try {
      AppLogger.info('Attempting Google Sign-In with YouTube scope');

      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: [
          'https://www.googleapis.com/auth/youtube.readonly',
          'https://www.googleapis.com/auth/youtube',
        ],
      );

      // Sign out first to force account selection
      await googleSignIn.signOut();

      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) {
        return AuthResult(false, 'User cancelled sign-in', AuthMethod.none);
      }

      final GoogleSignInAuthentication auth = await account.authentication;

      _isAuthenticated = true;
      _accessToken = auth.accessToken;
      _userInfo = account.displayName ?? account.email;
      _currentMethod = AuthMethod.googleSignIn;

      await _saveAuthState();

      AppLogger.info('Google Sign-In successful: ${account.email}');
      return AuthResult(
        true,
        'Google Sign-In successful',
        AuthMethod.googleSignIn,
      );
    } catch (e) {
      AppLogger.error('Google Sign-In failed: $e');
      return AuthResult(false, 'Google Sign-In failed: $e', AuthMethod.none);
    }
  }

  /// Method 2: System browser login
  Future<AuthResult> signInWithBrowser() async {
    try {
      AppLogger.info('Attempting system browser login');

      const String youtubeUrl = 'https://www.youtube.com/signin';
      final Uri url = Uri.parse(youtubeUrl);

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);

        // Mark as authenticated (user will manually confirm)
        _isAuthenticated = true;
        _currentMethod = AuthMethod.systemBrowser;
        _userInfo = 'Browser Login';

        await _saveAuthState();

        AppLogger.info('System browser login initiated');
        return AuthResult(
          true,
          'Please complete login in browser and return to app',
          AuthMethod.systemBrowser,
        );
      } else {
        return AuthResult(false, 'Cannot open browser', AuthMethod.none);
      }
    } catch (e) {
      AppLogger.error('System browser login failed: $e');
      return AuthResult(
        false,
        'System browser login failed: $e',
        AuthMethod.none,
      );
    }
  }

  /// Method 3: YouTube app login
  Future<AuthResult> signInWithYouTubeApp() async {
    try {
      AppLogger.info('Attempting YouTube app login');

      // Try YouTube app URL scheme
      const String youtubeAppUrl = 'youtube://';
      final Uri appUrl = Uri.parse(youtubeAppUrl);

      if (await canLaunchUrl(appUrl)) {
        await launchUrl(appUrl, mode: LaunchMode.externalApplication);

        // Mark as authenticated (user will manually confirm)
        _isAuthenticated = true;
        _currentMethod = AuthMethod.youtubeApp;
        _userInfo = 'YouTube App';

        await _saveAuthState();

        AppLogger.info('YouTube app login initiated');
        return AuthResult(
          true,
          'Please login in YouTube app and return',
          AuthMethod.youtubeApp,
        );
      } else {
        // Fallback to YouTube mobile website
        return await _signInWithMobileYouTube();
      }
    } catch (e) {
      AppLogger.error('YouTube app login failed: $e');
      return AuthResult(false, 'YouTube app login failed: $e', AuthMethod.none);
    }
  }

  /// Fallback: Mobile YouTube website
  Future<AuthResult> _signInWithMobileYouTube() async {
    try {
      AppLogger.info('Attempting mobile YouTube login');

      const String mobileYoutubeUrl = 'https://m.youtube.com/signin';
      final Uri url = Uri.parse(mobileYoutubeUrl);

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);

        _isAuthenticated = true;
        _currentMethod = AuthMethod.mobileBrowser;
        _userInfo = 'Mobile Browser';

        await _saveAuthState();

        AppLogger.info('Mobile YouTube login initiated');
        return AuthResult(
          true,
          'Please complete login in mobile browser',
          AuthMethod.mobileBrowser,
        );
      } else {
        return AuthResult(false, 'Cannot open mobile browser', AuthMethod.none);
      }
    } catch (e) {
      AppLogger.error('Mobile YouTube login failed: $e');
      return AuthResult(
        false,
        'Mobile YouTube login failed: $e',
        AuthMethod.none,
      );
    }
  }

  /// Method 4: No-login public access
  Future<AuthResult> usePublicAccess() async {
    try {
      AppLogger.info('Using public access mode');

      _isAuthenticated = false; // Explicitly not authenticated
      _currentMethod = AuthMethod.publicAccess;
      _userInfo = 'Public Access';
      _accessToken = null;

      await _saveAuthState();

      AppLogger.info('Public access mode enabled');
      return AuthResult(
        true,
        'Using public access - some features may be limited',
        AuthMethod.publicAccess,
      );
    } catch (e) {
      AppLogger.error('Public access setup failed: $e');
      return AuthResult(
        false,
        'Public access setup failed: $e',
        AuthMethod.none,
      );
    }
  }

  /// Check if YouTube app is installed
  Future<bool> isYouTubeAppInstalled() async {
    try {
      const String youtubeAppUrl = 'youtube://';
      final Uri appUrl = Uri.parse(youtubeAppUrl);
      return await canLaunchUrl(appUrl);
    } catch (e) {
      AppLogger.error('Failed to check YouTube app: $e');
      return false;
    }
  }

  /// Logout from current method
  Future<void> logout() async {
    try {
      AppLogger.info('Logging out from $_currentMethod');

      // If using Google Sign-In, sign out properly
      if (_currentMethod == AuthMethod.googleSignIn) {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
      }

      // Clear stored state
      _isAuthenticated = false;
      _accessToken = null;
      _userInfo = null;
      _currentMethod = AuthMethod.none;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authStateKey);
      await prefs.remove(_authTokenKey);
      await prefs.remove(_authMethodKey);
      await prefs.remove('youtube_user_info');

      AppLogger.info('YouTube logout completed');
    } catch (e) {
      AppLogger.error('Failed to logout: $e');
    }
  }

  /// Get auth headers for API calls
  Map<String, String> getAuthHeaders() {
    if (_accessToken != null) {
      return {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      };
    }
    return {'Content-Type': 'application/json'};
  }

  /// Manually confirm authentication (for browser/app methods)
  Future<void> confirmAuthentication({String? userInfo}) async {
    _isAuthenticated = true;
    if (userInfo != null) {
      _userInfo = userInfo;
    }
    await _saveAuthState();
    AppLogger.info('Authentication manually confirmed');
  }
}

/// Authentication methods
enum AuthMethod {
  none,
  googleSignIn,
  systemBrowser,
  youtubeApp,
  mobileBrowser,
  publicAccess,
}

/// Authentication result
class AuthResult {
  final bool success;
  final String message;
  final AuthMethod method;

  const AuthResult(this.success, this.message, this.method);
}

/// Extension for AuthMethod display names
extension AuthMethodExtension on AuthMethod {
  String get displayName {
    switch (this) {
      case AuthMethod.none:
        return 'Not authenticated';
      case AuthMethod.googleSignIn:
        return 'Google Sign-In';
      case AuthMethod.systemBrowser:
        return 'System Browser';
      case AuthMethod.youtubeApp:
        return 'YouTube App';
      case AuthMethod.mobileBrowser:
        return 'Mobile Browser';
      case AuthMethod.publicAccess:
        return 'Public Access';
    }
  }

  String get description {
    switch (this) {
      case AuthMethod.none:
        return 'No authentication method selected';
      case AuthMethod.googleSignIn:
        return 'Signed in with Google account';
      case AuthMethod.systemBrowser:
        return 'Logged in via system browser';
      case AuthMethod.youtubeApp:
        return 'Logged in via YouTube app';
      case AuthMethod.mobileBrowser:
        return 'Logged in via mobile browser';
      case AuthMethod.publicAccess:
        return 'Using public access (limited features)';
    }
  }
}
