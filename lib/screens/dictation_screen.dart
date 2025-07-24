import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../models/transcript_item.dart';
import '../models/video.dart';
import '../models/progress.dart';
import '../utils/video_playback_utils.dart';
import '../utils/language_utils.dart';
import '../utils/logger.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/simple_comparison_widget.dart';
import '../widgets/compact_progress_bar.dart';
import '../widgets/video_player_with_controls.dart';
import '../utils/precise_text_comparison.dart';
import '../models/simple_comparison_result.dart';

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
  bool _isProgressExpanded = false;

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
    _initializeComponents();
    _loadTranscript();
    _startTimers();
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
    final videoId =
        YoutubePlayer.convertUrlToId(widget.video.link) ?? widget.video.videoId;
    AppLogger.info('Initializing YouTube player with video ID: $videoId');
    AppLogger.info('Video link: ${widget.video.link}');

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
        hideControls: true, // Hide default controls since we have custom ones
        useHybridComposition: true,
      ),
    );

    // Add listener for player state changes
    _youtubeController.addListener(_onYouTubePlayerStateChange);

    // Initialize playback controller with user configuration
    _playbackController = VideoPlaybackController(
      _youtubeController,
      onStateChange: _onPlaybackStateChange,
      onProgress: _onPlaybackProgress,
      config: PlaybackConfig(
        playbackSpeed: _playbackSpeed, // Use user's preferred speed
        timeAccuracy: 0.1,
        bufferTolerance: 0.3,
        maxRetries: 2, // Reduce retries to fail faster
        retryDelay: const Duration(milliseconds: 200),
        enableLogging: true,
      ),
    );

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

    if (user != null && user.dictationConfig != null) {
      final config = user.dictationConfig!;

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
        'Loaded user configuration: speed=${_playbackSpeed}, autoRepeat=${_autoRepeat}, repeatCount=${_autoRepeatCount}',
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
          'shortcuts': user.dictationConfig?.shortcuts.toJson() ?? {},
          // Preserve language preference
          'language': user.dictationConfig?.language,
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
            content: Text('Failed to save settings: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _onYouTubePlayerStateChange() {
    final playerState = _youtubeController.value.playerState;
    final isReady = _youtubeController.value.isReady;
    final isPlaying = _youtubeController.value.isPlaying;

    AppLogger.info(
      'YouTube player state changed: $playerState, ready: $isReady, playing: $isPlaying',
    );

    setState(() {
      // Update video ready state - if isReady is true, consider it ready regardless of playerState
      _isVideoReady = isReady;

      // More accurate playing state sync - use the isPlaying property directly
      _isVideoPlaying = isPlaying;

      // Clear loading state when actually playing
      if (isPlaying && _isVideoLoading) {
        _isVideoLoading = false;
        AppLogger.info('Video loading state cleared - now playing');
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
        _apiService.getUserProgress(widget.channelId, widget.videoId).catchError(
          (e) {
            AppLogger.warning(
              'User progress not found, continuing without it: $e',
            );
            return <String, dynamic>{}; // Return empty map if no progress found
          },
        ),
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

      // Auto-merge transcript segments for better playback
      final mergedTranscript = LanguageUtils.autoMergeTranscriptItems(
        loadedTranscript,
        10.0, // Max 10 seconds per segment
      );

      setState(() {
        _transcript = mergedTranscript;
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

  void _recalculateAllComparisons() {
    for (int i = 0; i < _transcript.length; i++) {
      if (_userInput.containsKey(i)) {
        _performComparison(i);
      }
    }
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
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Saving progress...'),
              ],
            ),
            duration: Duration(seconds: 1),
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
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Progress saved successfully'),
              ],
            ),
            duration: Duration(seconds: 2),
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
                Expanded(child: Text('Failed to save progress: ${e.toString()}')),
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
        content: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text('Video player not ready. Please wait and try again.'),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Retry',
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

  void _toggleProgressExpanded() {
    setState(() {
      _isProgressExpanded = !_isProgressExpanded;
    });

    // Hide keyboard when expanding progress
    if (_isProgressExpanded) {
      _textFocusNode.unfocus();
    }
  }

  void _showTranscriptErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transcript Not Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            const Text(
              'This video may not have transcript data available yet, or there might be a network issue.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isLoadingTranscript = true;
              });
              _loadTranscript();
            },
            child: const Text('Retry'),
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
            const Text('You have completed this dictation exercise!'),
            const SizedBox(height: 16),
            Text('Accuracy: ${_overallAccuracy.toStringAsFixed(1)}%'),
            Text('Time: ${(_totalTime / 60).toStringAsFixed(1)} minutes'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Return to video list
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    // Save progress if there are changes before returning
    if (_hasUnsavedChanges) {
      AppLogger.info('Saving progress before returning to video list');
      await _saveProgress();
      
      // Schedule notification to show on the previous screen
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Small delay to ensure we're back on the video list screen
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Progress saved successfully'),
                ],
              ),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    }
    return true; // Allow pop
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTranscript) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.video.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        await _handleWillPop();
        return false; // Prevent default pop behavior
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.video.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.restart_alt_outlined),
              onPressed: _showResetConfirmationDialog,
              tooltip: 'Reset Progress',
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
                  'YouTube player ready - updating video ready state',
                );
                setState(() {
                  _isVideoReady = true;
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
            isExpanded: _isProgressExpanded,
            onToggleExpanded: _toggleProgressExpanded,
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
          title: const Text('Playback Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Playback Speed'),
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
                title: const Text('Auto Repeat'),
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
                  title: const Text('Repeat Count'),
                  trailing: DropdownButton<int>(
                    value: tempAutoRepeatCount,
                    items: [1, 2, 3, 4, 5].map((count) {
                      return DropdownMenuItem(
                        value: count,
                        child: Text('$count time${count > 1 ? 's' : ''}'),
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
              child: const Text('Cancel'),
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
                          'Settings updated: speed=${_playbackSpeed}, autoRepeat=${_autoRepeat}, repeatCount=${_autoRepeatCount}',
                        );

                        // Save configuration to server
                        await _saveConfigurationToServer();

                        // Refresh user data to reflect the new configuration
                        final authProvider = Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        );
                        await authProvider.refreshUserData();
                        AppLogger.info('User data refreshed after config save');

                        // Show success message
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Settings saved successfully'),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
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
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleWillPop() async {
    try {
      // Only save if there are unsaved changes
      if (_hasUnsavedChanges) {
        await _saveProgress();
      }
      
      // Navigate back without notification
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      AppLogger.error('Error during navigation: $e');
      // Navigate back even if save fails
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _showResetConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: Colors.orange),
              SizedBox(width: 8),
              Text('Reset Progress'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to reset your progress for this video?',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                'This will:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text('• Clear all your typed text'),
              Text('• Reset completion status'),
              Text('• Return to the first sentence'),
              SizedBox(height: 12),
              Text(
                'This action cannot be undone.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
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
              child: const Text('Reset Progress'),
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
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Resetting...'),
              ],
            ),
            duration: Duration(seconds: 2),
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
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Reset completed'),
              ],
            ),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }

      AppLogger.info('Progress reset successfully for video: ${widget.video.videoId}');
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
                  child: Text('Reset failed: ${e.toString()}'),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sentence ${_currentSentenceIndex + 1} of ${_transcript.length}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                IconButton(
                  icon: Icon(
                    isRevealed ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: _toggleCurrentSentenceReveal,
                  tooltip: isRevealed ? 'Hide original' : 'Show original',
                  iconSize: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (comparison != null && !comparison.isEmpty) ...[
              SimpleComparisonWidget(
                comparison: comparison,
                showOriginal: isRevealed,
                showUserInput: true,
              ),
            ] else if (isRevealed) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Original:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(currentTranscript),
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
            color: Colors.black.withOpacity(0.1),
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
          hintText: 'Type what you hear...',
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
