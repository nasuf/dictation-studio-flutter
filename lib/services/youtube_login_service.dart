import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// YouTube登录状态管理服务
class YouTubeLoginService {
  static const String _loginStatusKey = 'youtube_login_status';
  static YouTubeLoginService? _instance;
  
  bool _isLoggedIn = false;
  
  YouTubeLoginService._();
  
  static YouTubeLoginService get instance {
    _instance ??= YouTubeLoginService._();
    return _instance!;
  }
  
  /// 获取当前登录状态
  bool get isLoggedIn => _isLoggedIn;
  
  /// 从本地存储加载登录状态
  Future<void> loadLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool(_loginStatusKey) ?? false;
      AppLogger.info('YouTube login status loaded: $_isLoggedIn');
    } catch (e) {
      AppLogger.error('Failed to load YouTube login status: $e');
      _isLoggedIn = false;
    }
  }
  
  /// 设置登录状态
  Future<void> setLoginStatus(bool isLoggedIn) async {
    try {
      _isLoggedIn = isLoggedIn;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_loginStatusKey, isLoggedIn);
      AppLogger.info('YouTube login status saved: $_isLoggedIn');
    } catch (e) {
      AppLogger.error('Failed to save YouTube login status: $e');
    }
  }
  
  /// 清除登录状态（用于测试）
  Future<void> clearLoginStatus() async {
    try {
      _isLoggedIn = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_loginStatusKey);
      AppLogger.info('YouTube login status cleared');
    } catch (e) {
      AppLogger.error('Failed to clear YouTube login status: $e');
    }
  }
}