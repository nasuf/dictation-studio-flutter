import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/logger.dart';

class YouTubeWebViewPlayer extends StatefulWidget {
  final String videoId;
  final double? startTime;
  final double? endTime;
  final VoidCallback? onReady;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final VoidCallback? onEnd;

  const YouTubeWebViewPlayer({
    super.key,
    required this.videoId,
    this.startTime,
    this.endTime,
    this.onReady,
    this.onPlay,
    this.onPause,
    this.onEnd,
  });

  @override
  State<YouTubeWebViewPlayer> createState() => _YouTubeWebViewPlayerState();
}

class _YouTubeWebViewPlayerState extends State<YouTubeWebViewPlayer> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            AppLogger.info('WebView loading progress: $progress%');
          },
          onPageStarted: (String url) {
            AppLogger.info('WebView page started loading: $url');
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (String url) {
            AppLogger.info('WebView page finished loading: $url');
            setState(() {
              _isLoading = false;
            });
            
            // Inject JavaScript to control the player
            _injectPlayerControls();
            
            widget.onReady?.call();
          },
          onWebResourceError: (WebResourceError error) {
            AppLogger.error('WebView error: ${error.description}');
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(_buildYouTubeEmbedUrl()));
  }

  String _buildYouTubeEmbedUrl() {
    final startParam = widget.startTime != null ? '&start=${widget.startTime!.round()}' : '';
    final endParam = widget.endTime != null ? '&end=${widget.endTime!.round()}' : '';
    
    final url = 'https://www.youtube.com/embed/${widget.videoId}'
        '?enablejsapi=1'
        '&autoplay=0'
        '&controls=1'
        '&modestbranding=1'
        '&rel=0'
        '&showinfo=0'
        '&iv_load_policy=3'
        '&fs=1'
        '&cc_load_policy=0'
        '&playsinline=1'
        '$startParam$endParam';
        
    AppLogger.info('YouTube embed URL: $url');
    return url;
  }

  void _injectPlayerControls() {
    const jsCode = '''
      var player;
      var YT;
      var onYouTubeIframeAPIReady = function() {
        player = new YT.Player('player', {
          events: {
            'onReady': function(event) {
              window.flutter_inappwebview.callHandler('onPlayerReady');
            },
            'onStateChange': function(event) {
              if (event.data == YT.PlayerState.PLAYING) {
                window.flutter_inappwebview.callHandler('onPlayerPlay');
              } else if (event.data == YT.PlayerState.PAUSED) {
                window.flutter_inappwebview.callHandler('onPlayerPause');
              } else if (event.data == YT.PlayerState.ENDED) {
                window.flutter_inappwebview.callHandler('onPlayerEnd');
              }
            }
          }
        });
      };
      
      // Check login status
      function checkLoginStatus() {
        // Look for login indicators in the page
        var loginButton = document.querySelector('[aria-label*="Sign in"]') || 
                         document.querySelector('a[href*="accounts.google.com"]') ||
                         document.querySelector('.sign-in-link');
        
        if (loginButton) {
          window.flutter_inappwebview.callHandler('onLoginRequired');
          return false;
        }
        
        // Check for error messages that might indicate login issues
        var errorElement = document.querySelector('.ytp-error') || 
                          document.querySelector('[class*="error"]');
        
        if (errorElement && errorElement.textContent.includes('Sign in')) {
          window.flutter_inappwebview.callHandler('onLoginRequired');
          return false;
        }
        
        return true;
      }
      
      // Load YouTube IFrame API
      if (!window.YT) {
        var tag = document.createElement('script');
        tag.src = 'https://www.youtube.com/iframe_api';
        var firstScriptTag = document.getElementsByTagName('script')[0];
        firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
      }
      
      // Check login status after page loads
      setTimeout(checkLoginStatus, 3000);
      
      // Helper functions
      function playVideo() {
        if (player && player.playVideo) {
          player.playVideo();
        }
      }
      
      function pauseVideo() {
        if (player && player.pauseVideo) {
          player.pauseVideo();
        }
      }
      
      function seekTo(seconds) {
        if (player && player.seekTo) {
          player.seekTo(seconds, true);
        }
      }
      
      function getCurrentTime() {
        if (player && player.getCurrentTime) {
          return player.getCurrentTime();
        }
        return 0;
      }
      
      function openLoginPage() {
        window.open('https://accounts.google.com/signin', '_blank');
      }
    ''';

    _controller.runJavaScript(jsCode);
  }

  Future<void> play() async {
    try {
      await _controller.runJavaScript('playVideo();');
      AppLogger.info('WebView YouTube player: play command sent');
    } catch (e) {
      AppLogger.error('WebView play error: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _controller.runJavaScript('pauseVideo();');
      AppLogger.info('WebView YouTube player: pause command sent');
    } catch (e) {
      AppLogger.error('WebView pause error: $e');
    }
  }

  Future<void> seekTo(double seconds) async {
    try {
      await _controller.runJavaScript('seekTo($seconds);');
      AppLogger.info('WebView YouTube player: seek to ${seconds}s');
    } catch (e) {
      AppLogger.error('WebView seek error: $e');
    }
  }

  Future<double> getCurrentTime() async {
    try {
      final result = await _controller.runJavaScriptReturningResult('getCurrentTime();');
      final time = double.tryParse(result.toString()) ?? 0.0;
      AppLogger.info('WebView YouTube player current time: ${time}s');
      return time;
    } catch (e) {
      AppLogger.error('WebView getCurrentTime error: $e');
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      color: Colors.black,
      child: Stack(
        children: [
          if (!_hasError)
            WebViewWidget(controller: _controller),
          
          if (_hasError)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Failed to load video',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          
          if (_isLoading && !_hasError)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              ),
            ),
        ],
      ),
    );
  }
}

// WebView YouTube Player Controller for managing playback
class WebViewYouTubeController {
  final _YouTubeWebViewPlayerState _playerState;
  
  WebViewYouTubeController(this._playerState);
  
  Future<void> play() => _playerState.play();
  Future<void> pause() => _playerState.pause();
  Future<void> seekTo(double seconds) => _playerState.seekTo(seconds);
  Future<double> getCurrentTime() => _playerState.getCurrentTime();
}