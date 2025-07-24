import 'dart:async';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/transcript_item.dart';
import '../utils/logger.dart';

/// Video playback states
enum VideoPlaybackState {
  unstarted,
  ended,
  playing,
  paused,
  buffering,
  cued,
}

/// Configuration for video playback
class PlaybackConfig {
  final double playbackSpeed;
  final double timeAccuracy; // Accuracy in seconds for stopping
  final double bufferTolerance; // Extra buffer time before force stop
  final int maxRetries;
  final Duration retryDelay;
  final bool enableLogging;

  const PlaybackConfig({
    this.playbackSpeed = 1.0,
    this.timeAccuracy = 0.1,
    this.bufferTolerance = 0.5,
    this.maxRetries = 3,
    this.retryDelay = const Duration(milliseconds: 100),
    this.enableLogging = true,
  });

  static const PlaybackConfig defaultConfig = PlaybackConfig();
}

/// Callback for playback state changes
typedef PlaybackStateCallback = void Function(VideoPlaybackState state);
typedef PlaybackProgressCallback = void Function(double currentTime);

/// Controller for precise video segment playback
class VideoPlaybackController {
  final YoutubePlayerController _playerController;
  final PlaybackConfig _config;
  final PlaybackStateCallback? _onStateChange;
  final PlaybackProgressCallback? _onProgress;
  
  // Current playback speed (can be updated dynamically)
  double _currentPlaybackSpeed;

  Timer? _progressTimer;
  Timer? _stopTimer;
  bool _isPlaying = false;
  bool _isCancelled = false; // Cancellation flag
  double? _segmentEndTime;
  Completer<void>? _playbackCompleter;

  VideoPlaybackController(
    this._playerController, {
    PlaybackConfig config = PlaybackConfig.defaultConfig,
    PlaybackStateCallback? onStateChange,
    PlaybackProgressCallback? onProgress,
  }) : _config = config,
       _onStateChange = onStateChange,
       _onProgress = onProgress,
       _currentPlaybackSpeed = config.playbackSpeed {
    _initializeListener();
  }

  /// Initialize player state listener
  void _initializeListener() {
    _playerController.addListener(_onPlayerStateChange);
  }

  /// Handle player state changes
  void _onPlayerStateChange() {
    final playerState = _getVideoPlaybackState();
    _onStateChange?.call(playerState);
    
    if (_config.enableLogging) {
      AppLogger.info('Video player state changed to: $playerState');
    }
    
    // Handle automatic stopping for segment playback
    if (_isPlaying && _segmentEndTime != null) {
      final currentTime = _playerController.value.position.inMilliseconds / 1000.0;
      if (currentTime >= _segmentEndTime! - _config.timeAccuracy) {
        _stopSegmentPlayback();
      }
    }
  }

  /// Convert YouTube player state to our enum
  VideoPlaybackState _getVideoPlaybackState() {
    if (_playerController.value.isPlaying) {
      return VideoPlaybackState.playing;
    } else if (_playerController.value.hasPlayed) {
      return VideoPlaybackState.paused;
    } else {
      return VideoPlaybackState.unstarted;
    }
  }

  /// Play a specific transcript segment with precise timing
  Future<void> playSegment(TranscriptItem segment) async {
    try {
      // Always stop any existing playback first (like React version)
      await stop();
      
      // Reset cancellation flag for new playback
      _isCancelled = false;
      
      // Check if player is ready or can be made ready
      if (!_playerController.value.isReady) {
        AppLogger.info('Player not ready, waiting...');
        await _waitForPlayerReady();
      }
      
      // Check if cancelled during preparation
      if (_isCancelled) {
        AppLogger.info('Playback cancelled during preparation');
        return;
      }
      
      await _playTranscriptSegment(segment);
    } catch (e) {
      AppLogger.error('Error playing segment: $e');
      // Don't rethrow - show user a friendly error instead
      _onStateChange?.call(VideoPlaybackState.paused);
    }
  }

  /// Check if we can control the player
  bool _canControlPlayer() {
    try {
      // Try to access player state - this will throw if player is not accessible
      final state = _playerController.value.playerState;
      AppLogger.info('Player state check: $state');
      return true;
    } catch (e) {
      AppLogger.warning('Cannot control player: $e');
      return false;
    }
  }

  /// Wait for actual playback to start with enhanced buffering detection
  Future<void> _waitForPlaybackToStart() async {
    int attempts = 0;
    const maxAttempts = 50; // 5 seconds total for first-time loading
    bool wasBuffering = false;
    
    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
      
      try {
        final isPlaying = _playerController.value.isPlaying;
        final playerState = _playerController.value.playerState;
        final currentTime = _playerController.value.position.inMilliseconds / 1000.0;
        
        // Track if we've been buffering
        if (playerState == PlayerState.buffering) {
          wasBuffering = true;
        }
        
        // Only confirm playback if:
        // 1. Player is actually playing
        // 2. Player state is playing 
        // 3. Current time is progressing (not stuck at 0)
        // 4. If we were buffering, make sure we've moved past buffering
        if (isPlaying && 
            playerState == PlayerState.playing && 
            currentTime > 0 &&
            (!wasBuffering || playerState != PlayerState.buffering)) {
          AppLogger.info('Video playback confirmed after ${attempts * 100}ms, position: ${currentTime}s');
          
          // Wait an additional 200ms to ensure stable playback
          await Future.delayed(const Duration(milliseconds: 200));
          return;
        }
        
        if (attempts % 10 == 0) { // Log every 1000ms
          AppLogger.info('Waiting for playback to start... attempt $attempts, state: $playerState, playing: $isPlaying, time: ${currentTime}s, wasBuffering: $wasBuffering');
        }
      } catch (e) {
        AppLogger.warning('Error checking playback state: $e');
      }
    }
    
    // Enhanced fallback: try to get current position before proceeding
    try {
      final currentTime = _playerController.value.position.inMilliseconds / 1000.0;
      AppLogger.warning('Playback start not confirmed after ${maxAttempts * 100}ms, current time: ${currentTime}s, proceeding anyway');
    } catch (e) {
      AppLogger.warning('Playback start not confirmed and cannot get position: $e, proceeding anyway');
    }
  }

  /// Wait for YouTube player to be ready with fallback approach
  Future<void> _waitForPlayerReady() async {
    int attempts = 0;
    const maxAttempts = 30; // 3 seconds total
    
    while (!_playerController.value.isReady && attempts < maxAttempts) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
      if (attempts % 10 == 0) { // Log every second
        AppLogger.info('Waiting for player ready... attempt $attempts');
      }
    }
    
    // If player is not ready, try a more relaxed approach
    if (!_playerController.value.isReady) {
      AppLogger.warning('Player not ready after ${maxAttempts * 100}ms, trying fallback approach');
      
      // Check if we can at least get the player state
      try {
        final playerState = _playerController.value.playerState;
        AppLogger.info('Player state: $playerState');
        
        // If we can get the state, consider it "ready enough" for our purposes
        if (playerState == PlayerState.unStarted || 
            playerState == PlayerState.paused ||
            playerState == PlayerState.playing ||
            playerState == PlayerState.ended) {
          AppLogger.info('Using fallback: Player has valid state, proceeding');
          return;
        }
      } catch (e) {
        AppLogger.error('Error getting player state: $e');
      }
      
      // Last resort: wait a bit more and proceed anyway
      AppLogger.warning('Final fallback: Proceeding with potentially unready player');
      await Future.delayed(const Duration(milliseconds: 500));
    } else {
      AppLogger.info('YouTube player is ready');
    }
  }

  /// Internal method to play transcript segment (single attempt, no retries)
  Future<void> _playTranscriptSegment(TranscriptItem segment) async {
    if (_isCancelled) {
      AppLogger.info('Segment playback cancelled before starting');
      return;
    }
    
    if (_config.enableLogging) {
      AppLogger.info('Playing segment: ${segment.start}s - ${segment.end}s');
    }

    // Validate segment
    if (segment.start < 0 || segment.end <= segment.start) {
      throw ArgumentError('Invalid segment times: ${segment.start} - ${segment.end}');
    }

    // Single attempt only - no retry mechanism to avoid chaos during sentence switching
    await _attemptSegmentPlayback(segment);
  }

  /// Single attempt to play a segment with enhanced precision and error handling
  Future<void> _attemptSegmentPlayback(TranscriptItem segment) async {
    if (_isCancelled) {
      AppLogger.info('Segment playback attempt cancelled');
      return;
    }
    
    AppLogger.info('Attempting to play segment: ${segment.start}s - ${segment.end}s');
    
    // Set up completion tracking
    _playbackCompleter = Completer<void>();
    _segmentEndTime = segment.end;
    _isPlaying = true;

    try {
      // Check if we can control the player
      if (!_canControlPlayer()) {
        throw Exception('Cannot control YouTube player - player may not be properly initialized');
      }
      
      // Set playback speed with error handling (use current dynamic speed)
      try {
        _playerController.setPlaybackRate(_currentPlaybackSpeed);
        AppLogger.info('Set playback speed to: ${_currentPlaybackSpeed}');
      } catch (e) {
        AppLogger.warning('Failed to set playback rate: $e, continuing anyway');
      }
      
      // Seek to start position with precise timing
      final seekTime = (segment.start * 1000).round();
      AppLogger.info('Seeking to: ${seekTime}ms');
      
      try {
        _playerController.seekTo(Duration(milliseconds: seekTime));
        
        // Wait for seek to complete - longer delay for reliability
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Verify current position for debugging
        try {
          final currentPos = _playerController.value.position.inMilliseconds / 1000.0;
          AppLogger.info('Position after seek: ${currentPos}s (target: ${segment.start}s)');
        } catch (e) {
          AppLogger.warning('Could not verify position: $e');
        }
      } catch (e) {
        AppLogger.warning('Seek operation failed: $e, attempting to play anyway');
      }
      
      // Start playing with error handling
      try {
        _playerController.play();
        AppLogger.info('Initiated playback command');
        
        // Check for cancellation before starting playback
        if (_isCancelled) {
          AppLogger.info('Playback cancelled before starting');
          return;
        }
        
        // Wait for actual playback to start before setting up timers
        await _waitForPlaybackToStart();
        AppLogger.info('Playback confirmed to have started');
      } catch (e) {
        AppLogger.error('Failed to start playback: $e');
        throw Exception('Could not start video playback: $e');
      }

      // Check for cancellation after playback starts
      if (_isCancelled) {
        AppLogger.info('Playback cancelled after starting');
        return;
      }

      // Set up monitoring timers with enhanced precision
      _startProgressMonitoring();
      _startStopTimer(segment);

      // Wait for playback to complete with cancellation checking
      await _playbackCompleter!.future.timeout(
        Duration(seconds: (segment.duration + 5).round()),
        onTimeout: () {
          if (!_isCancelled) {
            throw TimeoutException('Segment playback timeout', Duration(seconds: segment.duration.round()));
          }
        },
      );

    } finally {
      _cleanup();
    }
  }

  /// Start monitoring playback progress with enhanced precision
  void _startProgressMonitoring() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isPlaying || _isCancelled) {
        timer.cancel();
        return;
      }

      try {
        final currentTime = _playerController.value.position.inMilliseconds / 1000.0;
        final isActuallyPlaying = _playerController.value.isPlaying;
        
        // Only call progress callback if video is actually playing
        if (isActuallyPlaying) {
          _onProgress?.call(currentTime);
        }

        // Enhanced stopping logic with better precision
        if (_segmentEndTime != null) {
          final timeRemaining = _segmentEndTime! - currentTime;
          
          // More conservative stopping: only stop if we're clearly past the end
          // Account for YouTube player's slight timing inconsistencies
          if (timeRemaining <= -0.1) { // Allow 100ms overshoot to prevent premature stopping
            if (_config.enableLogging) {
              AppLogger.info('Stopping playback at ${currentTime}s (target: ${_segmentEndTime}s, overshoot: ${(-timeRemaining).toStringAsFixed(3)}s)');
            }
            _stopSegmentPlayback();
          } else if (timeRemaining <= 0.2 && !isActuallyPlaying) {
            // If we're very close to the end and playback has naturally stopped, also stop
            if (_config.enableLogging) {
              AppLogger.info('Stopping playback due to natural end at ${currentTime}s (target: ${_segmentEndTime}s)');
            }
            _stopSegmentPlayback();
          }
        }
      } catch (e) {
        AppLogger.warning('Error in progress monitoring: $e');
      }
    });
  }

  /// Start timer to force stop at segment end with dynamic calculation
  void _startStopTimer(TranscriptItem segment) {
    // Check cancellation before setting up timer
    if (_isCancelled) return;
    
    // Get current actual position to calculate remaining time more accurately
    try {
      final currentTime = _playerController.value.position.inMilliseconds / 1000.0;
      // Add extra buffer time to prevent premature stopping - let progress monitoring handle precise timing
      final extraBuffer = 0.5; // Extra 500ms buffer for safety
      final remainingTime = segment.end - currentTime + _config.bufferTolerance + extraBuffer;
      final duration = Duration(milliseconds: (remainingTime * 1000).round().clamp(1000, 35000)); // Min 1s, max 35s
      
      AppLogger.info('Setting stop timer for ${remainingTime.toStringAsFixed(1)}s (from ${currentTime}s to ${segment.end}s, with safety buffer)');
      
      _stopTimer = Timer(duration, () {
        if (_isPlaying && !_isCancelled) {
          AppLogger.warning('Force stopping segment playback due to safety timeout (this should rarely happen)');
          _stopSegmentPlayback();
        }
      });
    } catch (e) {
      // Fallback to original logic if getting position fails
      AppLogger.warning('Could not get current position for timer, using fallback: $e');
      final duration = Duration(milliseconds: ((segment.end - segment.start + _config.bufferTolerance + 1.0) * 1000).round());
      
      _stopTimer = Timer(duration, () {
        if (_isPlaying) {
          AppLogger.warning('Force stopping segment playback due to safety timeout (fallback)');
          _stopSegmentPlayback();
        }
      });
    }
  }

  /// Stop segment playback
  void _stopSegmentPlayback() {
    if (!_isPlaying) return;

    _isPlaying = false;
    _segmentEndTime = null;

    // Pause the player
    _playerController.pause();

    // Complete the playback future
    if (_playbackCompleter != null && !_playbackCompleter!.isCompleted) {
      _playbackCompleter!.complete();
    }

    if (_config.enableLogging) {
      AppLogger.info('Segment playback stopped');
    }
  }

  /// Clean up only timers without changing playback state
  void _cleanupTimersOnly() {
    _progressTimer?.cancel();
    _stopTimer?.cancel();
    _progressTimer = null;
    _stopTimer = null;
  }

  /// Clean up timers and state
  void _cleanup() {
    _cleanupTimersOnly();
    _isPlaying = false;
    _segmentEndTime = null;
  }

  /// Stop any current playback immediately
  Future<void> stop() async {
    AppLogger.info('Stopping playback immediately');
    
    // Set cancellation flag immediately to stop all ongoing operations
    _isCancelled = true;
    
    // Mark as not playing first to prevent any ongoing operations
    _isPlaying = false;
    _segmentEndTime = null;
    
    // Cancel and complete any pending operations
    if (_playbackCompleter != null && !_playbackCompleter!.isCompleted) {
      _playbackCompleter!.complete();
    }
    
    // Clean up timers
    _cleanup();
    
    // Pause the player
    try {
      _playerController.pause();
    } catch (e) {
      AppLogger.warning('Error pausing player during stop: $e');
    }
  }

  /// Set playback speed
  Future<void> setPlaybackSpeed(double speed) async {
    _currentPlaybackSpeed = speed;
    _playerController.setPlaybackRate(speed);
    AppLogger.info('Updated YouTube player playback speed to: ${speed}x');
  }

  /// Get current playback time in seconds
  double get currentTime => _playerController.value.position.inMilliseconds / 1000.0;

  /// Get video duration in seconds
  double get duration => _playerController.metadata.duration.inMilliseconds / 1000.0;

  /// Check if currently playing a segment
  bool get isPlayingSegment => _isPlaying;

  /// Get current playback state
  VideoPlaybackState get playbackState => _getVideoPlaybackState();

  /// Dispose of the controller
  void dispose() {
    _cleanup();
    _playerController.removeListener(_onPlayerStateChange);
  }
}

/// Utility functions for video playback
class VideoPlaybackUtils {
  /// Extracts YouTube video ID from various URL formats
  static String? extractVideoId(String url) {
    return YoutubePlayer.convertUrlToId(url);
  }

  /// Validates if a URL is a valid YouTube URL
  static bool isValidYouTubeUrl(String url) {
    return extractVideoId(url) != null;
  }

  /// Formats time in seconds to MM:SS format
  static String formatTime(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Calculates optimal segment duration for merging
  static double calculateOptimalSegmentDuration(List<TranscriptItem> items) {
    if (items.isEmpty) return 10.0; // Default 10 seconds

    final durations = items.map((item) => item.duration).toList();
    durations.sort();

    // Use median duration as base, with reasonable bounds
    final median = durations[durations.length ~/ 2];
    return median.clamp(5.0, 15.0); // Between 5-15 seconds
  }

  /// Merges short transcript segments for better playback experience
  static List<TranscriptItem> mergeShortSegments(
    List<TranscriptItem> items, {
    double maxDuration = 10.0,
    double minDuration = 2.0,
  }) {
    if (items.isEmpty) return [];

    final merged = <TranscriptItem>[];
    TranscriptItem? current;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      
      if (current == null) {
        current = item;
        continue;
      }

      // Check if we should merge
      final wouldMergeDuration = item.end - current.start;
      final shouldMerge = current.duration < minDuration || 
                         (wouldMergeDuration <= maxDuration && 
                          !_isCompleteSentence(current.transcript));

      if (shouldMerge) {
        // Merge with current
        current = TranscriptItem(
          start: current.start,
          end: item.end,
          transcript: '${current.transcript} ${item.transcript}'.trim(),
          index: current.index,
        );
      } else {
        // Save current and start new
        merged.add(current);
        current = item;
      }
    }

    // Add the last segment
    if (current != null) {
      merged.add(current);
    }

    return merged;
  }

  /// Simple sentence completion check
  static bool _isCompleteSentence(String text) {
    final trimmed = text.trim();
    return RegExp(r'[.!?。！？]$').hasMatch(trimmed);
  }

  /// Creates YouTube player options for dictation
  static Map<String, dynamic> getDictationPlayerOptions() {
    return {
      'autoplay': 0,
      'modestbranding': 1,
      'controls': 1,
      'disablekb': 1, // Disable keyboard controls
      'cc': 0, // Force disable captions
      'rel': 0, // Don't show related videos
      'showinfo': 0, // Don't show video info
    };
  }
}