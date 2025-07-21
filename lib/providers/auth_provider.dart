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

  // Getters
  models.User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;

  // Initialize authentication state
  Future<void> initialize() async {
    _setLoading(true);
    try {
      // Check if user is already logged in
      final session = _supabase.auth.currentSession;
      if (session?.user != null) {
        AppLogger.info('👤 Found existing session, loading user...');
        await _loadUserFromSession(session!.user);
      } else {
        AppLogger.info('🚫 No existing session found');
      }

      // Listen to auth state changes
      _supabase.auth.onAuthStateChange.listen((AuthState state) {
        AppLogger.info('🔄 Auth state changed: ${state.event}');
        switch (state.event) {
          case AuthChangeEvent.signedIn:
            if (state.session?.user != null) {
              AppLogger.info('✅ User signed in successfully');
              _loadUserFromSession(state.session!.user);
            }
            break;
          case AuthChangeEvent.signedOut:
            AppLogger.info('🚪 User signed out');
            _currentUser = null;
            _clearUserFromPrefs();
            notifyListeners();
            break;
          default:
            break;
        }
      });
    } catch (e) {
      AppLogger.error('❌ Initialize error: $e');
      _setError('Failed to initialize authentication: ${e.toString()}');
    } finally {
      _setLoading(false);
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

      // Call backend API to login/register user
      final apiResponse = await _apiService.login(email, username, avatar);

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
      role: 'user',
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
  Future<void> logout() async {
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

      notifyListeners();
      AppLogger.info('✅ User logged out and data cleared');
    } catch (e) {
      AppLogger.error('❌ Logout error: $e');
      _setError('Logout failed: ${e.toString()}');

      // Force clear everything even if logout fails
      _currentUser = null;
      await _clearUserFromPrefs();
      await TokenManager.clearTokens();
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
}
