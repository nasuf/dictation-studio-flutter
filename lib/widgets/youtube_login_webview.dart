import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/youtube_login_service.dart';
import '../utils/logger.dart';

class YouTubeLoginWebView extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final Function(String)? onLoginError;
  final VoidCallback? onCancel;
  
  const YouTubeLoginWebView({
    super.key,
    this.onLoginSuccess,
    this.onLoginError,
    this.onCancel,
  });

  @override
  State<YouTubeLoginWebView> createState() => _YouTubeLoginWebViewState();
}

class _YouTubeLoginWebViewState extends State<YouTubeLoginWebView> {
  late WebViewController _controller;
  bool _isLoading = true;
  String _currentUrl = '';
  final YouTubeLoginService _loginService = YouTubeLoginService();

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = _loginService.createLoginWebViewController(
      onLoginSuccess: () {
        AppLogger.info('YouTube login successful in WebView');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          widget.onLoginSuccess?.call();
        }
      },
      onLoginError: (error) {
        AppLogger.error('YouTube login error in WebView: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          widget.onLoginError?.call(error);
        }
      },
    );
    
    // Add additional navigation tracking
    _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (String url) {
          if (mounted) {
            setState(() {
              _currentUrl = url;
              _isLoading = true;
            });
          }
          AppLogger.info('YouTube login page started: $url');
        },
        onPageFinished: (String url) {
          if (mounted) {
            setState(() {
              _currentUrl = url;
              _isLoading = false;
            });
          }
          AppLogger.info('YouTube login page finished: $url');
        },
        onProgress: (int progress) {
          AppLogger.info('YouTube login progress: $progress%');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0B) : Colors.white,
      appBar: AppBar(
        title: const Text('YouTube Login'),
        backgroundColor: isDark ? const Color(0xFF1A1A1D) : null,
        foregroundColor: isDark ? const Color(0xFFE8E8EA) : null,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            AppLogger.info('YouTube login cancelled by user');
            widget.onCancel?.call();
            Navigator.of(context).pop();
          },
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              AppLogger.info('YouTube login refresh requested');
              _controller.reload();
            },
            tooltip: 'Refresh',
          ),
          // 完成按钮
          TextButton(
            onPressed: () async {
              AppLogger.info('YouTube login completed by user via Done button');
              // Mark as logged in manually
              await _loginService.markAsLoggedIn(userInfo: 'YouTube User');
              // Don't call Navigator.pop() here - let the success callback handle navigation
              widget.onLoginSuccess?.call();
            },
            child: const Text(
              'Done',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: _isLoading
              ? const LinearProgressIndicator()
              : Container(height: 4.0),
        ),
      ),
      body: Column(
        children: [
          // URL bar for debugging (only in debug mode)
          if (kDebugMode && _currentUrl.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? const Color(0xFF2A2A2F) : Colors.grey[100],
              child: Text(
                _currentUrl,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontFamily: 'monospace',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          
          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: isDark ? const Color(0xFF1C1C1E) : Colors.blue[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: isDark ? Colors.blue[400] : Colors.blue[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'YouTube Login Instructions',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.blue[400] : Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Sign in with your Google/YouTube account\n'
                  '2. Complete any verification steps\n'
                  '3. You\'ll be redirected automatically when login succeeds\n'
                  '4. This allows the video player to access YouTube without restrictions',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          
          // WebView
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[50],
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF3A3A3F) : Colors.grey[300]!,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  AppLogger.info('YouTube login cancelled by user');
                  widget.onCancel?.call();
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  AppLogger.info('YouTube login completed via Done & Refresh button');
                  // Mark as logged in manually and refresh player
                  await _loginService.markAsLoggedIn(userInfo: 'YouTube User');
                  // Don't call Navigator.pop() here - let the success callback handle navigation
                  widget.onLoginSuccess?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Done & Refresh'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog helper function
Future<void> showYouTubeLoginDialog(
  BuildContext context, {
  VoidCallback? onLoginSuccess,
  Function(String)? onLoginError,
  VoidCallback? onCancel,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog.fullscreen(
        child: YouTubeLoginWebView(
          onLoginSuccess: () {
            Navigator.of(context).pop();
            onLoginSuccess?.call();
          },
          onLoginError: (error) {
            Navigator.of(context).pop();
            onLoginError?.call(error);
          },
          onCancel: () {
            Navigator.of(context).pop();
            onCancel?.call();
          },
        ),
      );
    },
  );
}