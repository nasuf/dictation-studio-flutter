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
  bool _isProgressExpanded = false;

  bool _isLoadingTranscript = true;
  bool _isCompleted = false;
  bool _hasUnsavedChanges = false;
  bool _isTimerRunning = false;

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

    AppLogger.info(
      'YouTube player state changed: $playerState, ready: $isReady',
    );

    // Handle player ready state
    if (isReady && playerState != PlayerState.unknown) {
      AppLogger.info('YouTube player is ready and functional');
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

      // Restore user progress if exists
      if (progressResponse['data'] != null) {
        final progressData = progressResponse['data'] as Map<String, dynamic>;
        if (progressData['userInput'] != null &&
            (progressData['userInput'] as Map).isNotEmpty) {
          await _restoreUserProgress(progressData);
        }
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

      // Restore user input and merge back into transcript
      final userInputData = progressData['userInput'] as Map<String, dynamic>?;
      if (userInputData != null) {
        // Convert string keys to int and store in _userInput map
        _userInput.clear();
        userInputData.forEach((key, value) {
          final intKey = int.tryParse(key);
          if (intKey != null && value is String) {
            _userInput[intKey] = value;
          }
        });

        // Update transcript items with user input
        for (int i = 0; i < _transcript.length; i++) {
          if (_userInput.containsKey(i)) {
            _transcript[i] = _transcript[i].copyWith(userInput: _userInput[i]);
          }
        }
      }

      // Restore current position - find last input index
      if (_userInput.isNotEmpty) {
        final lastInputIndex = _userInput.keys.reduce((a, b) => a > b ? a : b);
        _currentSentenceIndex = lastInputIndex.clamp(0, _transcript.length - 1);
      }

      // Restore revealed sentences (ones with user input)
      _revealedSentences.clear();
      _revealedSentences.addAll(_userInput.keys);

      // Restore overall completion and other metrics
      final completion = progressData['overallCompletion'];
      if (completion != null) {
        _overallCompletion = (completion is double)
            ? completion
            : (completion as num).toDouble();
      }

      // Recalculate comparisons for existing inputs
      _recalculateAllComparisons();

      setState(() {
        _hasUnsavedChanges = false; // Just loaded, so no unsaved changes
      });

      AppLogger.info(
        'Restored progress: ${_userInput.length} inputs, ${_overallCompletion.toStringAsFixed(1)}% complete',
      );
    } catch (e) {
      AppLogger.warning('Could not restore user progress: $e');
    }
  }

  void _onPlaybackStateChange(VideoPlaybackState state) {
    AppLogger.info('Playback state changed: $state');

    setState(() {
      _isTimerRunning = state == VideoPlaybackState.playing;
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

    _updateOverallProgress();
  }

  void _recalculateAllComparisons() {
    for (int i = 0; i < _transcript.length; i++) {
      if (_userInput.containsKey(i)) {
        _performComparison(i);
      }
    }
  }

  void _updateOverallProgress() {
    int totalSentences = _transcript.length;
    int completedSentences = 0;
    double totalAccuracy = 0.0;

    for (int i = 0; i < totalSentences; i++) {
      final input = _userInput[i];
      if (input != null && input.trim().isNotEmpty) {
        completedSentences++;
        final result = _comparisonResults[i];
        if (result != null) {
          totalAccuracy += result.accuracy;
        }
      }
    }

    setState(() {
      _overallCompletion = totalSentences > 0
          ? (completedSentences / totalSentences * 100).clamp(0.0, 100.0)
          : 0.0;
      _overallAccuracy = completedSentences > 0
          ? (totalAccuracy / completedSentences).clamp(0.0, 100.0)
          : 0.0;
    });

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

    try {
      final segment = _transcript[_currentSentenceIndex];
      AppLogger.info(
        'Playing sentence ${_currentSentenceIndex + 1}: "${segment.transcript}"',
      );

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
      _showPlaybackErrorSnackBar();
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
    _saveCurrentInput();

    if (_currentSentenceIndex < _transcript.length - 1) {
      setState(() {
        _currentSentenceIndex++;
        _revealedSentences.add(_currentSentenceIndex);
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
      _performComparison(_currentSentenceIndex);
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
                AppLogger.info('YouTube player ready');
              },
              onEnded: (metaData) {
                AppLogger.info('YouTube video ended');
              },
            ),
            builder: (context, player) {
              return VideoPlayerWithControls(
                youtubeController: _youtubeController,
                playbackController: _playbackController,
                onPlayCurrent: _playCurrentSentence,
                onPlayNext: _playNextSentence,
                onPlayPrevious: _playPreviousSentence,
                canGoNext: _currentSentenceIndex < _transcript.length - 1,
                canGoPrevious: _currentSentenceIndex > 0,
                isPlaying: _playbackController.isPlayingSegment,
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
                  ).colorScheme.surfaceVariant.withOpacity(0.3),
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
        onSubmitted: (text) {
          _saveCurrentInput();
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
