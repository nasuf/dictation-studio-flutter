import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:async';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb; // platform checks
import '../generated/app_localizations.dart';

import '../models/transcript_item.dart';
import '../models/video.dart';
import '../models/progress.dart';
import '../utils/video_playback_utils.dart';
import '../utils/logger.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/simple_comparison_widget.dart';
import '../widgets/compact_progress_bar.dart';
import '../widgets/video_player_with_controls.dart';
import '../utils/precise_text_comparison.dart';
import '../models/simple_comparison_result.dart';
import '../services/youtube_login_service.dart';
import '../widgets/youtube_login_webview.dart';

class DictationScreen extends StatefulWidget {
  final String channelId;
  final String videoId;
  final Video video;

  const DictationScreen({
    super.key,
    required this.channelId,
    required this.videoId,
    required this.video,
  });

  @override
  State<DictationScreen> createState() => _DictationScreenState();
}

class _DictationScreenState extends State<DictationScreen>
    with WidgetsBindingObserver {
  // Controllers and managers
  late YoutubePlayerController _youtubeController;
  late VideoPlaybackController _playbackController;
  late TextEditingController _textController;
  late FocusNode _textFocusNode;

  // State variables
  List<TranscriptItem> _transcript = [];
  final Map<int, String> _userInput = {};
  final Map<int, SimpleComparisonResult> _comparisonResults = {};

  int _currentSentenceIndex = 0;
  final Set<int> _revealedSentences = {};
  final Set<int> _playedSentences = {}; // 跟踪已经播放过的句子
  final Set<int> _completedSentences = {}; // 跟踪已经完成输入的句子

  bool _isLoadingTranscript = true;
  bool _isCompleted = false;
  bool _hasUnsavedChanges = false;
  bool _isTimerRunning = false;

  // Video player state management
  bool _isVideoReady = false;
  bool _isVideoPlaying = false;
  bool _isVideoLoading = false;

  // Playback task management to prevent concurrent playback
  int _currentPlaybackTaskId = 0;

  // Progress tracking
  double _overallCompletion = 0.0;
  double _overallAccuracy = 0.0;
  int _totalTime = 0; // in seconds

  // Configuration
  double _playbackSpeed = 1.0;
  int _autoRepeatCount = 0; // Default: no auto repeat (play once)
  bool _autoRepeat = false; // Default: auto repeat disabled

  // Services
  final ApiService _apiService = ApiService();
  final YouTubeLoginService _youtubeLoginService = YouTubeLoginService();

  // iOS media warm-up flag to bypass first-play user gesture restriction
  bool _iosWarmupDone = false;

  // Android warm-up flag to handle Android-specific playback issues
  bool _androidWarmupDone = false;

  bool get _isIOSDevice =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool get _isAndroidDevice =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  // Supported playback speeds
  static const List<double> _supportedPlaybackSpeeds = [
    0.5,
    0.6,
    0.7,
    0.75,
    0.8,
    0.9,
    1.0,
    1.1,
    1.2,
    1.25,
    1.3,
    1.4,
    1.5,
    1.6,
    1.7,
    1.8,
    1.9,
    2.0,
  ];

  // Timers
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeYouTubeLoginService();
    _initializeComponents();
    _loadTranscript();
    _startTimers();

    // 备用自动刷新机制 - 多层检查
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 第一次检查 - 3秒后
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          final playerState = _youtubeController.value.playerState;
          AppLogger.info(
            'Backup check #1: PlayerState=$playerState, Ready=$_isVideoReady',
          );

          if (!_isVideoReady || playerState == PlayerState.unknown) {
            AppLogger.info(
              'Player not properly initialized after 3 seconds, performing backup refresh',
            );
            _refreshYouTubePlayer();

            // 第二次检查 - 如果第一次刷新不成功
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                final secondCheckState = _youtubeController.value.playerState;
                AppLogger.info(
                  'Backup check #2: PlayerState=$secondCheckState, Ready=$_isVideoReady',
                );

                if (!_isVideoReady || secondCheckState == PlayerState.unknown) {
                  AppLogger.warning(
                    'Player still not ready after backup refresh, showing error message',
                  );
                  _showPlayerInitializationError();
                }
              }
            });
          } else {
            AppLogger.info(
              'Player properly initialized, skipping backup refresh',
            );
          }
        }
      });
    });
  }

  /// Initialize YouTube Login Service
  Future<void> _initializeYouTubeLoginService() async {
    try {
      await _youtubeLoginService.initialize();
      AppLogger.info(
        'YouTube login service initialized. Login status: ${_youtubeLoginService.isLoggedIn}',
      );

      if (_youtubeLoginService.userInfo != null) {
        AppLogger.info('YouTube user: ${_youtubeLoginService.userInfo}');
      }
    } catch (e) {
      AppLogger.error('Failed to initialize YouTube login service: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimers();

    // Save progress only if there are actual changes
    if (_hasUnsavedChanges) {
      AppLogger.info('Saving progress on page exit - user has unsaved changes');
      _saveProgress(); // Save silently during disposal
    } else {
      AppLogger.info('No unsaved changes on page exit - skipping save');
    }

    // Remove listeners before disposing
    _youtubeController.removeListener(_onYouTubePlayerStateChange);
    _textController.removeListener(_onTextChanged);
    _textFocusNode.removeListener(_onFocusChanged);

    // Dispose controllers
    _playbackController.dispose();
    _youtubeController.dispose();
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _initializeComponents() {
    // Load user configuration first
    _loadUserConfiguration();

    // Initialize YouTube controller with improved configuration
    final extractedVideoId = YoutubePlayer.convertUrlToId(widget.video.link);
    final videoId = extractedVideoId ?? widget.video.videoId;

    // Ensure videoId is a String (defensive programming)
    final safeVideoId = videoId.toString();

    AppLogger.info('Initializing video player with video ID: $safeVideoId');
    AppLogger.info('Video link: ${widget.video.link}');
    AppLogger.info(
      'Extracted ID: $extractedVideoId, Original ID: ${widget.video.videoId}',
    );

    // Try YouTube Player first, fallback to WebView if it fails
    _initializeYouTubePlayer(safeVideoId);

    // Initialize text controller and focus
    _textController = TextEditingController();
    _textFocusNode = FocusNode();

    _textController.addListener(_onTextChanged);
    _textFocusNode.addListener(_onFocusChanged);
  }

  /// Load user configuration from authentication provider
  void _loadUserConfiguration() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user != null) {
      final config = user.dictationConfig;

      setState(() {
        // Load playback speed (clamp to supported range)
        _playbackSpeed = config.playbackSpeed.clamp(0.5, 2.0);

        // Ensure the loaded speed is in our supported list
        if (!_supportedPlaybackSpeeds.contains(_playbackSpeed)) {
          // Find the closest supported speed
          double minDiff = double.infinity;
          double closestSpeed = 1.0;
          for (double speed in _supportedPlaybackSpeeds) {
            double diff = (_playbackSpeed - speed).abs();
            if (diff < minDiff) {
              minDiff = diff;
              closestSpeed = speed;
            }
          }
          _playbackSpeed = closestSpeed;
          AppLogger.info(
            'Adjusted unsupported playback speed to closest supported value: $_playbackSpeed',
          );
        }

        // Load auto repeat settings
        // auto_repeat: 0 means no repeat (play once), >0 means repeat N times (total plays = N+1)
        _autoRepeat = config.autoRepeat > 0;
        _autoRepeatCount =
            config.autoRepeat; // Store the actual repeat count from backend

        AppLogger.info('Raw config.autoRepeat value: ${config.autoRepeat}');
        AppLogger.info(
          'Processed _autoRepeat: $_autoRepeat, _autoRepeatCount: $_autoRepeatCount',
        );
      });

      AppLogger.info(
        'Loaded user configuration: speed=$_playbackSpeed, autoRepeat=$_autoRepeat, repeatCount=$_autoRepeatCount',
      );
    } else {
      AppLogger.info('No user configuration found, using defaults');
    }
  }

  /// Save configuration changes to backend API
  Future<void> _saveConfigurationToServer() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) {
      AppLogger.warning('Cannot save configuration: user not logged in');
      return;
    }

    try {
      // Prepare configuration data for API
      final configData = {
        'dictation_config': {
          'playback_speed': _playbackSpeed,
          'auto_repeat': _autoRepeat ? _autoRepeatCount : 0,
          // Preserve existing shortcuts (mobile app doesn't change them)
          'shortcuts': user.dictationConfig.shortcuts.toJson(),
          // Preserve language preference
          'language': user.dictationConfig.language,
        },
      };

      AppLogger.info('Saving user configuration to server: $configData');

      // Call API service to save configuration
      await _apiService.saveUserConfig(configData);

      AppLogger.info('User configuration saved successfully');

      // Update local user data in auth provider
      // Note: This might require a method in AuthProvider to update dictation config
      // For now, the config will be refreshed on next app launch
    } catch (e) {
      AppLogger.error('Failed to save user configuration: $e');

      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.failedToSaveSettings}: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _initializeYouTubePlayer(String videoId) {
    try {
      AppLogger.info(
        'Attempting to initialize YouTube Player with ID: $videoId',
      );

      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          disableDragSeek: false,
          loop: false,
          isLive: false,
          forceHD: false,
          enableCaption: false,
          hideControls: true,
          useHybridComposition: true,
          // Additional flags that might help with bot detection bypass
          controlsVisibleAtStart: false,
        ),
      );

      // Add listener for player state changes
      _youtubeController.addListener(_onYouTubePlayerStateChange);

      // Initialize playback controller
      _playbackController = VideoPlaybackController(
        _youtubeController,
        onStateChange: _onPlaybackStateChange,
        onProgress: _onPlaybackProgress,
        onPlaybackFailure: _onPlaybackFailure,
        config: PlaybackConfig(
          playbackSpeed: _playbackSpeed,
          timeAccuracy: 0.1,
          bufferTolerance: 0.3,
          maxRetries: 2,
          retryDelay: const Duration(milliseconds: 200),
          enableLogging: true,
        ),
      );

      AppLogger.info('YouTube Player initialized successfully');
      AppLogger.info('Waiting for onReady callback before loading video...');
    } catch (e) {
      AppLogger.error('YouTube Player initialization failed: $e');
    }
  }

  // YouTube login related methods removed

  void _showPlayerInitializationError() {
    if (!mounted) return;

    final errorMessage = _isIOSDevice
        ? 'Video player initialization failed. If you see a YouTube login prompt, try refreshing the player.'
        : 'Video player initialization failed. Try using the refresh button.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(errorMessage)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Refresh',
          textColor: Colors.white,
          onPressed: () {
            _refreshYouTubePlayer();
          },
        ),
      ),
    );
  }

  /// Check if YouTube login is required and show login dialog
  Future<void> _checkAndPromptYouTubeLogin() async {
    if (_youtubeLoginService.shouldShowLoginPrompt()) {
      AppLogger.info('YouTube login required - showing login dialog');

      if (!mounted) return;

      // Show login dialog
      await showYouTubeLoginDialog(
        context,
        onLoginSuccess: () {
          AppLogger.info('YouTube login completed successfully');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'YouTube login successful! Refreshing video player...',
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );

            // Update UI to reflect login state
            setState(() {}); // This will update the login button appearance

            // Refresh the YouTube player to apply login state
            Future.delayed(const Duration(milliseconds: 500), () async {
              if (mounted) {
                AppLogger.info(
                  'Refreshing YouTube player after successful login',
                );
                
                // Apply login cookies to the player
                await _youtubeLoginService.refreshPlayerCookies();
                
                // Then refresh the player
                _refreshYouTubePlayer();
              }
            });
          }
        },
        onCancel: () {
          // When user cancels/closes login, stay on dictation screen and refresh player
          AppLogger.info(
            'YouTube login cancelled - staying on dictation screen and refreshing player',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Login cancelled. Refreshing player...'),
                  ],
                ),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 2),
              ),
            );

            // Refresh the YouTube player even if login was cancelled
            Future.delayed(const Duration(milliseconds: 500), () async {
              if (mounted) {
                AppLogger.info(
                  'Refreshing YouTube player after login cancellation',
                );
                
                // Try to refresh cookies if user is logged in
                if (_youtubeLoginService.isLoggedIn) {
                  await _youtubeLoginService.refreshPlayerCookies();
                }
                
                _refreshYouTubePlayer();
              }
            });
          }
        },
        onLoginError: (error) {
          AppLogger.error('YouTube login failed: $error');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('YouTube login failed: $error')),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _checkAndPromptYouTubeLogin(),
              ),
            ),
          );
        },
      );
    } else {
      AppLogger.info('YouTube login not required - user is already logged in');
    }
  }

  /// Show YouTube login suggestion as a non-intrusive prompt
  void _showYouTubeLoginSuggestion() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Video player might need YouTube login. Tap the login button in the top-right corner.',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Login Now',
          textColor: Colors.white,
          onPressed: () => _checkAndPromptYouTubeLogin(),
        ),
      ),
    );
  }

  void _onYouTubePlayerStateChange() {
    final playerState = _youtubeController.value.playerState;
    final isReady = _youtubeController.value.isReady;
    final isPlaying = _youtubeController.value.isPlaying;

    AppLogger.info(
      'YouTube player state changed: $playerState, ready: $isReady, playing: $isPlaying',
    );

    // Only iOS has warm-up now, Android uses simple initialization
    final isInWarmup = (_isIOSDevice && !_iosWarmupDone);

    setState(() {
      // Update video ready state - if isReady is true, consider it ready regardless of playerState
      _isVideoReady = isReady;

      // During iOS warm-up, ignore playing state changes, otherwise normal handling
      if (isInWarmup) {
        // Force all states to stopped during iOS warm-up only
        _isVideoPlaying = false;
        _isVideoLoading = false;
        AppLogger.info('iOS WARM-UP: Forcing all states to stopped (actual: playing=$isPlaying, state=$playerState)');
      } else {
        // Normal state handling for Android and post-warm-up iOS
        _isVideoPlaying = isPlaying;
        AppLogger.info('Normal state update: playing = $isPlaying');
        
        // Clear loading state when actually playing
        if (isPlaying && _isVideoLoading) {
          _isVideoLoading = false;
          AppLogger.info('Video loading state cleared - now playing');
        }
      }
    });

    // Handle player ready state
    if (_isVideoReady) {
      AppLogger.info(
        'YouTube player is ready and functional - buttons should be enabled now',
      );
    } else {
      AppLogger.info('YouTube player not ready - buttons are disabled');
    }

    // Safety check: if we detect unexpected auto-play (not user-initiated), force pause
    if (!isInWarmup && isPlaying && !_playbackController.isPlayingSegment) {
      AppLogger.warning(
        'Detected unexpected auto-play, forcing pause',
      );
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _youtubeController.pause();
          setState(() {
            _isVideoPlaying = false;
            _isVideoLoading = false;
          });
        }
      });
    }
  }

  void _startTimers() {
    // Progress tracking timer
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isTimerRunning) {
        setState(() {
          _totalTime++;
        });
      }
    });

    // Remove auto-save timer - will only save on page exit if there are changes
  }

  void _stopTimers() {
    _progressTimer?.cancel();
  }

  Future<void> _loadTranscript() async {
    try {
      AppLogger.info(
        'Loading transcript for video: ${widget.videoId} in channel: ${widget.channelId}',
      );

      // Fetch transcript and user progress concurrently
      AppLogger.info('Calling APIs for transcript and progress...');
      final futures = await Future.wait([
        _apiService.getVideoTranscript(widget.channelId, widget.videoId),
        _apiService
            .getUserProgress(widget.channelId, widget.videoId)
            .catchError((e) {
              AppLogger.warning(
                'User progress not found, continuing without it: $e',
              );
              return <
                String,
                dynamic
              >{}; // Return empty map if no progress found
            }),
      ]);

      final transcriptResponse = futures[0];
      final progressResponse = futures[1];

      // Parse transcript data - check multiple possible response structures
      AppLogger.info('Transcript response: ${transcriptResponse.toString()}');

      Map<String, dynamic>? transcriptData;
      List<dynamic>? transcriptList;

      // Try different response structures
      if (transcriptResponse.containsKey('data') &&
          transcriptResponse['data'] != null) {
        // Structure: { "data": { "transcript": [...] } }
        transcriptData = transcriptResponse['data'] as Map<String, dynamic>?;
        if (transcriptData != null &&
            transcriptData.containsKey('transcript')) {
          transcriptList = transcriptData['transcript'] as List<dynamic>?;
        }
      } else if (transcriptResponse.containsKey('transcript')) {
        // Structure: { "transcript": [...] }
        transcriptList = transcriptResponse['transcript'] as List<dynamic>?;
      } else {
        // Structure: direct array [...] - but transcriptResponse is Map, so this won't work
        // Just log the structure for debugging
        AppLogger.warning(
          'Unexpected response structure: ${transcriptResponse.runtimeType}',
        );
      }

      if (transcriptList == null || transcriptList.isEmpty) {
        throw Exception('No transcript data available for this video');
      }
      final loadedTranscript = transcriptList.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value as Map<String, dynamic>;
        return TranscriptItem.fromJson({...item, 'index': index});
      }).toList();

      setState(() {
        _transcript = loadedTranscript;
        _isLoadingTranscript = false;
      });

      // Restore user progress if exists - API returns data directly without 'data' wrapper
      AppLogger.info('=== PROGRESS RESTORATION DEBUG ===');
      AppLogger.info('Progress response type: ${progressResponse.runtimeType}');
      AppLogger.info(
        'Progress response keys: ${progressResponse.keys.toList()}',
      );
      AppLogger.info('Progress response: ${progressResponse.toString()}');

      // Check for valid progress data - API returns data directly
      bool hasValidProgress = false;
      try {
        // Backend API returns progress data directly: {channelId, videoId, userInput, currentTime, overallCompletion}
        if (progressResponse.containsKey('userInput') &&
            progressResponse['userInput'] != null) {
          final userInput = progressResponse['userInput'];
          AppLogger.info('UserInput type: ${userInput.runtimeType}');
          AppLogger.info('UserInput content: $userInput');

          if (userInput is Map && userInput.isNotEmpty) {
            hasValidProgress = true;
            AppLogger.info(
              '✓ Valid progress found with ${userInput.length} inputs',
            );
            AppLogger.info('UserInput keys: ${userInput.keys.toList()}');
          } else {
            AppLogger.info('✗ UserInput is empty or not a Map');
          }
        } else {
          AppLogger.info('✗ No userInput key or userInput is null');
        }
      } catch (e) {
        AppLogger.warning('Error checking progress data: $e');
      }

      AppLogger.info('Final hasValidProgress: $hasValidProgress');

      if (hasValidProgress) {
        AppLogger.info('Found existing progress, restoring...');
        await _restoreUserProgress(progressResponse);
      } else {
        AppLogger.info('No existing progress found, starting fresh');
        setState(() {
          _currentSentenceIndex = 0;
        });
      }

      AppLogger.info('Loaded ${_transcript.length} transcript segments');
    } catch (e) {
      AppLogger.error('Error loading transcript: $e');
      setState(() {
        _isLoadingTranscript = false;
      });
      _showTranscriptErrorDialog(
        'Failed to load video transcript: ${e.toString()}',
      );
    }
  }

  Future<void> _restoreUserProgress(Map<String, dynamic> progressData) async {
    try {
      AppLogger.info('Restoring user progress...');

      // Restore user input - exactly like React version
      final userInputData = progressData['userInput'] as Map<String, dynamic>?;
      if (userInputData != null && userInputData.isNotEmpty) {
        _userInput.clear();

        // Create new transcript with user input - mirroring React lines 374-378
        final List<TranscriptItem> newTranscript = [];
        for (int i = 0; i < _transcript.length; i++) {
          final userInput = userInputData.containsKey(i.toString())
              ? userInputData[i.toString()]
              : '';
          newTranscript.add(_transcript[i].copyWith(userInput: userInput));

          // Only store entries that actually exist in the progress data
          if (userInputData.containsKey(i.toString())) {
            _userInput[i] = userInputData[i.toString()];
          }
        }
        _transcript = newTranscript;

        // Find last input index - exactly like React line 380-383
        final lastInputIndex = _userInput.keys.isEmpty
            ? 0
            : _userInput.keys.reduce((a, b) => a > b ? a : b);

        // Set current sentence index to last input - like React line 383
        _currentSentenceIndex = lastInputIndex.clamp(0, _transcript.length - 1);

        // Don't auto-reveal sentences - user controls original text display
        _revealedSentences.clear();

        // Mark all input sentences as played and completed
        _playedSentences.clear();
        _playedSentences.addAll(_userInput.keys);
        _completedSentences.clear();
        _completedSentences.addAll(_userInput.keys);

        // Auto-score all restored sentences - like React lines 388-403
        await Future.delayed(const Duration(milliseconds: 100));

        // Trigger comparison for all restored inputs
        for (int index in _userInput.keys) {
          if (index < _transcript.length) {
            _performComparison(index);
          }
        }

        // Update overall progress
        _updateOverallProgress();

        // Set text controller to current sentence's input
        _textController.text = _userInput[_currentSentenceIndex] ?? '';

        // Seek video to current position if possible - mimic React line 387-389
        if (_isVideoReady && _currentSentenceIndex < _transcript.length) {
          final targetSegment = _transcript[_currentSentenceIndex];
          try {
            _youtubeController.seekTo(
              Duration(seconds: targetSegment.start.toInt()),
            );
            AppLogger.info(
              'Video seeked to ${targetSegment.start} seconds for restored progress',
            );
          } catch (e) {
            AppLogger.warning(
              'Failed to seek video during progress restoration: $e',
            );
          }
        }

        AppLogger.info(
          'Progress restored: ${_userInput.length} inputs, positioned at sentence ${_currentSentenceIndex + 1}/${_transcript.length}',
        );
      }

      // Restore timing and completion data
      final completion = progressData['overallCompletion'];
      if (completion != null) {
        _overallCompletion = (completion is double)
            ? completion
            : (completion as num).toDouble();
      }

      // Reset timer for new session - like React lines 437-439
      _totalTime = 0;

      setState(() {
        _hasUnsavedChanges = false; // Just loaded, so no unsaved changes
      });

      AppLogger.info(
        'User progress fully restored: ${_userInput.length} sentences, ${_overallCompletion.toStringAsFixed(1)}% complete',
      );
    } catch (e) {
      AppLogger.error('Error restoring user progress: $e');
    }
  }

  void _onPlaybackStateChange(VideoPlaybackState state) {
    AppLogger.info('Playback state changed: $state');

    setState(() {
      _isTimerRunning = state == VideoPlaybackState.playing;

      // Clear loading state when playback starts
      if (state == VideoPlaybackState.playing) {
        _isVideoLoading = false;
      }

      // Don't modify _isVideoReady here - let YouTube player state listener handle it
      // Don't override _isVideoPlaying here - let YouTube player state listener handle it
      // Only update if we're transitioning to a definitive non-playing state
      if (state == VideoPlaybackState.paused ||
          state == VideoPlaybackState.ended) {
        _isVideoPlaying = false;
        _isVideoLoading = false; // Clear loading state when stopped
      }
    });
  }

  void _onPlaybackProgress(double currentTime) {
    // Update progress if needed
  }

  void _onPlaybackFailure(String reason) {
    AppLogger.warning('Playback failure detected: $reason');
    // Login-related failure handling removed - just log the error
  }

  void _refreshYouTubePlayer() {
    try {
      AppLogger.info('🔄 Refreshing YouTube Player...');
      AppLogger.info('📺 Video title: ${widget.video.title}');
      AppLogger.info('🔗 Video link: ${widget.video.link}');

      // 使用与初始化时相同的逻辑来获取正确的videoId
      final extractedVideoId = YoutubePlayer.convertUrlToId(widget.video.link);
      final videoId = extractedVideoId ?? widget.video.videoId;
      final safeVideoId = videoId.toString();

      AppLogger.info('🎯 Refreshing with video ID: $safeVideoId');
      AppLogger.info(
        '📊 Current player state before refresh - Ready: $_isVideoReady, Loading: $_isVideoLoading, Playing: $_isVideoPlaying',
      );

      // 重新加载当前视频
      _youtubeController.load(safeVideoId);

      // Platform-specific warm-up for first-time playback issues
      if ((_isIOSDevice && !_iosWarmupDone) ||
          (_isAndroidDevice && !_androidWarmupDone)) {
        _warmupPlayerIfNeeded();
      } else {
        // For iOS: If already warmed but user manually refreshed, perform another warm-up
        // to bypass potential YouTube login prompts
        if (_isIOSDevice && _iosWarmupDone) {
          AppLogger.info(
            'iOS: Performing additional warm-up due to manual refresh',
          );
          _performIOSWarmup();
        } else {
          // Other platforms: apply cookies and ensure paused
          Future.delayed(const Duration(milliseconds: 100), () async {
            if (mounted) {
              // Apply login cookies if user is logged in
              if (_youtubeLoginService.isLoggedIn) {
                await _youtubeLoginService.refreshPlayerCookies();
              }
              
              AppLogger.info(
                'Pausing video after manual refresh to prevent auto-play',
              );
              _youtubeController.pause();
            }
          });
        }
      }

      // 更新状态 - 确保播放状态重置为暂停
      setState(() {
        _isVideoReady = true;
        _isVideoLoading = false;
        _isVideoPlaying = false; // 确保刷新后不显示为播放状态
      });

      AppLogger.info('✅ YouTube Player refresh completed successfully');
      AppLogger.info(
        '📊 New player state after refresh - Ready: $_isVideoReady, Loading: $_isVideoLoading, Playing: $_isVideoPlaying',
      );
    } catch (e) {
      AppLogger.error('❌ Failed to refresh YouTube Player: $e');
    }
  }

  // iOS-only: mute -> short play -> pause -> unmute, done once
  void _warmupPlayerIfNeeded() {
    if (_isIOSDevice && !_iosWarmupDone) {
      _performIOSWarmup();
    } else if (_isAndroidDevice && !_androidWarmupDone) {
      // DISABLE Android warm-up completely - use simple initialization instead
      AppLogger.info('Android: Skipping warm-up, using simple initialization like other platforms');
      _androidWarmupDone = true; // Mark as done immediately
      
      // Use the same simple approach as other platforms
      Future.delayed(const Duration(milliseconds: 100), () async {
        if (mounted) {
          // Apply login cookies if user is logged in
          if (_youtubeLoginService.isLoggedIn) {
            await _youtubeLoginService.refreshPlayerCookies();
          }
          
          AppLogger.info(
            'Android: Pausing video after load to prevent auto-play (simple method)',
          );
          _youtubeController.pause();
          
          // Ensure UI state is correct
          setState(() {
            _isVideoPlaying = false;
            _isVideoLoading = false;
          });
        }
      });
    }
  }

  void _performIOSWarmup() {
    AppLogger.info(
      'iOS warm-up start: enhanced user gesture simulation to bypass YouTube login',
    );
    // Enhanced warm-up to bypass YouTube's anti-bot protection
    Future.microtask(() async {
      try {
        AppLogger.info(
          'iOS warm-up: step 1 - mute player for silent initialization',
        );
        _youtubeController.mute();

        // Small delay to ensure mute takes effect
        await Future.delayed(const Duration(milliseconds: 100));

        AppLogger.info(
          'iOS warm-up: step 2 - start playback (simulating user gesture)',
        );
        _youtubeController.play();

        // Longer playback window to ensure YouTube recognizes this as legitimate user interaction
        await Future.delayed(const Duration(milliseconds: 600));

        AppLogger.info(
          'iOS warm-up: step 3 - pause to complete gesture simulation',
        );
        _youtubeController.pause();

        // Allow time for pause to register
        await Future.delayed(const Duration(milliseconds: 150));

        AppLogger.info('iOS warm-up: step 4 - unmute for normal operation');
        _youtubeController.unMute();

        // Final delay to ensure all states are properly set
        await Future.delayed(const Duration(milliseconds: 100));

        _iosWarmupDone = true;
        AppLogger.info(
          'iOS warm-up completed - YouTube anti-bot bypass should be active',
        );

        // Ensure UI state is correctly set to paused after warm-up
        if (mounted) {
          setState(() {
            _isVideoPlaying = false;
            _isVideoLoading = false;
          });
          AppLogger.info('iOS warm-up: UI state reset to paused');
        }
      } catch (e) {
        AppLogger.error('iOS warm-up failed: $e');
        _iosWarmupDone = true; // Mark as done to prevent infinite retries
      }
    });
  }

  // Android warm-up method removed - now using simple initialization like other platforms

  void _onTextChanged() {
    final text = _textController.text;
    final oldInput = _userInput[_currentSentenceIndex] ?? '';

    if (text != oldInput) {
      setState(() {
        _userInput[_currentSentenceIndex] = text;
        _hasUnsavedChanges = true;
      });

      // Perform comparison if we have transcript
      if (_currentSentenceIndex < _transcript.length) {
        _performComparison(_currentSentenceIndex);

        // 不再实时更新整体进度，只在句子完成时更新
      }

      // Remove auto-save logic - will only save on page exit
    }
  }

  void _onFocusChanged() {
    setState(() {}); // Rebuild to update UI focus state
  }

  void _markCurrentSentenceCompleted() {
    final input = _userInput[_currentSentenceIndex];
    if (input != null && input.trim().isNotEmpty) {
      // 标记当前句子为完成
      _completedSentences.add(_currentSentenceIndex);

      // 重新计算整体进度
      _updateOverallProgress();

      AppLogger.info(
        'Sentence $_currentSentenceIndex marked as completed: "$input"',
      );
    }
  }

  void _performComparison(int index) {
    if (index >= _transcript.length) return;

    final userText = _userInput[index] ?? '';
    final transcriptText = _transcript[index].transcript;

    final result = PreciseTextComparison.compareInputWithTranscript(
      userText,
      transcriptText,
    );

    setState(() {
      _comparisonResults[index] = result;
    });

    // 不再自动更新整体进度，由调用方决定何时更新
  }

  void _updateOverallProgress() {
    // 计算所有原文单词总数
    int totalOriginalWords = 0;
    for (final transcript in _transcript) {
      final words = transcript.transcript.trim().split(RegExp(r'\s+'));
      totalOriginalWords += words.where((w) => w.isNotEmpty).length;
    }

    // 计算已播放句子的原文单词总数
    int playedOriginalWords = 0;
    for (int playedIndex in _playedSentences) {
      if (playedIndex < _transcript.length) {
        final words = _transcript[playedIndex].transcript.trim().split(
          RegExp(r'\s+'),
        );
        playedOriginalWords += words.where((w) => w.isNotEmpty).length;
      }
    }

    // 计算已完成句子的用户输入正确单词数和对应的原文单词数
    int totalCorrectWords = 0;
    int totalCompletedOriginalWords = 0; // 已完成句子的原文单词数

    for (int completedIndex in _completedSentences) {
      if (completedIndex < _transcript.length) {
        final result = _comparisonResults[completedIndex];
        if (result != null) {
          // 计算用户输入中正确的单词数
          final correctWordsInSentence = result.userInputResult
              .where((word) => word.isCorrect)
              .length;
          totalCorrectWords += correctWordsInSentence;

          // 计算该句子原文的单词数
          final words = _transcript[completedIndex].transcript.trim().split(
            RegExp(r'\s+'),
          );
          totalCompletedOriginalWords += words
              .where((w) => w.isNotEmpty)
              .length;
        }
      }
    }

    setState(() {
      // 完成率 = 已播放句子的原文单词数 / 所有原文单词数
      _overallCompletion = totalOriginalWords > 0
          ? (playedOriginalWords / totalOriginalWords * 100).clamp(0.0, 100.0)
          : 0.0;

      // 准确率 = 已完成句子的正确单词数 / 已完成句子的原文单词数
      _overallAccuracy = totalCompletedOriginalWords > 0
          ? (totalCorrectWords / totalCompletedOriginalWords * 100).clamp(
              0.0,
              100.0,
            )
          : 0.0;
    });

    AppLogger.info(
      'Progress updated - Completion: ${_overallCompletion.toStringAsFixed(1)}%, Accuracy: ${_overallAccuracy.toStringAsFixed(1)}%',
    );
    AppLogger.info(
      'Played sentences: $_playedSentences, Completed sentences: $_completedSentences',
    );
    AppLogger.info(
      'Total correct words: $totalCorrectWords, Completed original words: $totalCompletedOriginalWords, Played original words: $playedOriginalWords',
    );

    // Check for completion
    if (_overallCompletion >= 100.0 && !_isCompleted) {
      _onDictationCompleted();
    }
  }

  void _onDictationCompleted() {
    setState(() {
      _isCompleted = true;
    });

    _saveProgress();
    _showCompletionDialog();
  }

  Future<void> _saveProgress() async {
    await _saveProgressWithUI(showNotifications: false);
  }

  Future<void> _saveProgressWithUI({required bool showNotifications}) async {
    if (!_hasUnsavedChanges) return;

    try {
      // Show progress saving indicator only if notifications are enabled and widget is mounted
      if (showNotifications && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text(AppLocalizations.of(context)!.savingProgress),
              ],
            ),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.blue,
          ),
        );
      }

      // Create a proper ProgressData object (convert Map<int,String> to Map<String,String>)
      final userInputForApi = Map<String, String>.fromEntries(
        _userInput.entries.map((e) => MapEntry(e.key.toString(), e.value)),
      );

      final progressData = ProgressData(
        channelId: widget.channelId,
        videoId: widget.videoId,
        userInput: userInputForApi,
        currentTime: DateTime.now().millisecondsSinceEpoch.toDouble(),
        overallCompletion: _overallCompletion,
        duration: _totalTime.toDouble(),
      );

      await _apiService.saveUserProgress(progressData);

      // Only call setState if widget is still mounted
      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
        });
      } else {
        // Update flag directly if widget is disposed
        _hasUnsavedChanges = false;
      }

      // Show success message only if notifications are enabled and widget is mounted
      if (showNotifications && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(AppLocalizations.of(context)!.progressSavedSuccessfully),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }

      AppLogger.info('Progress saved successfully');
    } catch (e) {
      AppLogger.error('Failed to save progress: $e');

      // Show error message only if notifications are enabled and widget is mounted
      if (showNotifications && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${AppLocalizations.of(context)!.failedToSaveProgress}: ${e.toString()}',
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Playback control methods with debouncing
  DateTime? _lastPlaybackAction;
  // Increased debounce delay to prevent chaos from rapid clicking
  static const Duration _playbackDebounceDelay = Duration(milliseconds: 600);
  bool _isPlaybackInProgress = false;

  Future<void> _playCurrentSentence() async {
    // Debouncing: prevent rapid successive calls
    final now = DateTime.now();
    if (_lastPlaybackAction != null &&
        now.difference(_lastPlaybackAction!) < _playbackDebounceDelay) {
      AppLogger.info(
        'Playback call debounced - too soon after last action (${now.difference(_lastPlaybackAction!).inMilliseconds}ms ago)',
      );
      return;
    }
    _lastPlaybackAction = now;

    // Prevent concurrent playback operations
    if (_isPlaybackInProgress) {
      AppLogger.info('Playback already in progress, ignoring new request');
      return;
    }

    if (_currentSentenceIndex >= _transcript.length) return;

    // Check if video is ready before attempting to play
    if (!_isVideoReady) {
      AppLogger.warning('Video not ready, cannot play current sentence');
      _showPlaybackErrorSnackBar();
      return;
    }

    _isPlaybackInProgress = true;

    // Generate unique task ID - this will invalidate any previous tasks
    final taskId = ++_currentPlaybackTaskId;
    AppLogger.info(
      'Starting playback task $taskId for sentence ${_currentSentenceIndex + 1}',
    );

    // Android-specific: Check for PlayerState.unStarted and attempt recovery
    if (_isAndroidDevice) {
      final currentState = _youtubeController.value.playerState;
      AppLogger.info(
        'ℹ️ DictationStudio: Player state check before playback: $currentState',
      );

      if (currentState == PlayerState.unStarted) {
        AppLogger.warning(
          '⚠️ Android PlayerState is unStarted, attempting state recovery',
        );

        try {
          // Attempt to force state transition for Android devices
          AppLogger.info(
            'Android recovery: attempting muted play to force state transition',
          );
          _youtubeController.mute();
          _youtubeController.play();

          // Wait and check for state transition
          int attempts = 0;
          const maxAttempts = 10;
          PlayerState waitState = PlayerState.unStarted;

          while (attempts < maxAttempts && waitState == PlayerState.unStarted) {
            await Future.delayed(const Duration(milliseconds: 100));
            waitState = _youtubeController.value.playerState;
            final isPlaying = _youtubeController.value.isPlaying;
            attempts++;
            AppLogger.info(
              'ℹ️ DictationStudio: Android waiting for playback... attempt $attempts, state: $waitState, playing: $isPlaying',
            );
          }

          _youtubeController.pause();
          _youtubeController.unMute();

          final recoveredState = _youtubeController.value.playerState;
          AppLogger.info(
            'Android recovery result: PlayerState = $recoveredState after $attempts attempts',
          );

          if (recoveredState == PlayerState.unStarted) {
            AppLogger.error(
              '⚠️ Android PlayerState recovery failed, playback may not work properly',
            );
          } else {
            AppLogger.info(
              '✅ Android PlayerState recovery successful: $recoveredState',
            );
          }
        } catch (e) {
          AppLogger.error('Android PlayerState recovery failed: $e');
        }
      }
    }

    // Always stop any current playback before starting new one (like React version)
    await _playbackController.stop();
    AppLogger.info('Stopped previous playback for task $taskId');

    try {
      final segment = _transcript[_currentSentenceIndex];
      AppLogger.info(
        'Playing sentence ${_currentSentenceIndex + 1}: "${segment.transcript}" (task $taskId)',
      );

      // Set loading state when starting playback
      if (mounted) {
        setState(() {
          _isVideoLoading = true;
          // 记录这个句子已经被播放过
          _playedSentences.add(_currentSentenceIndex);
        });
      }
      AppLogger.info('Video loading state set to true for task $taskId');

      // Check if this task is still current before starting playback
      if (taskId != _currentPlaybackTaskId) {
        AppLogger.info('Playback task $taskId was cancelled before starting');
        if (mounted) {
          setState(() {
            _isVideoLoading = false;
          });
        }
        return;
      }

      // Play the segment (initial play)
      AppLogger.info('Starting initial playback at ${_playbackSpeed}x speed');
      await _playbackController.playSegment(segment);

      // Check if task is still current after main playback
      if (taskId != _currentPlaybackTaskId) {
        AppLogger.info(
          'Playback task $taskId was cancelled after main playback',
        );
        if (mounted) {
          setState(() {
            _isVideoLoading = false;
          });
        }
        return;
      }

      // Auto-repeat if enabled
      // _autoRepeatCount represents how many additional times to repeat (not total plays)
      // auto_repeat: 1 means play once + repeat 1 time = total 2 plays
      if (_autoRepeat && _autoRepeatCount > 0) {
        AppLogger.info(
          'Auto-repeat enabled: will repeat $_autoRepeatCount additional times',
        );

        for (int i = 0; i < _autoRepeatCount; i++) {
          // Check if we're still the current task
          if (taskId != _currentPlaybackTaskId) {
            AppLogger.info(
              'Playback task $taskId cancelled during auto-repeat',
            );
            setState(() {
              _isVideoLoading = false;
            });
            return;
          }

          await Future.delayed(const Duration(milliseconds: 500));
          AppLogger.info('Auto-repeat ${i + 1}/$_autoRepeatCount');
          await _playbackController.playSegment(segment);
        }
      }

      // Final check and only update UI if we're still the current task
      if (taskId == _currentPlaybackTaskId) {
        if (mounted) {
          setState(() {
            _isVideoLoading = false;
          });
        }
        AppLogger.info('Playback task $taskId completed successfully');
      } else {
        AppLogger.info('Playback task $taskId completed but was superseded');
      }
    } catch (e) {
      AppLogger.error('Error in playback task $taskId: $e');
      // Only reset loading state if this is still the current task
      if (taskId == _currentPlaybackTaskId) {
        if (mounted) {
          setState(() {
            _isVideoLoading = false;
          });
        }
        _showPlaybackErrorSnackBar();
      }
    } finally {
      _isPlaybackInProgress = false;
    }
  }

  /// Play button toggles between play and pause
  /// If currently playing: pause playback
  /// If not playing: play the current sentence
  Future<void> _handlePlayButtonClick() async {
    // Check if currently playing the current sentence
    if (_playbackController.isPlayingSegment) {
      // Currently playing, so pause/stop
      AppLogger.info(
        'Pausing current playback for sentence ${_currentSentenceIndex + 1}',
      );
      await _playbackController.stop();

      if (mounted) {
        setState(() {
          _isVideoLoading = false;
          _isVideoPlaying = false;
        });
      }
    } else {
      // Not playing, so start playing the current sentence
      AppLogger.info(
        'Starting playback for sentence ${_currentSentenceIndex + 1}',
      );
      await _playCurrentSentence();
    }
  }

  void _showPlaybackErrorSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(AppLocalizations.of(context)!.videoNotReady)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: AppLocalizations.of(context)!.retry,
          textColor: Colors.white,
          onPressed: _playCurrentSentence,
        ),
      ),
    );
  }

  Future<void> _playNextSentence() async {
    // Debouncing: prevent rapid successive calls for navigation
    final now = DateTime.now();
    if (_lastPlaybackAction != null &&
        now.difference(_lastPlaybackAction!) < _playbackDebounceDelay) {
      AppLogger.info(
        'Next sentence call debounced - too soon after last action (${now.difference(_lastPlaybackAction!).inMilliseconds}ms ago)',
      );
      return;
    }
    // Don't set _lastPlaybackAction here - let _playCurrentSentence() handle it

    _saveCurrentInput();

    // 标记当前句子为完成状态（如果有输入）
    _markCurrentSentenceCompleted();

    // Remove auto-save - will only save on page exit

    if (_currentSentenceIndex < _transcript.length - 1) {
      // Force stop any current playback immediately and reset playback state
      await _playbackController.stop();
      _isPlaybackInProgress =
          false; // Reset flag to ensure new playback can start
      AppLogger.info('Stopped playback for next sentence navigation');

      if (mounted) {
        setState(() {
          _currentSentenceIndex++;
          // 不再自动显示原文，用户需要手动控制
          _textController.text = _userInput[_currentSentenceIndex] ?? '';
          // Set loading state immediately for button feedback
          _isVideoLoading = true;
        });
      }

      await _playCurrentSentence();
    }
  }

  Future<void> _playPreviousSentence() async {
    // Debouncing: prevent rapid successive calls for navigation
    final now = DateTime.now();
    if (_lastPlaybackAction != null &&
        now.difference(_lastPlaybackAction!) < _playbackDebounceDelay) {
      AppLogger.info(
        'Previous sentence call debounced - too soon after last action (${now.difference(_lastPlaybackAction!).inMilliseconds}ms ago)',
      );
      return;
    }
    // Don't set _lastPlaybackAction here - let _playCurrentSentence() handle it

    if (_currentSentenceIndex > 0) {
      // Force stop any current playback immediately and reset playback state
      await _playbackController.stop();
      _isPlaybackInProgress =
          false; // Reset flag to ensure new playback can start
      AppLogger.info('Stopped playback for previous sentence navigation');

      if (mounted) {
        setState(() {
          _currentSentenceIndex--;
          _textController.text = _userInput[_currentSentenceIndex] ?? '';
          // Set loading state immediately for button feedback
          _isVideoLoading = true;
        });
      }

      await _playCurrentSentence();
    }
  }

  void _saveCurrentInput() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _userInput[_currentSentenceIndex] = text;
        _hasUnsavedChanges = true;
      });

      // Update transcript with user input - like React line 662-669
      _transcript[_currentSentenceIndex] = _transcript[_currentSentenceIndex]
          .copyWith(userInput: text);

      // Don't auto-reveal sentences based on user input - let user control original text display
      // Original text visibility should be consistent across all sentences

      _performComparison(_currentSentenceIndex);

      // Remove auto-save logic - will only save on page exit
    }
  }

  void _toggleCurrentSentenceReveal() {
    setState(() {
      if (_revealedSentences.contains(_currentSentenceIndex)) {
        _revealedSentences.remove(_currentSentenceIndex);
      } else {
        _revealedSentences.add(_currentSentenceIndex);
      }
    });
  }

  void _showTranscriptErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.transcriptNotAvailable),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.transcriptNotAvailableMessage,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.back),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isLoadingTranscript = true;
              });
              _loadTranscript();
            },
            child: Text(AppLocalizations.of(context)!.retry),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Congratulations!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context)!.youHaveCompleted),
            const SizedBox(height: 16),
            Text(
              '${AppLocalizations.of(context)!.accuracy}: ${_overallAccuracy.toStringAsFixed(1)}%',
            ),
            Text(
              '${AppLocalizations.of(context)!.time}: ${(_totalTime / 60).toStringAsFixed(1)} ${AppLocalizations.of(context)!.minutes}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.continueButton),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Return to video list
            },
            child: Text(AppLocalizations.of(context)!.finish),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoadingTranscript) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0B) : null,
        appBar: AppBar(
          title: Text(widget.video.title),
          backgroundColor: isDark ? const Color(0xFF1A1A1D) : null,
          foregroundColor: isDark ? const Color(0xFFE8E8EA) : null,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpinKitPulse(
                color: isDark
                    ? const Color(0xFF007AFF)
                    : theme.colorScheme.primary,
                size: 50,
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.loadingDictation,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isDark
                      ? const Color(0xFF9E9EA3)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: true, // Always allow swipe back and button navigation
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          // Pop already happened, start background save if needed
          if (_hasUnsavedChanges) {
            _saveProgress().catchError((e) {
              AppLogger.error('Background save failed after navigation: $e');
            });
          }
          return;
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0B) : null,
        appBar: AppBar(
          title: Text(widget.video.title),
          backgroundColor: isDark ? const Color(0xFF1A1A1D) : null,
          foregroundColor: isDark ? const Color(0xFFE8E8EA) : null,
          actions: [
            // YouTube login button for all platforms
            IconButton(
              icon: Icon(
                _youtubeLoginService.isLoggedIn
                    ? Icons.account_circle
                    : Icons.login,
                color: _youtubeLoginService.isLoggedIn ? Colors.green : null,
              ),
              onPressed: () async {
                if (_youtubeLoginService.isLoggedIn) {
                  // Show logout confirmation
                  final shouldLogout = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('YouTube Logout'),
                      content: Text('Do you want to logout from YouTube?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );

                  if (shouldLogout == true) {
                    await _youtubeLoginService.logout();
                    if (mounted) {
                      setState(() {}); // Refresh UI
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('YouTube logout successful'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                } else {
                  // Show login dialog
                  await _checkAndPromptYouTubeLogin();
                }
              },
              tooltip: _youtubeLoginService.isLoggedIn
                  ? 'YouTube Account (${_youtubeLoginService.userInfo ?? "Logged In"})'
                  : 'Login to YouTube',
            ),
            IconButton(
              icon: const Icon(Icons.restart_alt_outlined),
              onPressed: _showResetConfirmationDialog,
              tooltip: AppLocalizations.of(context)!.resetProgress,
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showSettingsDialog,
            ),
          ],
        ),
        body: Column(
          children: [
            // Video player with integrated controls
            YoutubePlayerBuilder(
              player: YoutubePlayer(
                controller: _youtubeController,
                showVideoProgressIndicator: false,
                onReady: () {
                  AppLogger.info(
                    'YouTube player ready callback - now loading video',
                  );

                  // 现在才调用load()，确保播放器完全准备好
                  final extractedVideoId = YoutubePlayer.convertUrlToId(
                    widget.video.link,
                  );
                  final videoId = extractedVideoId ?? widget.video.videoId;
                  final safeVideoId = videoId.toString();

                  AppLogger.info(
                    'Loading video in onReady callback: $safeVideoId',
                  );
                  _youtubeController.load(safeVideoId);

                  // Platform-specific warm-up for first-time playback issues;
                  // other platforms keep the old immediate pause to prevent auto-play
                  if ((_isIOSDevice && !_iosWarmupDone) ||
                      (_isAndroidDevice && !_androidWarmupDone)) {
                    AppLogger.info(
                      'Initiating platform-specific warm-up sequence',
                    );
                    _warmupPlayerIfNeeded();
                  } else {
                    Future.delayed(const Duration(milliseconds: 100), () async {
                      if (mounted) {
                        // Apply login cookies if user is logged in
                        if (_youtubeLoginService.isLoggedIn) {
                          await _youtubeLoginService.refreshPlayerCookies();
                        }
                        
                        AppLogger.info(
                          'Pausing video after load to prevent auto-play',
                        );
                        _youtubeController.pause();
                      }
                    });
                  }

                  // 延迟设置状态，等待load()完成
                  Future.delayed(const Duration(milliseconds: 800), () {
                    if (mounted) {
                      AppLogger.info(
                        'Setting video ready state after onReady load() completion',
                      );
                      setState(() {
                        _isVideoReady = true;
                        _isVideoLoading = false;
                        _isVideoPlaying = false; // 确保初始化后不显示为播放状态
                      });

                      // Check if YouTube login might be needed (iOS specific)
                      if (_isIOSDevice && !_youtubeLoginService.isLoggedIn) {
                        Future.delayed(const Duration(seconds: 2), () {
                          if (mounted) {
                            final playerState =
                                _youtubeController.value.playerState;
                            if (playerState == PlayerState.unknown ||
                                !_isVideoReady) {
                              AppLogger.info(
                                'iOS: Player might need YouTube login - checking automatically',
                              );
                              _showYouTubeLoginSuggestion();
                            }
                          }
                        });
                      }
                    }
                  });
                },
                onEnded: (metaData) {
                  AppLogger.info('YouTube video ended');
                },
              ),
              builder: (context, player) {
                return VideoPlayerWithControls(
                  youtubeController: _youtubeController,
                  playbackController: _playbackController,
                  onPlayCurrent: _isVideoReady
                      ? () {
                          AppLogger.info(
                            'Play current button clicked - video ready: $_isVideoReady',
                          );
                          _handlePlayButtonClick();
                        }
                      : null,
                  onPlayNext:
                      _isVideoReady &&
                          !_isVideoLoading &&
                          _currentSentenceIndex < _transcript.length - 1
                      ? _playNextSentence
                      : null,
                  onPlayPrevious:
                      _isVideoReady &&
                          !_isVideoLoading &&
                          _currentSentenceIndex > 0
                      ? _playPreviousSentence
                      : null,
                  canGoNext: _currentSentenceIndex < _transcript.length - 1,
                  canGoPrevious: _currentSentenceIndex > 0,
                  isPlaying: _isVideoPlaying,
                  isLoading: _isVideoLoading,
                  fallbackWidget: player,
                );
              },
            ),

            // Compact progress bar
            CompactProgressBar(
              completion: _overallCompletion,
              accuracy: _overallAccuracy,
              timeSpent: _totalTime,
            ),

            // Main content - optimized for mobile keyboard
            Expanded(child: _buildMainContent()),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    // Create local copies of settings for the dialog
    double tempPlaybackSpeed = _playbackSpeed;
    bool tempAutoRepeat = _autoRepeat;
    int tempAutoRepeatCount = _autoRepeatCount;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.playbackSettings),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(AppLocalizations.of(context)!.playbackSpeed),
                trailing: DropdownButton<double>(
                  value: tempPlaybackSpeed,
                  items: _supportedPlaybackSpeeds.map((speed) {
                    return DropdownMenuItem(
                      value: speed,
                      child: Text('${speed}x'),
                    );
                  }).toList(),
                  onChanged: isSaving
                      ? null
                      : (value) {
                          if (value != null) {
                            setDialogState(() {
                              tempPlaybackSpeed = value;
                            });
                          }
                        },
                ),
              ),
              ListTile(
                title: Text(AppLocalizations.of(context)!.autoRepeat),
                trailing: Switch(
                  value: tempAutoRepeat,
                  onChanged: isSaving
                      ? null
                      : (value) {
                          setDialogState(() {
                            tempAutoRepeat = value;
                            // If disabling auto repeat, reset count to 0 (no repeats)
                            if (!value) {
                              tempAutoRepeatCount = 0;
                            } else {
                              // If enabling auto repeat, set to 1 repeat (2 total plays)
                              if (tempAutoRepeatCount == 0) {
                                tempAutoRepeatCount = 1;
                              }
                            }
                          });
                        },
                ),
              ),
              if (tempAutoRepeat)
                ListTile(
                  title: Text(AppLocalizations.of(context)!.repeatCount),
                  trailing: DropdownButton<int>(
                    value: tempAutoRepeatCount,
                    items: [1, 2, 3, 4, 5].map((count) {
                      return DropdownMenuItem(
                        value: count,
                        child: Text('$count'),
                      );
                    }).toList(),
                    onChanged: isSaving
                        ? null
                        : (value) {
                            if (value != null) {
                              setDialogState(() {
                                tempAutoRepeatCount = value;
                              });
                            }
                          },
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() {
                        isSaving = true;
                      });

                      try {
                        // Apply changes to main state
                        setState(() {
                          _playbackSpeed = tempPlaybackSpeed;
                          _autoRepeat = tempAutoRepeat;
                          _autoRepeatCount = tempAutoRepeatCount;
                        });

                        // Update playback controller speed
                        _playbackController.setPlaybackSpeed(tempPlaybackSpeed);

                        AppLogger.info(
                          'Settings updated: speed=$_playbackSpeed, autoRepeat=$_autoRepeat, repeatCount=$_autoRepeatCount',
                        );

                        // Save configuration to server
                        await _saveConfigurationToServer();

                        // Refresh user data to reflect the new configuration
                        if (context.mounted) {
                          final authProvider = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );
                          await authProvider.refreshUserData();
                          AppLogger.info(
                            'User data refreshed after config save',
                          );
                        }

                        // Show success message
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.settingsSavedSuccessfully,
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        // Error is already handled in _saveConfigurationToServer
                        // Just reset the saving state
                        setDialogState(() {
                          isSaving = false;
                        });
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(AppLocalizations.of(context)!.save),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_outlined, color: Colors.orange),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.resetProgress),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.resetProgressConfirm,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.thisWill,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(AppLocalizations.of(context)!.clearAllInputs),
              Text(AppLocalizations.of(context)!.resetToBeginning),
              Text(AppLocalizations.of(context)!.loseAllProgress),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.cannotBeUndone,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _resetProgress();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(context)!.resetProgress),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetProgress() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text(AppLocalizations.of(context)!.resetting),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Reset all local state
      setState(() {
        _currentSentenceIndex = 0;
        _userInput.clear();
        _completedSentences.clear();
        _revealedSentences.clear();
        _comparisonResults.clear();

        // Reset progress calculations
        _overallCompletion = 0.0;
        _overallAccuracy = 0.0;

        // Reset input field
        _textController.clear();

        // Mark as changed so it will save the reset state
        _hasUnsavedChanges = true;
      });

      // Save the reset progress to server immediately
      await _saveProgress();

      // Clear the unsaved changes flag after successful save
      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
        });
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(AppLocalizations.of(context)!.resetCompleted),
              ],
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }

      AppLogger.info(
        'Progress reset successfully for video: ${widget.video.videoId}',
      );
    } catch (e) {
      AppLogger.error('Failed to reset progress: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${AppLocalizations.of(context)!.resetFailed}: ${e.toString()}',
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Build main content with mobile keyboard optimization
  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Current sentence display and comparison
          _buildEnhancedSentenceDisplay(),

          const SizedBox(height: 16),

          // Text input area - positioned to avoid keyboard overlap
          _buildOptimizedTextInput(),

          // Add extra space for keyboard
          SizedBox(
            height: MediaQuery.of(context).viewInsets.bottom > 0 ? 100 : 32,
          ),
        ],
      ),
    );
  }

  /// Enhanced sentence display with better comparison
  Widget _buildEnhancedSentenceDisplay() {
    if (_transcript.isEmpty || _currentSentenceIndex >= _transcript.length) {
      return const SizedBox.shrink();
    }

    final currentTranscript = _transcript[_currentSentenceIndex].transcript;
    final isRevealed = _revealedSentences.contains(_currentSentenceIndex);
    final comparison = _comparisonResults[_currentSentenceIndex];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: isDark ? 8 : 2,
      color: isDark
          ? const Color(0xFF1C1C1E)
          : theme.colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isDark
            ? BorderSide(
                color: const Color(0xFF3A3A3F).withValues(alpha: 0.3),
                width: 0.5,
              )
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with sentence info and toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.sentenceOf(
                      _currentSentenceIndex + 1,
                      _transcript.length,
                    ),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF9E9EA3)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                // Simple toggle button with original green color
                IconButton(
                  icon: Icon(
                    isRevealed ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: _toggleCurrentSentenceReveal,
                  color: const Color(0xFF4CAF50), // Original deep green color
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Comparison content with better styling
            if (comparison != null && !comparison.isEmpty) ...[
              SimpleComparisonWidget(
                comparison: comparison,
                showOriginal: isRevealed,
                showUserInput: isRevealed,
              ),
            ] else if (isRevealed) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2A2A2F), Color(0xFF25252A)],
                        )
                      : null,
                  color: isDark
                      ? null
                      : theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.4,
                        ),
                  borderRadius: BorderRadius.circular(12),
                  border: isDark
                      ? Border.all(
                          color: const Color(0xFF3A3A3F).withValues(alpha: 0.4),
                          width: 0.5,
                        )
                      : Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.15,
                          ),
                          width: 1,
                        ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.text_snippet_outlined,
                          size: 16,
                          color: isDark
                              ? const Color(0xFF007AFF)
                              : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.original,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFF007AFF)
                                : theme.colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      currentTranscript,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: isDark
                            ? const Color(0xFFE8E8EA)
                            : theme.colorScheme.onSurface,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Optimized text input for mobile
  Widget _buildOptimizedTextInput() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _textController,
        focusNode: _textFocusNode,
        maxLines: 3,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.typeWhatYouHear,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          contentPadding: const EdgeInsets.all(16),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_textController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _textController.clear();
                    _onTextChanged();
                  },
                ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () async {
                  _saveCurrentInput();
                  _markCurrentSentenceCompleted();
                  // Move to next sentence if available (same as onSubmitted)
                  if (_currentSentenceIndex < _transcript.length - 1) {
                    await _playNextSentence();
                  }
                },
              ),
            ],
          ),
        ),
        onSubmitted: (text) async {
          _saveCurrentInput();
          // Mark current sentence as completed if there's input
          _markCurrentSentenceCompleted();
          // Remove auto-save logic - will only save on page exit

          if (_currentSentenceIndex < _transcript.length - 1) {
            _playNextSentence();
          }
        },
        onTap: () {
          // Ensure the text field is properly focused
        },
      ),
    );
  }
}
