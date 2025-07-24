import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'dart:async';

import '../models/transcript_item.dart';
import '../models/video.dart';
import '../models/progress.dart';
import '../utils/video_playback_utils.dart';
import '../utils/language_utils.dart';
import '../utils/logger.dart';
import '../services/api_service.dart';
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

  // Progress tracking
  double _overallCompletion = 0.0;
  double _overallAccuracy = 0.0;
  int _totalTime = 0; // in seconds

  // Configuration
  double _playbackSpeed = 1.0;
  int _autoRepeatCount = 1;
  bool _autoRepeat = true;

  // Timers
  Timer? _progressTimer;
  Timer? _autoSaveTimer;
  int _autoSaveInputCount = 0;

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
    _saveProgress(); // Save before disposing

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

    // Initialize playback controller with configuration
    _playbackController = VideoPlaybackController(
      _youtubeController,
      onStateChange: _onPlaybackStateChange,
      onProgress: _onPlaybackProgress,
      config: const PlaybackConfig(
        playbackSpeed: 1.0,
        timeAccuracy: 0.1,
        bufferTolerance: 0.3,
        maxRetries: 2, // Reduce retries to fail faster
        retryDelay: Duration(milliseconds: 200),
        enableLogging: true,
      ),
    );

    // Initialize text controller and focus
    _textController = TextEditingController();
    _textFocusNode = FocusNode();

    _textController.addListener(_onTextChanged);
    _textFocusNode.addListener(_onFocusChanged);
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
      AppLogger.info('YouTube player is ready and functional - buttons should be enabled now');
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

    // Auto-save timer
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_hasUnsavedChanges) {
        _saveProgress();
      }
    });
  }

  void _stopTimers() {
    _progressTimer?.cancel();
    _autoSaveTimer?.cancel();
  }

  Future<void> _loadTranscript() async {
    try {
      AppLogger.info(
        'Loading transcript for video: ${widget.videoId} in channel: ${widget.channelId}',
      );

      // Fetch transcript and user progress concurrently
      AppLogger.info('Calling APIs for transcript and progress...');
      final futures = await Future.wait([
        apiService.getVideoTranscript(widget.channelId, widget.videoId),
        apiService.getUserProgress(widget.channelId, widget.videoId).catchError(
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
      AppLogger.info('Progress response keys: ${progressResponse.keys.toList()}');
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
            AppLogger.info('✓ Valid progress found with ${userInput.length} inputs');
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
          final userInput = userInputData[i.toString()] ?? '';
          newTranscript.add(_transcript[i].copyWith(userInput: userInput));
          
          // Store in our map too
          if (userInput.isNotEmpty) {
            _userInput[i] = userInput;
          }
        }
        _transcript = newTranscript;

        // Find last input index - exactly like React line 380-383
        final lastInputIndex = _userInput.keys.isEmpty 
            ? 0 
            : _userInput.keys.reduce((a, b) => a > b ? a : b);
        
        // Set current sentence index to last input - like React line 383
        _currentSentenceIndex = lastInputIndex.clamp(0, _transcript.length - 1);

        // Set revealed sentences - like React lines 385-386  
        _revealedSentences.clear();
        _revealedSentences.addAll(_userInput.keys);
        
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
            _youtubeController.seekTo(Duration(seconds: targetSegment.start.toInt()));
            AppLogger.info('Video seeked to ${targetSegment.start} seconds for restored progress');
          } catch (e) {
            AppLogger.warning('Failed to seek video during progress restoration: $e');
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
      if (state == VideoPlaybackState.paused || state == VideoPlaybackState.ended) {
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

      // Auto-save after certain number of inputs
      _autoSaveInputCount++;
      if (_autoSaveInputCount >= 5) {
        _saveProgress();
        _autoSaveInputCount = 0;
      }
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
      
      AppLogger.info('Sentence $_currentSentenceIndex marked as completed: "$input"');
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
        final words = _transcript[playedIndex].transcript.trim().split(RegExp(r'\s+'));
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
          final words = _transcript[completedIndex].transcript.trim().split(RegExp(r'\s+'));
          totalCompletedOriginalWords += words.where((w) => w.isNotEmpty).length;
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
          ? (totalCorrectWords / totalCompletedOriginalWords * 100).clamp(0.0, 100.0)
          : 0.0;
    });

    AppLogger.info('Progress updated - Completion: ${_overallCompletion.toStringAsFixed(1)}%, Accuracy: ${_overallAccuracy.toStringAsFixed(1)}%');
    AppLogger.info('Played sentences: $_playedSentences, Completed sentences: $_completedSentences');
    AppLogger.info('Total correct words: $totalCorrectWords, Completed original words: $totalCompletedOriginalWords, Played original words: $playedOriginalWords');

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
    if (!_hasUnsavedChanges) return;

    try {
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

      await apiService.saveUserProgress(progressData);

      setState(() {
        _hasUnsavedChanges = false;
      });

      AppLogger.info('Progress saved successfully');
    } catch (e) {
      AppLogger.error('Failed to save progress: $e');
    }
  }

  // Playback control methods
  Future<void> _playCurrentSentence() async {
    if (_currentSentenceIndex >= _transcript.length) return;
    
    // Check if video is ready before attempting to play
    if (!_isVideoReady) {
      AppLogger.warning('Video not ready, cannot play current sentence');
      _showPlaybackErrorSnackBar();
      return;
    }

    try {
      final segment = _transcript[_currentSentenceIndex];
      AppLogger.info(
        'Playing sentence ${_currentSentenceIndex + 1}: "${segment.transcript}"',
      );

      // Set loading state when starting playback
      setState(() {
        _isVideoLoading = true;
        // 记录这个句子已经被播放过
        _playedSentences.add(_currentSentenceIndex);
      });
      AppLogger.info('Video loading state set to true');

      await _playbackController.playSegment(segment);

      // Auto-repeat if enabled
      if (_autoRepeat && _autoRepeatCount > 1) {
        for (int i = 1; i < _autoRepeatCount; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          await _playbackController.playSegment(segment);
        }
      }
    } catch (e) {
      AppLogger.error('Error playing current sentence: $e');
      // Reset loading state on error
      setState(() {
        _isVideoLoading = false;
      });
      _showPlaybackErrorSnackBar();
    }
  }

  /// Play button should move to the next sentence after the last input
  /// This matches React version behavior
  Future<void> _handlePlayButtonClick() async {
    // Find the next sentence to play after the last input
    if (_userInput.isNotEmpty) {
      final lastInputIndex = _userInput.keys.reduce((a, b) => a > b ? a : b);
      final nextIndex = (lastInputIndex + 1).clamp(0, _transcript.length - 1);
      
      // Only move if we're not already positioned correctly
      if (_currentSentenceIndex != nextIndex) {
        setState(() {
          _currentSentenceIndex = nextIndex;
          _textController.text = _userInput[_currentSentenceIndex] ?? '';
        });
        AppLogger.info('Play button: moved to sentence ${nextIndex + 1} (next after last input)');
      }
    }
    
    await _playCurrentSentence();
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
    _saveCurrentInput();
    
    // 标记当前句子为完成状态（如果有输入）
    _markCurrentSentenceCompleted();
    
    // Auto-save progress after completing a sentence
    await _saveProgress();

    if (_currentSentenceIndex < _transcript.length - 1) {
      setState(() {
        _currentSentenceIndex++;
        // 不再自动显示原文，用户需要手动控制
        _textController.text = _userInput[_currentSentenceIndex] ?? '';
      });

      await _playCurrentSentence();
    }
  }

  Future<void> _playPreviousSentence() async {
    if (_currentSentenceIndex > 0) {
      setState(() {
        _currentSentenceIndex--;
        _textController.text = _userInput[_currentSentenceIndex] ?? '';
      });

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
      _transcript[_currentSentenceIndex] = _transcript[_currentSentenceIndex].copyWith(userInput: text);
      
      // Add to revealed sentences - like React lines 670-674
      if (!_revealedSentences.contains(_currentSentenceIndex)) {
        _revealedSentences.add(_currentSentenceIndex);
      }
      
      _performComparison(_currentSentenceIndex);
      
      // Auto-save after input - like React lines 679-682
      Future.delayed(const Duration(milliseconds: 200), () {
        _saveProgress();
      });
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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTranscript) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.video.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.video.title),
        actions: [
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
                AppLogger.info('YouTube player ready - updating video ready state');
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
                onPlayCurrent: _isVideoReady ? () {
                  AppLogger.info('Play current button clicked - video ready: $_isVideoReady');
                  _handlePlayButtonClick();
                } : null,
                onPlayNext: _isVideoReady && !_isVideoLoading && _currentSentenceIndex < _transcript.length - 1 ? _playNextSentence : null,
                onPlayPrevious: _isVideoReady && !_isVideoLoading && _currentSentenceIndex > 0 ? _playPreviousSentence : null,
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
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Playback Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Playback Speed'),
              trailing: DropdownButton<double>(
                value: _playbackSpeed,
                items: [0.5, 0.75, 1.0, 1.25, 1.5].map((speed) {
                  return DropdownMenuItem(
                    value: speed,
                    child: Text('${speed}x'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _playbackSpeed = value;
                    });
                    _playbackController.setPlaybackSpeed(value);
                  }
                },
              ),
            ),
            ListTile(
              title: const Text('Auto Repeat'),
              trailing: Switch(
                value: _autoRepeat,
                onChanged: (value) {
                  setState(() {
                    _autoRepeat = value;
                  });
                },
              ),
            ),
            if (_autoRepeat)
              ListTile(
                title: const Text('Repeat Count'),
                trailing: DropdownButton<int>(
                  value: _autoRepeatCount,
                  items: [1, 2, 3].map((count) {
                    return DropdownMenuItem(
                      value: count,
                      child: Text('$count'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _autoRepeatCount = value;
                      });
                    }
                  },
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
                icon: const Icon(Icons.keyboard_voice),
                onPressed: () {
                  // Voice input could be implemented here
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Voice input not yet implemented'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        onSubmitted: (text) async {
          _saveCurrentInput();
          // Mark current sentence as completed if there's input
          _markCurrentSentenceCompleted();
          // Auto-save progress after submitting
          await _saveProgress();
          
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
