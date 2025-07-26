import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/logger.dart';

class YouTubeLoginWebView extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final VoidCallback? onCancel;

  const YouTubeLoginWebView({
    super.key,
    this.onLoginSuccess,
    this.onCancel,
  });

  @override
  State<YouTubeLoginWebView> createState() => _YouTubeLoginWebViewState();
}

class _YouTubeLoginWebViewState extends State<YouTubeLoginWebView> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            AppLogger.info('Login WebView loading progress: $progress%');
            if (progress >= 100 && mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onPageStarted: (String url) {
            AppLogger.info('Login WebView page started: $url');
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (String url) {
            AppLogger.info('Login WebView page finished: $url');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              
              // Check if user is logged in
              _checkLoginStatus(url);
            }
          },
          onWebResourceError: (WebResourceError error) {
            AppLogger.error('Login WebView error: ${error.description}');
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            AppLogger.info('Navigation request: ${request.url}');
            
            // Check if login was successful (only if not already logged in)
            if (!_isLoggedIn && (
                request.url.contains('myaccount.google.com') || 
                request.url.contains('accounts.google.com/signin/oauth') ||
                (request.url.contains('youtube.com') && !request.url.contains('accounts')))) {
              _handleLoginSuccess();
            }
            
            return NavigationDecision.navigate;
          },
        ),
      );

    // Load YouTube login page
    _loadYouTubeLoginPage();
  }

  void _loadYouTubeLoginPage() {
    // Start with YouTube homepage which will prompt for login
    const loginUrl = 'https://accounts.google.com/signin/v2/identifier?service=youtube&hl=en&flowName=GlifWebSignIn&flowEntry=ServiceLogin';
    AppLogger.info('Loading YouTube login page: $loginUrl');
    _controller.loadRequest(Uri.parse(loginUrl));
  }

  void _checkLoginStatus(String url) {
    // Inject JavaScript to check if user is logged in
    const jsCode = '''
      (function() {
        // Check for login indicators
        var avatar = document.querySelector('img[alt*="Avatar"]') || 
                    document.querySelector('[aria-label*="Account menu"]') ||
                    document.querySelector('.ytd-topbar-menu-button-renderer');
        
        var signInButton = document.querySelector('a[aria-label*="Sign in"]') ||
                          document.querySelector('[href*="accounts.google.com"]');
        
        if (avatar && !signInButton) {
          return 'logged_in';
        } else if (signInButton) {
          return 'not_logged_in';
        }
        return 'unknown';
      })();
    ''';

    _controller.runJavaScriptReturningResult(jsCode).then((result) {
      final status = result.toString().replaceAll('"', '');
      AppLogger.info('Login status check result: $status');
      
      if (status == 'logged_in' && !_isLoggedIn) {
        _handleLoginSuccess();
      }
    }).catchError((error) {
      AppLogger.warning('Failed to check login status: $error');
    });
  }

  void _handleLoginSuccess() {
    if (_isLoggedIn || !mounted) return; // Prevent multiple calls and check mounted
    
    setState(() {
      _isLoggedIn = true;
    });
    
    AppLogger.info('YouTube login successful!');
    
    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Login successful! Returning to video...'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }

    // 缩短延迟时间并立即调用回调
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _isLoggedIn) {
        widget.onLoginSuccess?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube Login'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            widget.onCancel?.call();
          },
        ),
        actions: [
          if (_isLoggedIn)
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () => widget.onLoginSuccess?.call(),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (!_hasError)
            WebViewWidget(controller: _controller),
          
          if (_hasError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load login page',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Please check your internet connection'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                      });
                      _loadYouTubeLoginPage();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading YouTube login...'),
                  ],
                ),
              ),
            ),
            
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please log in to your YouTube/Google account to watch videos in the app.',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => widget.onCancel?.call(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoggedIn 
                        ? () => widget.onLoginSuccess?.call()
                        : null,
                    child: Text(_isLoggedIn ? 'Continue' : 'Login Required'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}