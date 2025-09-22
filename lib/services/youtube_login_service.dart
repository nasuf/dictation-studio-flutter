import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';

/// 管理 YouTube 登录状态与 Cookie，同步给播放器使用。
class YouTubeLoginService {
  YouTubeLoginService._internal();
  static final YouTubeLoginService _instance = YouTubeLoginService._internal();
  factory YouTubeLoginService() => _instance;

  static const String loginUrl =
      'https://accounts.google.com/signin/v2/identifier?service=youtube&hl=en&passive=true&flowName=GlifWebSignIn&flowEntry=ServiceLogin&continue=https%3A%2F%2Fm.youtube.com%2Fsignin%3Faction_handle_signin%3Dtrue%26hl%3Den';
  static const String _loginStateKey = 'youtube_login_state';
  static const String _cookiesKey = 'youtube_cookie_store';
  static const String _userInfoKey = 'youtube_user_info';

  final CookieManager _cookieManager = CookieManager.instance();

  bool _isLoggedIn = false;
  String? _userInfo;

  bool get isLoggedIn => _isLoggedIn;
  String? get userInfo => _userInfo;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool(_loginStateKey) ?? false;
    _userInfo = prefs.getString(_userInfoKey);
    AppLogger.info('YouTube login loaded. loggedIn=$_isLoggedIn user=$_userInfo');
  }

  Future<void> markAsLoggedIn({String? userInfo}) async {
    _isLoggedIn = true;
    _userInfo = userInfo ?? 'YouTube 用户';
    await _saveState();
    await _captureCookiesFromWebView();
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _userInfo = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loginStateKey);
    await prefs.remove(_userInfoKey);
    await prefs.remove(_cookiesKey);
    await _cookieManager.deleteAllCookies();
    AppLogger.info('YouTube login cleared');
  }

  Future<void> prepareYouTubePlayerEnvironment() async {
    if (!_isLoggedIn) {
      await _cookieManager.deleteAllCookies();
      AppLogger.info('Skipped cookie restore (not logged in)');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final cookiesJson = prefs.getString(_cookiesKey);
    if (cookiesJson == null) {
      AppLogger.warning('No stored cookies, clearing WebView cache');
      await _cookieManager.deleteAllCookies();
      return;
    }

    final List<dynamic> cookiesData = jsonDecode(cookiesJson);
    await _cookieManager.deleteAllCookies();

    for (final dynamic item in cookiesData) {
      final cookie = item as Map<String, dynamic>;
      final name = cookie['name'] as String?;
      final value = cookie['value'] as String?;
      if (name == null || value == null) {
        continue;
      }

      final storedDomain = (cookie['domain'] as String?) ?? '.youtube.com';
      final path = (cookie['path'] as String?) ?? '/';
      final secure = cookie['secure'] as bool? ?? true;
      final httpOnly = cookie['httpOnly'] as bool? ?? false;

      final domains = _expandDomains(storedDomain);
      for (final domain in domains) {
        await _setCookie(
          domain: domain,
          name: name,
          value: value,
          path: path,
          secure: secure,
          httpOnly: httpOnly,
        );
      }
    }

    AppLogger.info('Applied ${cookiesData.length} YouTube cookies to WebView');
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loginStateKey, _isLoggedIn);
    if (_userInfo != null) {
      await prefs.setString(_userInfoKey, _userInfo!);
    }
  }

  Future<void> _captureCookiesFromWebView() async {
    final targets = <WebUri>{
      WebUri('https://www.youtube.com'),
      WebUri('https://m.youtube.com'),
      WebUri('https://youtube.com'),
      WebUri('https://accounts.google.com'),
      WebUri('https://www.google.com'),
    };

    final Map<String, Map<String, dynamic>> store = {};

    for (final uri in targets) {
      final cookies = await _cookieManager.getCookies(url: uri);
      for (final cookie in cookies) {
        final domain = cookie.domain ?? uri.host;
        final key = '${domain.toLowerCase()}::${cookie.name}';
        store[key] = {
          'name': cookie.name,
          'value': cookie.value,
          'domain': domain,
          'path': cookie.path ?? '/',
          'secure': cookie.isSecure,
          'httpOnly': cookie.isHttpOnly,
        };
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cookiesKey, jsonEncode(store.values.toList()));
    AppLogger.info('Captured ${store.length} cookies from login WebView');
  }

  Set<String> _expandDomains(String domain) {
    final normalized = domain.startsWith('.') ? domain : '.$domain';
    if (normalized.contains('google')) {
      return {normalized};
    }
    return {
      normalized,
      '.youtube.com',
      '.m.youtube.com',
      '.youtube-nocookie.com',
      '.googlevideo.com',
    };
  }

  Future<void> _setCookie({
    required String domain,
    required String name,
    required String value,
    required String path,
    required bool secure,
    required bool httpOnly,
  }) async {
    final host = domain.startsWith('.') ? domain.substring(1) : domain;
    try {
      await _cookieManager.setCookie(
        url: WebUri('https://$host'),
        name: name,
        value: value,
        domain: domain,
        path: path,
        isSecure: secure,
        isHttpOnly: httpOnly,
        sameSite: HTTPCookieSameSitePolicy.LAX,
      );
    } catch (e) {
      AppLogger.warning('Failed to set cookie $name@$domain: $e');
    }
  }
}
