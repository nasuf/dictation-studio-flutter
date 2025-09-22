import '../utils/logger.dart';
import 'youtube_login_service.dart';

/// 旧代码的兼容包装，统一使用 [YouTubeLoginService]。
class YouTubeSimpleAuthService {
  YouTubeSimpleAuthService._internal();
  static final YouTubeSimpleAuthService _instance =
      YouTubeSimpleAuthService._internal();
  factory YouTubeSimpleAuthService() => _instance;

  final YouTubeLoginService _loginService = YouTubeLoginService();

  bool get isAuthenticated => _loginService.isLoggedIn;
  String? get userInfo => _loginService.userInfo;

  Future<void> initialize() async {
    await _loginService.initialize();
  }

  Future<void> prepareYouTubePlayerEnvironment() async {
    await _loginService.prepareYouTubePlayerEnvironment();
  }

  Future<void> logout() async {
    await _loginService.logout();
  }

  /// 登录弹窗确认后调用。
  Future<void> confirmLogin({String? userInfo}) async {
    await _loginService.markAsLoggedIn(userInfo: userInfo);
    await _loginService.prepareYouTubePlayerEnvironment();
  }

  /// 兼容旧代码的日志。
  void debugAuthState(String tag) {
    AppLogger.info('[$tag] YouTube auth: logged=${_loginService.isLoggedIn} user=${_loginService.userInfo}');
  }
}
