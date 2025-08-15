import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/logger.dart';

class YouTubeLoginService {
  static const String _loginStateKey = 'youtube_login_state';
  static const String _cookiesKey = 'youtube_cookies';
  
  // YouTube login URL - using mobile-friendly login flow to avoid WebView restrictions
  static const String _youtubeLoginUrl = 'https://accounts.google.com/signin/v2/identifier?service=youtube&continue=https%3A%2F%2Fm.youtube.com%2Fsignin%3Faction_handle_signin%3Dtrue%26app%3Dmobile%26hl%3Den&hl=en&passive=true&flowName=GlifWebSignIn&flowEntry=ServiceLogin';
  
  // Backup mobile login URL for better compatibility
  static const String _mobileYoutubeLoginUrl = 'https://m.youtube.com/signin';
  
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
  Future<WebViewController> createLoginWebViewController({
    required VoidCallback onLoginSuccess,
    required Function(String) onLoginError,
  }) async {
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
          onNavigationRequest: (NavigationRequest request) {
            AppLogger.info('Navigation request to: ${request.url}');
            // Allow all YouTube and Google navigation
            if (request.url.contains('google.com') || 
                request.url.contains('youtube.com') ||
                request.url.contains('gstatic.com') ||
                request.url.contains('googleapis.com')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      );

    // Use latest Mobile Safari User-Agent for better Google compatibility
    await _controller!.setUserAgent(
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1'
    );

    // Load the login URL
    await _controller!.loadRequest(Uri.parse(_youtubeLoginUrl));
    
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
        
        // Execute JavaScript to check if user is logged in with enhanced detection
        final result = await _controller!.runJavaScriptReturningResult('''
          (function() {
            // Wait a moment for page elements to load
            return new Promise((resolve) => {
              setTimeout(() => {
                try {
                  // Multiple methods to detect login state
                  const avatar = document.querySelector('[id="avatar-btn"]');
                  const avatarImg = document.querySelector('#avatar-btn img');
                  const signInButton = document.querySelector('[aria-label="Sign in"]');
                  const userMenu = document.querySelector('#avatar-btn');
                  const accountMenu = document.querySelector('[aria-label="Account menu"]');
                  
                  // Check for login indicators in URL or page content
                  const isLoggedInURL = window.location.href.includes('youtube.com') && 
                                        !window.location.href.includes('accounts.google.com');
                  
                  // Check for presence of user data in the page
                  const hasUserData = document.querySelector('[data-sessionlink*="signin"]') === null;
                  
                  // Check cookies for auth indicators
                  const hasAuthCookie = document.cookie.includes('SAPISID') || 
                                       document.cookie.includes('LOGIN_INFO') ||
                                       document.cookie.includes('SSID');
                  
                  let loggedIn = false;
                  let userInfo = null;
                  
                  if ((avatar && !signInButton) || accountMenu || hasAuthCookie) {
                    loggedIn = true;
                    // Try to extract user info
                    userInfo = avatarImg?.alt || 
                              avatarImg?.title ||
                              document.querySelector('[aria-label*="channel"]')?.textContent ||
                              'YouTube User';
                  }
                  
                  // Additional checks for mobile layout
                  if (!loggedIn && isLoggedInURL) {
                    const mobileAvatar = document.querySelector('img[alt*="Avatar"]');
                    const mobileUserButton = document.querySelector('[aria-label*="Account"]');
                    if (mobileAvatar || mobileUserButton || hasAuthCookie) {
                      loggedIn = true;
                      userInfo = mobileAvatar?.alt || 'YouTube User';
                    }
                  }
                  
                  resolve(JSON.stringify({
                    loggedIn: loggedIn,
                    userInfo: userInfo,
                    hasAuthCookie: hasAuthCookie,
                    currentURL: window.location.href
                  }));
                } catch (error) {
                  resolve(JSON.stringify({
                    loggedIn: false,
                    userInfo: null,
                    error: error.toString()
                  }));
                }
              }, 2000); // Wait 2 seconds for page to fully load
            });
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
  
  /// Apply stored cookies to YouTube Player WebView with enhanced compatibility
  Future<void> applyCookiesToPlayer(WebViewController playerController) async {
    try {
      if (!_isLoggedIn) {
        AppLogger.info('Not logged in, skipping cookie application');
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final cookieManager = WebViewCookieManager();
      
      // Clear existing cookies first for clean state
      await cookieManager.clearCookies();
      await Future.delayed(const Duration(milliseconds: 300));
      AppLogger.info('Cleared cookies before applying YouTube cookies');
      
      // Load and apply YouTube cookies with enhanced domains
      final youtubeCookieDataString = prefs.getString('youtube_cookies_data');
      if (youtubeCookieDataString != null) {
        try {
          final youtubeCookieList = const JsonDecoder().convert(youtubeCookieDataString) as List<dynamic>;
          
          // Apply cookies to multiple YouTube domains for better compatibility
          final domains = ['.youtube.com', '.m.youtube.com', '.www.youtube.com', '.googlevideo.com'];
          
          for (final cookieData in youtubeCookieList) {
            final cookieMap = cookieData as Map<String, dynamic>;
            final name = cookieMap['name'] as String;
            final value = cookieMap['value'] as String;
            
            // Skip empty or invalid cookies
            if (name.isEmpty || value.isEmpty) continue;
            
            // Apply to all relevant domains
            for (final domain in domains) {
              final cookie = WebViewCookie(
                name: name,
                value: value,
                domain: domain,
                path: '/',
              );
              try {
                await cookieManager.setCookie(cookie);
                // Small delay between cookie sets to avoid conflicts
                await Future.delayed(const Duration(milliseconds: 50));
              } catch (e) {
                AppLogger.warning('Failed to set cookie $name for $domain: $e');
              }
            }
          }
          
          AppLogger.info('Applied ${youtubeCookieList.length} YouTube cookies to player across ${domains.length} domains');
        } catch (e) {
          AppLogger.error('Failed to parse YouTube cookies: $e');
        }
      }
      
      // Add enhanced marker cookies to indicate login state
      final markerCookies = [
        const WebViewCookie(name: 'youtube_login_shared', value: 'true', domain: '.youtube.com', path: '/'),
        const WebViewCookie(name: 'youtube_login_shared', value: 'true', domain: '.m.youtube.com', path: '/'),
        const WebViewCookie(name: 'youtube_mobile_auth', value: 'true', domain: '.youtube.com', path: '/'),
        const WebViewCookie(name: 'PREF', value: 'hl=en&gl=US&f5=30', domain: '.youtube.com', path: '/'),
      ];
      
      for (final cookie in markerCookies) {
        try {
          await cookieManager.setCookie(cookie);
          await Future.delayed(const Duration(milliseconds: 50));
        } catch (e) {
          AppLogger.warning('Failed to set marker cookie ${cookie.name}: $e');
        }
      }
      
      AppLogger.info('YouTube login cookies and markers applied to player');
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

  /// Get mobile login URL for backup login attempt
  String getMobileLoginUrl() {
    return _mobileYoutubeLoginUrl;
  }

  /// Try backup mobile login if primary login fails
  Future<void> tryMobileLogin() async {
    if (_controller != null) {
      AppLogger.info('Attempting backup mobile login');
      await _controller!.loadRequest(Uri.parse(_mobileYoutubeLoginUrl));
    }
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
      
      // Clear cookies for clean state - this helps resolve playback issues
      try {
        await cookieManager.clearCookies();
        AppLogger.info('Cleared all cookies before re-applying YouTube cookies');
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        AppLogger.warning('Failed to clear cookies: $e, continuing with refresh');
      }
      
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
  
  /// Pre-initialize YouTube Player environment with login cookies
  Future<void> prepareYouTubePlayerEnvironment() async {
    try {
      AppLogger.info('Preparing YouTube Player environment...');
      
      final cookieManager = WebViewCookieManager();
      
      if (_isLoggedIn) {
        // Apply all cookies before any YouTube player initialization
        await refreshPlayerCookies();
        AppLogger.info('YouTube Player environment prepared with login cookies');
      } else {
        // Clear any existing cookies to ensure clean state when not logged in
        await cookieManager.clearCookies();
        AppLogger.info('YouTube Player environment prepared (no login, cookies cleared)');
      }
      
      // Add a small delay to ensure cookies are properly set
      await Future.delayed(const Duration(milliseconds: 500));
      
    } catch (e) {
      AppLogger.error('Failed to prepare YouTube Player environment: $e');
    }
  }
  
  /// Enhanced method to inject login state into YouTube Player
  Future<void> injectLoginStateToPlayer(WebViewController? playerController) async {
    if (playerController == null || !_isLoggedIn) return;
    
    try {
      // Inject JavaScript to modify YouTube Player behavior
      await playerController.runJavaScript('''
        (function() {
          // Set login indicators that YouTube might check
          if (window.yt) {
            window.yt.config_ = window.yt.config_ || {};
            window.yt.config_.LOGGED_IN = true;
            window.yt.config_.SESSION_INDEX = 1;
          }
          
          // Try to set auth headers if available
          if (window.XMLHttpRequest) {
            const originalOpen = XMLHttpRequest.prototype.open;
            XMLHttpRequest.prototype.open = function() {
              originalOpen.apply(this, arguments);
              // Add auth header if making requests to YouTube API
              if (arguments[1] && arguments[1].includes('youtube.com')) {
                this.setRequestHeader('X-YouTube-Client-Name', '1');
                this.setRequestHeader('X-YouTube-Client-Version', '2.0');
              }
            };
          }
          
          console.log('YouTube Player login state injected');
        })();
      ''');
      
      AppLogger.info('Successfully injected login state to YouTube Player');
    } catch (e) {
      AppLogger.error('Failed to inject login state to player: $e');
    }
  }
}