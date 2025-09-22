import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/youtube_login_service.dart';
import '../utils/logger.dart';

/// 统一的 YouTube 登录界面，使用 InAppWebView 以共享 Cookie。
class YouTubeLoginWebView extends StatefulWidget {
  const YouTubeLoginWebView({super.key});

  @override
  State<YouTubeLoginWebView> createState() => _YouTubeLoginWebViewState();
}

class _YouTubeLoginWebViewState extends State<YouTubeLoginWebView> {
  final YouTubeLoginService _loginService = YouTubeLoginService();
  InAppWebViewController? _controller;
  bool _isLoading = true;
  bool _loginCompleted = false;
  String _currentUrl = YouTubeLoginService.loginUrl;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0B) : Colors.white,
      appBar: AppBar(
        title: const Text('YouTube 登录'),
        backgroundColor: isDark ? const Color(0xFF1A1A1D) : null,
        foregroundColor: isDark ? const Color(0xFFE8E8EA) : null,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller?.reload(),
          ),
          TextButton(
            onPressed: _completeLoginManually,
            child: const Text('完成', style: TextStyle(color: Colors.white)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _isLoading
              ? const LinearProgressIndicator(minHeight: 2)
              : const SizedBox(height: 2),
        ),
      ),
      body: Column(
        children: [
          if (_currentUrl.isNotEmpty)
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? const Color(0xFF1C1C1E) : Colors.blue[50],
              child: Text(
                _currentUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: isDark ? Colors.blue[200] : Colors.blue[700],
                ),
              ),
            ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(YouTubeLoginService.loginUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                mediaPlaybackRequiresUserGesture: true,
                allowsInlineMediaPlayback: true,
                useHybridComposition: true,
                allowsBackForwardNavigationGestures: true,
                preferredContentMode: UserPreferredContentMode.MOBILE,
                userAgent:
                    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1',
              ),
              onWebViewCreated: (controller) => _controller = controller,
              onLoadStart: (_, uri) {
                if (!mounted) return;
                setState(() {
                  _isLoading = true;
                  _currentUrl = uri?.toString() ?? _currentUrl;
                });
              },
              onLoadStop: (_, uri) async {
                if (!mounted) return;
                setState(() {
                  _isLoading = false;
                  _currentUrl = uri?.toString() ?? _currentUrl;
                });
                await _handlePotentialSuccess(uri);
              },
              onUpdateVisitedHistory: (_, uri, __) async {
                await _handlePotentialSuccess(uri);
              },
              shouldOverrideUrlLoading: (controller, action) async {
                final uri = action.request.url;
                if (uri == null) {
                  return NavigationActionPolicy.ALLOW;
                }

                final host = uri.host;
                if (host.contains('google') || host.contains('youtube')) {
                  return NavigationActionPolicy.ALLOW;
                }
                return NavigationActionPolicy.CANCEL;
              },
              onReceivedServerTrustAuthRequest: (controller, challenge) async {
                // 允许 Google/YouTube 的 TLS
                return ServerTrustAuthResponse(
                  action: ServerTrustAuthResponseAction.PROCEED,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePotentialSuccess(Uri? uri) async {
    if (_loginCompleted || uri == null) {
      return;
    }

    final host = uri.host;
    if (host.contains('youtube.com') && !host.contains('accounts')) {
      AppLogger.info('Detected YouTube page after login: $uri');
      await _completeLogin();
    }
  }

  Future<void> _completeLogin() async {
    if (_loginCompleted) return;
    _loginCompleted = true;

    try {
      await _loginService.markAsLoggedIn(userInfo: 'YouTube 用户');
      await _loginService.prepareYouTubePlayerEnvironment();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      AppLogger.error('Failed to finalize YouTube login: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('登录状态同步失败：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      _loginCompleted = false;
    }
  }

  Future<void> _completeLoginManually() async {
    if (_loginCompleted) return;
    await _completeLogin();
  }
}
