import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user.dart' as models;
import '../services/api_service.dart';
import '../services/token_manager.dart';
import '../utils/logger.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ApiService _apiService = ApiService();

  models.User? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  // Getters
  models.User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;

  // Initialize authentication state
  Future<void> initialize() async {
    // Prevent multiple initializations
    if (_isInitialized) {
      print('⚠️ [AuthProvider] Already initialized, skipping...');
      return;
    }
    
    _setLoading(true);
    try {
      AppLogger.info('🔄 Starting AuthProvider initialization...');
      print('🔄 [AuthProvider] Starting AuthProvider initialization...');
      
      // Check if user is already logged in
      final session = _supabase.auth.currentSession;
      print('🔍 [AuthProvider] Supabase session check: ${session?.user.email ?? 'null'}');
      print('🔍 [AuthProvider] Session expires at: ${session?.expiresAt}');
      print('🔍 [AuthProvider] Current time: ${DateTime.now().millisecondsSinceEpoch ~/ 1000}');
      
      if (session?.user != null) {
        // Check if session is still valid
        final isSessionValid = session!.expiresAt != null && 
            DateTime.now().millisecondsSinceEpoch < session.expiresAt! * 1000;
        
        print('🔍 [AuthProvider] Session valid: $isSessionValid');
        
        if (isSessionValid) {
          AppLogger.info('👤 Found valid Supabase session, loading user...');
          print('👤 [AuthProvider] Found valid Supabase session, loading user...');
          await _loadUserFromSession(session.user);
        } else {
          AppLogger.info('⚠️ Supabase session expired, trying to refresh...');
          print('⚠️ [AuthProvider] Supabase session expired, trying to refresh...');
          
          try {
            // Try to refresh the session
            final refreshResult = await _supabase.auth.refreshSession();
            if (refreshResult.session?.user != null) {
              AppLogger.info('✅ Session refreshed successfully');
              print('✅ [AuthProvider] Session refreshed successfully');
              await _loadUserFromSession(refreshResult.session!.user);
            } else {
              AppLogger.info('❌ Session refresh failed, checking cached data...');
              print('❌ [AuthProvider] Session refresh failed, checking cached data...');
              await _loadCachedUserData();
            }
          } catch (e) {
            AppLogger.warning('⚠️ Session refresh error: $e, checking cached data...');
            print('⚠️ [AuthProvider] Session refresh error: $e, checking cached data...');
            await _loadCachedUserData();
          }
        }
      } else {
        AppLogger.info('❌ No Supabase session found, checking cached data...');
        print('❌ [AuthProvider] No Supabase session found, checking cached data...');
        // Only load cached data if no session exists at all
        await _loadCachedUserData();
      }

      print('🔍 [AuthProvider] After initialization - isLoggedIn: $isLoggedIn, currentUser: ${_currentUser?.email ?? 'null'}');

      // Listen to auth state changes
      _supabase.auth.onAuthStateChange.listen((AuthState state) {
        AppLogger.info('🔄 Auth state changed: ${state.event}');
        print('🔄 [AuthProvider] Auth state changed: ${state.event}');
        switch (state.event) {
          case AuthChangeEvent.signedIn:
            if (state.session?.user != null) {
              AppLogger.info('✅ User signed in successfully');
              print('✅ [AuthProvider] User signed in successfully');
              _loadUserFromSession(state.session!.user);
            }
            break;
          case AuthChangeEvent.signedOut:
            AppLogger.info('🚪 User signed out');
            print('🚪 [AuthProvider] User signed out');
            _currentUser = null;
            _clearUserFromPrefs();
            notifyListeners();
            break;
          default:
            break;
        }
      });
      
      _isInitialized = true;
      AppLogger.info('✅ AuthProvider initialization completed');
      print('✅ [AuthProvider] AuthProvider initialization completed');
    } catch (e) {
      AppLogger.error('❌ AuthProvider initialize error: $e');
      print('❌ [AuthProvider] AuthProvider initialize error: $e');
      _setError('Failed to initialize authentication: ${e.toString()}');
    } finally {
      _setLoading(false);
      print('🏁 [AuthProvider] Loading set to false');
    }
  }

  // Load cached user data as fallback (but don't consider user as logged in without valid session)
  Future<void> _loadCachedUserData() async {
    try {
      print('🔍 [AuthProvider] Attempting to load cached user data...');
      final prefs = await SharedPreferences.getInstance();
      final userJsonString = prefs.getString('current_user');
      print('🔍 [AuthProvider] Cached user data: ${userJsonString != null ? 'found' : 'not found'}');
      if (userJsonString != null) {
        final userJson = jsonDecode(userJsonString) as Map<String, dynamic>;
        
        // Don't set _currentUser directly - we need to verify the session first
        // Instead, we'll try to restore the session with cached data
        print('🔍 [AuthProvider] Found cached user: ${userJson['email']}');
        
        // Since we have cached user data but no valid session, the user is not logged in
        // We should clear the cached data to force re-login
        print('⚠️ [AuthProvider] Cached user data found but no valid session - clearing cache');
        await _clearUserFromPrefs();
        _currentUser = null;
        
        AppLogger.info('⚠️ Cached user data cleared due to invalid session');
      } else {
        print('❌ [AuthProvider] No cached user data found');
        _currentUser = null;
      }
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Failed to load cached user data: $e');
      print('❌ [AuthProvider] Failed to load cached user data: $e');
      _currentUser = null;
      notifyListeners();
    }
  }

  // Deterministic password encryption (matching React logic)
  String _encryptPasswordDeterministic(String password, String email) {
    final combinedData = '$password$email';
    final bytes = utf8.encode(combinedData);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Register with email and password
  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required String avatar,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Encrypt password deterministically
      final encryptedPassword = _encryptPasswordDeterministic(password, email);

      final response = await _supabase.auth.signUp(
        email: email,
        password: encryptedPassword,
        data: {'full_name': fullName, 'avatar_url': avatar},
      );

      if (response.user != null) {
        // Registration successful
        return true;
      } else {
        _setError('Registration failed');
        return false;
      }
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Registration failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Login with email and password (dual strategy like React)
  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      
      bool loginSuccess = false;
      AuthResponse? authResponse;

      // Strategy 1: Try encrypted password first (for new users)
      try {
        final encryptedPassword = _encryptPasswordDeterministic(
          password,
          email,
        );
        authResponse = await _supabase.auth.signInWithPassword(
          email: email,
          password: encryptedPassword,
        );

        if (authResponse.user != null) {
          loginSuccess = true;
          AppLogger.info('Login successful with encrypted password');
        }
      } catch (e) {
        AppLogger.info(
          'Encrypted password login failed, trying original password...',
        );
      }

      // Strategy 2: If encrypted password fails, try original password (for existing users)
      if (!loginSuccess) {
        try {
          authResponse = await _supabase.auth.signInWithPassword(
            email: email,
            password: password,
          );

          if (authResponse.user != null) {
            loginSuccess = true;
            AppLogger.info(
              'Login successful with original password - migrating to encrypted password...',
            );

            // Migrate user to encrypted password
            try {
              final encryptedPassword = _encryptPasswordDeterministic(
                password,
                email,
              );
              await _supabase.auth.updateUser(
                UserAttributes(password: encryptedPassword),
              );
              AppLogger.info(
                'Successfully migrated user to encrypted password',
              );
            } catch (migrationError) {
              AppLogger.error('Password migration failed: $migrationError');
              // Don't fail the login if migration fails
            }
          }
        } catch (e) {
          AppLogger.error('Original password login also failed: $e');
        }
      }

      if (!loginSuccess || authResponse?.user == null) {
        _setError('Invalid email or password');
        return false;
      }

      // Load user data and call backend API
      await _loadUserFromSession(authResponse!.user!);
      return true;
    } catch (e) {
      _setError('Login failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Google Sign-In using Supabase OAuth (simplified and improved)
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _setError(null);

    try {
      AppLogger.info('🔑 Starting Google Sign-In via Supabase OAuth...');

      // Use external browser for better compatibility with Android
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'dictationstudioflutter://auth-callback',
        authScreenLaunchMode:
            LaunchMode.externalApplication, // Use external browser
      );

      if (response) {
        AppLogger.info('✅ OAuth flow initiated successfully');

        // For OAuth flow, we return true immediately and let the auth state listener handle the rest
        // The deep link service will process the callback and trigger auth state changes
        return true;
      } else {
        AppLogger.error('❌ Failed to initiate OAuth flow');
        _setError('Failed to initiate Google sign-in. Please try again.');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ Google OAuth error: $e');

      // Provide more specific error messages
      String errorMessage = 'Google login failed';
      if (e.toString().contains('cancel') || e.toString().contains('Cancel')) {
        errorMessage = 'Google login was cancelled';
      } else if (e.toString().contains('network') ||
          e.toString().contains('Network')) {
        errorMessage =
            'Network error during Google login. Please check your internet connection.';
      } else if (e.toString().contains('browser') ||
          e.toString().contains('Browser')) {
        errorMessage = 'Could not open browser for Google login';
      } else if (e.toString().contains('CONNECTION_CLOSED') ||
          e.toString().contains('connection')) {
        errorMessage =
            'Connection to authentication server failed. Please try again.';
      }

      _setError(errorMessage);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Load user from Supabase session and call backend API
  Future<void> _loadUserFromSession(User supabaseUser) async {
    try {
      final userData = supabaseUser.userMetadata ?? {};
      final email = supabaseUser.email ?? '';
      final username =
          userData['full_name'] ?? userData['name'] ?? 'Unknown User';
      final avatar = userData['avatar_url'] ?? userData['picture'] ?? '';

      AppLogger.info('🔄 Loading user from session...');
      AppLogger.info('Supabase user email: $email');
      AppLogger.info('Username from metadata: $username');
      AppLogger.info('Avatar from metadata: $avatar');

      // Call backend API to login/register user with timeout
      final apiResponse = await _apiService.login(email, username, avatar)
          .timeout(const Duration(seconds: 10));

      if (apiResponse.containsKey('user')) {
        // Create user object from backend response
        final userJson = apiResponse['user'] as Map<String, dynamic>;
        _currentUser = models.User.fromJson(userJson);

        await _saveUserToPrefs(_currentUser!);
        notifyListeners();
        AppLogger.info(
          '✅ User loaded and saved successfully: ${_currentUser!.username}',
        );
      } else {
        AppLogger.warning(
          '⚠️ No user data in API response, creating local user',
        );
        await _createFallbackUser(supabaseUser, userData);
      }
    } catch (e) {
      AppLogger.error('❌ Failed to load user from session: $e');
      // Even if API fails, create a basic user from Supabase data
      final userData = supabaseUser.userMetadata ?? {};
      await _createFallbackUser(supabaseUser, userData);
    }
  }

  // Create a fallback user when API call fails
  Future<void> _createFallbackUser(
    User supabaseUser,
    Map<String, dynamic> userData,
  ) async {
    _currentUser = models.User(
      id: supabaseUser.id,
      email: supabaseUser.email ?? '',
      username: userData['full_name'] ?? userData['name'] ?? 'Unknown User',
      avatar: userData['avatar_url'] ?? userData['picture'] ?? '',
      language: 'en',
      plan: models.Plan(name: 'Free', status: 'active'),
      role: 'User',  // Fixed: Use capitalized 'User' to match backend default
      dictationConfig: models.DictationConfig(shortcuts: models.ShortcutKeys()),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _saveUserToPrefs(_currentUser!);
    notifyListeners();
    AppLogger.info(
      '✅ Created fallback user from Supabase data: ${_currentUser!.username}',
    );
  }

  // Logout
  Future<void> logout({VoidCallback? onClearCache}) async {
    _setLoading(true);
    try {
      AppLogger.info('🚪 Logging out user...');

      // Call backend logout API if we have tokens
      final accessToken = await TokenManager.getAccessToken();
      if (accessToken != null) {
        try {
          await _apiService.logout();
          AppLogger.info('✅ Backend logout successful');
        } catch (e) {
          AppLogger.warning('⚠️ Backend logout failed: $e');
          // Continue with logout even if backend call fails
        }
      }

      // Sign out from Supabase
      await _supabase.auth.signOut();
      AppLogger.info('✅ Supabase logout successful');

      // Clear user data and tokens (TokenManager.clearTokens() is called in logout API)
      _currentUser = null;
      await _clearUserFromPrefs();

      // Clear other caches if callback is provided
      onClearCache?.call();
      AppLogger.info('✅ External caches cleared');

      notifyListeners();
      AppLogger.info('✅ User logged out and data cleared');
    } catch (e) {
      AppLogger.error('❌ Logout error: $e');
      _setError('Logout failed: ${e.toString()}');

      // Force clear everything even if logout fails
      _currentUser = null;
      await _clearUserFromPrefs();
      await TokenManager.clearTokens();
      
      // Clear other caches even if logout fails
      onClearCache?.call();
      AppLogger.info('✅ External caches cleared (fallback)');
      
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // Save user to shared preferences
  Future<void> _saveUserToPrefs(models.User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', jsonEncode(user.toJson()));
  }

  // Clear user from shared preferences
  Future<void> _clearUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
  }

  // Update user language
  Future<void> updateUserLanguage(String language) async {
    if (_currentUser != null) {
      try {
        await _apiService.saveUserConfig({'language': language});
        _currentUser = _currentUser!.copyWith(language: language);
        await _saveUserToPrefs(_currentUser!);
        notifyListeners();
      } catch (e) {
        AppLogger.error('Failed to update user language: $e');
      }
    }
  }

  // Refresh user data from backend (e.g., after config changes)
  Future<void> refreshUserData() async {
    final supabaseUser = _supabase.auth.currentUser;
    if (supabaseUser != null) {
      AppLogger.info('🔄 Refreshing user data from backend...');
      await _loadUserFromSession(supabaseUser);
    }
  }
}
