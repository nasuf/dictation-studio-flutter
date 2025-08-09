import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/logger.dart';

class YouTubeLoginService {
  static const String _loginStateKey = 'youtube_login_state';
  static const String _cookiesKey = 'youtube_cookies';
  
  // YouTube login URL with embedded player permissions
  static const String _youtubeLoginUrl = 'https://accounts.google.com/signin/v2/identifier?service=youtube&continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Faction_handle_signin%3Dtrue%26app%3Ddesktop%26hl%3Den%26next%3D%252F&hl=en&passive=true&flowName=GlifWebSignIn&flowEntry=ServiceLogin';
  
  WebViewController? _controller;
  bool _isLoggedIn = false;
  String? _userInfo;
  bool _hasCalledLoginSuccess = false; // 防止重复调用登录成功回调
  
  // Singleton pattern
  static final YouTubeLoginService _instance = YouTubeLoginService._internal();
  factory YouTubeLoginService() => _instance;
  YouTubeLoginService._internal();
  
  bool get isLoggedIn => _isLoggedIn;
  String? get userInfo => _userInfo;
  
  /// Initialize the service and check stored login state
  Future<void> initialize() async {
    await _loadStoredLoginState();
  }
  
  /// Load stored login state from SharedPreferences
  Future<void> _loadStoredLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool(_loginStateKey) ?? false;
      _userInfo = prefs.getString('youtube_user_info');
      
      AppLogger.info('YouTube login state loaded: $_isLoggedIn');
      if (_userInfo != null) {
        AppLogger.info('User info: $_userInfo');
      }
    } catch (e) {
      AppLogger.error('Failed to load YouTube login state: $e');
    }
  }
  
  /// Save login state to SharedPreferences
  Future<void> _saveLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_loginStateKey, _isLoggedIn);
      if (_userInfo != null) {
        await prefs.setString('youtube_user_info', _userInfo!);
      }
      
      AppLogger.info('YouTube login state saved: $_isLoggedIn');
    } catch (e) {
      AppLogger.error('Failed to save YouTube login state: $e');
    }
  }
  
  /// Create WebViewController for YouTube login
  WebViewController createLoginWebViewController({
    required VoidCallback onLoginSuccess,
    required Function(String) onLoginError,
  }) {
    // Reset the callback flag for new login session
    _hasCalledLoginSuccess = false;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            AppLogger.info('YouTube login progress: $progress%');
          },
          onPageStarted: (String url) {
            AppLogger.info('YouTube login page started: $url');
            _handleNavigationChange(url, onLoginSuccess, onLoginError);
          },
          onPageFinished: (String url) {
            AppLogger.info('YouTube login page finished: $url');
            _checkLoginStatus(url, onLoginSuccess, onLoginError);
          },
          onWebResourceError: (WebResourceError error) {
            AppLogger.error('YouTube login WebView error: ${error.description}');
            onLoginError('Login failed: ${error.description}');
          },
        ),
      )
      ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1')
      ..loadRequest(Uri.parse(_youtubeLoginUrl));
    
    return _controller!;
  }
  
  /// Handle navigation changes to detect login success
  void _handleNavigationChange(
    String url, 
    VoidCallback onLoginSuccess, 
    Function(String) onLoginError,
  ) {
    AppLogger.info('Navigation change: $url');
    
    // Check for successful login redirect
    if (url.contains('youtube.com') && !url.contains('accounts.google.com')) {
      AppLogger.info('Detected YouTube redirect - login might be successful');
      _checkLoginStatus(url, onLoginSuccess, onLoginError);
    }
    
    // Check for login errors
    if (url.contains('error') || url.contains('denied')) {
      AppLogger.warning('Login error detected in URL: $url');
      onLoginError('Login was denied or failed');
    }
  }
  
  /// Check if user is successfully logged in by examining the page
  Future<void> _checkLoginStatus(
    String url, 
    VoidCallback onLoginSuccess, 
    Function(String) onLoginError,
  ) async {
    if (_controller == null) return;
    
    try {
      // Check if we're on YouTube main page (indicates successful login)
      if (url.startsWith('https://www.youtube.com') && !url.contains('accounts')) {
        AppLogger.info('On YouTube main page - checking login status');
        
        // Execute JavaScript to check if user is logged in
        final result = await _controller!.runJavaScriptReturningResult('''
          (function() {
            // Check for user avatar or sign-in button
            const avatar = document.querySelector('[id="avatar-btn"]');
            const signInButton = document.querySelector('[aria-label="Sign in"]');
            const userMenu = document.querySelector('#avatar-btn');
            
            if (avatar && !signInButton) {
              // User is logged in - try to get user info
              const channelName = document.querySelector('#avatar-btn img')?.alt || 'YouTube User';
              return JSON.stringify({
                loggedIn: true,
                userInfo: channelName
              });
            } else {
              return JSON.stringify({
                loggedIn: false,
                userInfo: null
              });
            }
          })();
        ''');
        
        AppLogger.info('Login status check result: $result');
        
        // Parse the result
        if (result.toString().contains('loggedIn":true')) {
          _isLoggedIn = true;
          
          // Extract user info if available
          final userInfoMatch = RegExp(r'"userInfo":"([^"]*)"').firstMatch(result.toString());
          if (userInfoMatch != null) {
            _userInfo = userInfoMatch.group(1);
          }
          
          await _saveLoginState();
          await _saveCookies();
          
          AppLogger.info('YouTube login successful! User: $_userInfo');
          
          // Only call the success callback once per login session
          if (!_hasCalledLoginSuccess) {
            _hasCalledLoginSuccess = true;
            onLoginSuccess();
          } else {
            AppLogger.info('Login success callback already called, skipping duplicate call');
          }
        } else {
          AppLogger.info('User not logged in yet, continuing...');
        }
      }
    } catch (e) {
      AppLogger.error('Error checking login status: $e');
      onLoginError('Failed to verify login status: $e');
    }
  }
  
  /// Save cookies to share with YouTube Player
  Future<void> _saveCookies() async {
    if (_controller == null) return;
    
    try {
      // Get cookies using JavaScript execution since getCookies is not available
      final cookieResult = await _controller!.runJavaScriptReturningResult('document.cookie');
      final cookieString = cookieResult.toString();
      
      AppLogger.info('Retrieved cookie string: $cookieString');
      
      // Parse cookie string and extract meaningful cookies
      final cookies = <Map<String, String>>[];
      if (cookieString.isNotEmpty && cookieString != 'null') {
        final cookiePairs = cookieString.split(';');
        for (final pair in cookiePairs) {
          final trimmed = pair.trim();
          if (trimmed.isNotEmpty) {
            final parts = trimmed.split('=');
            if (parts.length >= 2) {
              cookies.add({
                'name': parts[0],
                'value': parts.sublist(1).join('='), // Handle values with = in them
                'domain': '.youtube.com',
                'path': '/',
              });
            }
          }
        }
      }
      
      final prefs = await SharedPreferences.getInstance();
      
      // Save cookie data
      await prefs.setString('youtube_cookies_data', 
          const JsonEncoder().convert(cookies));
      await prefs.setString(_cookiesKey, 'youtube_cookies_saved');
      
      AppLogger.info('YouTube cookies saved: ${cookies.length} cookies parsed from cookie string');
    } catch (e) {
      AppLogger.error('Failed to save YouTube cookies: $e');
    }
  }
  
  /// Apply stored cookies to YouTube Player WebView
  Future<void> applyCookiesToPlayer(WebViewController playerController) async {
    try {
      if (!_isLoggedIn) {
        AppLogger.info('Not logged in, skipping cookie application');
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final cookieManager = WebViewCookieManager();
      
      // Load and apply YouTube cookies
      final youtubeCookieDataString = prefs.getString('youtube_cookies_data');
      if (youtubeCookieDataString != null) {
        try {
          final youtubeCookieList = const JsonDecoder().convert(youtubeCookieDataString) as List<dynamic>;
          for (final cookieData in youtubeCookieList) {
            final cookieMap = cookieData as Map<String, dynamic>;
            final cookie = WebViewCookie(
              name: cookieMap['name'] as String,
              value: cookieMap['value'] as String,
              domain: cookieMap['domain'] as String,
              path: cookieMap['path'] as String? ?? '/',
            );
            await cookieManager.setCookie(cookie);
          }
          AppLogger.info('Applied ${youtubeCookieList.length} YouTube cookies to player');
        } catch (e) {
          AppLogger.error('Failed to parse YouTube cookies: $e');
        }
      }
      
      // Add a marker cookie to indicate login state
      await cookieManager.setCookie(const WebViewCookie(
        name: 'youtube_login_shared',
        value: 'true',
        domain: '.youtube.com',
        path: '/',
      ));
      
      AppLogger.info('YouTube login cookies applied to player');
    } catch (e) {
      AppLogger.error('Failed to apply cookies to player: $e');
    }
  }
  
  /// Logout and clear stored data
  Future<void> logout() async {
    try {
      _isLoggedIn = false;
      _userInfo = null;
      
      // Clear stored preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_loginStateKey);
      await prefs.remove('youtube_user_info');
      await prefs.remove(_cookiesKey);
      await prefs.remove('youtube_cookies_data');
      
      // Clear WebView cookies
      final cookieManager = WebViewCookieManager();
      await cookieManager.clearCookies();
      
      AppLogger.info('YouTube logout completed');
    } catch (e) {
      AppLogger.error('Failed to logout from YouTube: $e');
    }
  }
  
  /// Check if we need to show login prompt
  bool shouldShowLoginPrompt() {
    return !_isLoggedIn;
  }
  
  /// Get login URL for manual browser login (fallback)
  String getLoginUrl() {
    return _youtubeLoginUrl;
  }
  
  /// Manually mark as logged in (when user confirms login completion)
  Future<void> markAsLoggedIn({String? userInfo}) async {
    _isLoggedIn = true;
    _userInfo = userInfo ?? 'YouTube User';
    _hasCalledLoginSuccess = true; // Mark as called to prevent auto-detection from firing
    await _saveLoginState();
    await _saveCookies();
    AppLogger.info('Manually marked as logged in: $_userInfo');
  }
  
  /// Force refresh YouTube player cookies (for use after login)
  Future<void> refreshPlayerCookies() async {
    try {
      if (!_isLoggedIn) {
        AppLogger.info('Not logged in, cannot refresh player cookies');
        return;
      }
      
      final cookieManager = WebViewCookieManager();
      
      // Clear existing YouTube cookies
      await cookieManager.clearCookies();
      
      // Wait a moment for cookies to clear
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Re-apply saved cookies
      final prefs = await SharedPreferences.getInstance();
      
      // Apply YouTube cookies
      final youtubeCookieDataString = prefs.getString('youtube_cookies_data');
      if (youtubeCookieDataString != null) {
        try {
          final youtubeCookieList = const JsonDecoder().convert(youtubeCookieDataString) as List<dynamic>;
          for (final cookieData in youtubeCookieList) {
            final cookieMap = cookieData as Map<String, dynamic>;
            final cookie = WebViewCookie(
              name: cookieMap['name'] as String,
              value: cookieMap['value'] as String,
              domain: cookieMap['domain'] as String,
              path: cookieMap['path'] as String? ?? '/',
            );
            await cookieManager.setCookie(cookie);
          }
          AppLogger.info('Refreshed ${youtubeCookieList.length} YouTube cookies');
        } catch (e) {
          AppLogger.error('Failed to refresh YouTube cookies: $e');
        }
      }
      
      AppLogger.info('Player cookies refreshed successfully');
    } catch (e) {
      AppLogger.error('Failed to refresh player cookies: $e');
    }
  }
  
  /// Get login token for YouTube API usage (Android specific fix)
  Future<String?> getYouTubeApiToken() async {
    try {
      if (!_isLoggedIn) {
        return null;
      }
      
      final prefs = await SharedPreferences.getInstance();
      
      // Try to extract auth token from cookies
      final youtubeCookieDataString = prefs.getString('youtube_cookies_data');
      if (youtubeCookieDataString != null) {
        try {
          final youtubeCookieList = const JsonDecoder().convert(youtubeCookieDataString) as List<dynamic>;
          
          for (final cookieData in youtubeCookieList) {
            final cookieMap = cookieData as Map<String, dynamic>;
            if (cookieMap['name'] == 'SAPISID' || 
                cookieMap['name'] == '__Secure-3PAPISID' ||
                cookieMap['name'] == 'SSID') {
              return cookieMap['value'] as String?;
            }
          }
        } catch (e) {
          AppLogger.error('Failed to parse cookies for API token: $e');
        }
      }
      
      return 'logged_in'; // Fallback indicator
    } catch (e) {
      AppLogger.error('Failed to get YouTube API token: $e');
      return null;
    }
  }
}