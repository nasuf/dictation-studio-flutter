import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/transcript_item.dart';
import '../utils/logger.dart';

/// Video playback states
enum VideoPlaybackState { unstarted, ended, playing, paused, buffering, cued }

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
    this.timeAccuracy = 0.05,
    this.bufferTolerance = 0.3,
    this.maxRetries = 3,
    this.retryDelay = const Duration(milliseconds: 200),
    this.enableLogging = true,
  });

  static const PlaybackConfig defaultConfig = PlaybackConfig();
}

/// Callback for playback state changes
typedef PlaybackStateCallback = void Function(VideoPlaybackState state);
typedef PlaybackProgressCallback = void Function(double currentTime);

/// Callback for playback failure
typedef PlaybackFailureCallback = void Function(String reason);

/// Controller for precise video segment playback
class VideoPlaybackController {
  final YoutubePlayerController _playerController;
  final PlaybackConfig _config;
  final PlaybackStateCallback? _onStateChange;
  final PlaybackProgressCallback? _onProgress;
  final PlaybackFailureCallback? _onPlaybackFailure;

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
    PlaybackFailureCallback? onPlaybackFailure,
  }) : _config = config,
       _onStateChange = onStateChange,
       _onProgress = onProgress,
       _onPlaybackFailure = onPlaybackFailure,
       _currentPlaybackSpeed = config.playbackSpeed {
    _initializeListener();
  }

  /// Initialize player state listener
  void _initializeListener() {
    _playerController.addListener(_onPlayerStateChange);
  }

  bool get _isIOSPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool get _supportsPlaybackRateChange => !_isIOSPlatform;

  /// Handle player state changes
  void _onPlayerStateChange() {
    final playerState = _getVideoPlaybackState();
    _onStateChange?.call(playerState);

    if (_config.enableLogging) {
      AppLogger.info('Video player state changed to: $playerState');
    }

    // Handle automatic stopping for segment playback
    if (_isPlaying && _segmentEndTime != null) {
      final currentTime =
          _playerController.value.position.inMilliseconds / 1000.0;
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

      _applyPlaybackSpeed(_currentPlaybackSpeed);

      if (_isCancelled) {
        AppLogger.info('Playback cancelled after speed preparation');
        return;
      }

      await _playTranscriptSegment(segment);
    } catch (e) {
      if (_isCancelled) {
        if (_config.enableLogging) {
          AppLogger.info('Playback cancelled: $e');
        }
        return;
      }

      AppLogger.error('Error playing segment: $e');
      _onStateChange?.call(VideoPlaybackState.paused);
      rethrow;
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

  void _applyPlaybackSpeed(double speed) {
    if (!_supportsPlaybackRateChange) {
      if (_config.enableLogging) {
        AppLogger.info(
          'Skipping playback rate change for unsupported platform',
        );
      }
      return;
    }

    try {
      _playerController.setPlaybackRate(speed);
      if (_config.enableLogging) {
        AppLogger.info('Playback rate set to ${speed.toStringAsFixed(2)}x');
      }
    } catch (e) {
      AppLogger.warning('Failed to set playback rate: $e');
    }
  }

  /// Enhanced wait strategy for iOS devices with actual playback verification
  Future<void> _waitForPlaybackSimple() async {
    int attempts = 0;
    const maxAttempts = 30; // 3 seconds total
    double lastPosition = -1;
    bool playbackConfirmed = false;

    while (attempts < maxAttempts && !playbackConfirmed) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;

      try {
        final isPlaying = _playerController.value.isPlaying;
        final playerState = _playerController.value.playerState;
        final currentTime =
            _playerController.value.position.inMilliseconds / 1000.0;

        // Check if we have actual progress (time is moving forward)
        bool hasProgress = currentTime > lastPosition && currentTime > 0;
        lastPosition = currentTime;

        // Confirm playback if player is playing and time is progressing
        if (isPlaying && playerState == PlayerState.playing && hasProgress) {
          playbackConfirmed = true;
          AppLogger.info(
            'iOS playback confirmed after ${attempts * 100}ms, position: ${currentTime}s',
          );

          // Wait additional time to ensure stable playback before setting up timers
          await Future.delayed(const Duration(milliseconds: 300));
          return;
        }

        if (attempts % 10 == 0) {
          // Log every second
          AppLogger.info(
            'iOS waiting for playback... attempt $attempts, state: $playerState, playing: $isPlaying, time: ${currentTime}s, hasProgress: $hasProgress',
          );
        }
      } catch (e) {
        AppLogger.warning('Error checking iOS playback state: $e');
      }
    }

    // If we couldn't confirm playback, still proceed but with caution
    AppLogger.warning(
      'iOS playback not fully confirmed after ${maxAttempts * 100}ms, proceeding with caution',
    );
    await Future.delayed(
      const Duration(milliseconds: 500),
    ); // Extra buffer time
  }

  Future<void> _confirmPlaybackStarted(int attemptNumber) async {
    if (_isIOSPlatform) {
      await _waitForPlaybackSimple();
      return;
    }

    const int maxChecks = 10;
    int checks = 0;

    while (checks < maxChecks && !_isCancelled) {
      await Future.delayed(const Duration(milliseconds: 200));
      checks++;

      try {
        final value = _playerController.value;
        final state = value.playerState;
        final isPlaying = value.isPlaying;

        if (isPlaying ||
            state == PlayerState.playing ||
            state == PlayerState.buffering) {
          return;
        }

        if (state == PlayerState.paused || state == PlayerState.cued) {
          _playerController.play();
        }
      } catch (e) {
        AppLogger.warning('Error confirming playback start: $e');
      }
    }

    throw Exception(
      'Playback did not start after ${(maxChecks * 200)}ms (attempt $attemptNumber)',
    );
  }

  /// Wait for YouTube player to be ready with fallback approach
  Future<void> _waitForPlayerReady() async {
    int attempts = 0;
    const maxAttempts = 30; // 3 seconds total

    while (!_playerController.value.isReady && attempts < maxAttempts) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
      if (attempts % 10 == 0) {
        // Log every second
        AppLogger.info('Waiting for player ready... attempt $attempts');
      }
    }

    // If player is not ready, try a more relaxed approach
    if (!_playerController.value.isReady) {
      AppLogger.warning(
        'Player not ready after ${maxAttempts * 100}ms, trying fallback approach',
      );

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
      AppLogger.warning(
        'Final fallback: Proceeding with potentially unready player',
      );
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

    if (segment.start < 0 || segment.end <= segment.start) {
      throw ArgumentError(
        'Invalid segment times: ${segment.start} - ${segment.end}',
      );
    }

    Exception? lastError;

    for (
      int attempt = 1;
      attempt <= _config.maxRetries && !_isCancelled;
      attempt++
    ) {
      try {
        await _attemptSegmentPlayback(segment, attempt);
        return;
      } catch (e) {
        if (_isCancelled) {
          AppLogger.info('Segment playback cancelled during attempt $attempt');
          return;
        }

        lastError = e is Exception ? e : Exception(e.toString());

        if (_config.enableLogging) {
          AppLogger.warning('Segment playback attempt $attempt failed: $e');
        }

        if (attempt < _config.maxRetries) {
          await Future.delayed(_config.retryDelay * attempt);
        }
      }
    }

    if (lastError != null) {
      throw lastError;
    }
  }

  /// Single attempt to play a segment with enhanced precision and error handling
  Future<void> _attemptSegmentPlayback(
    TranscriptItem segment,
    int attemptNumber,
  ) async {
    if (_isCancelled) {
      AppLogger.info('Segment playback attempt cancelled');
      return;
    }

    AppLogger.info(
      'Attempting to play segment: ${segment.start}s - ${segment.end}s (attempt $attemptNumber/${_config.maxRetries})',
    );

    // Set up completion tracking
    _playbackCompleter = Completer<void>();
    _segmentEndTime = segment.end;
    _isPlaying = true;

    try {
      // Check if we can control the player
      if (!_canControlPlayer()) {
        throw Exception(
          'Cannot control YouTube player - player may not be properly initialized',
        );
      }

      // Ensure we start from a paused state for deterministic behavior
      try {
        _playerController.pause();
      } catch (e) {
        AppLogger.warning('Pause before seek failed: $e');
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
          final currentPos =
              _playerController.value.position.inMilliseconds / 1000.0;
          AppLogger.info(
            'Position after seek: ${currentPos}s (target: ${segment.start}s)',
          );
        } catch (e) {
          AppLogger.warning('Could not verify position: $e');
        }
      } catch (e) {
        AppLogger.warning(
          'Seek operation failed: $e, attempting to play anyway',
        );
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

        await _confirmPlaybackStarted(attemptNumber);
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
      final playbackDurationSeconds =
          segment.duration /
          (_currentPlaybackSpeed > 0 ? _currentPlaybackSpeed : 1.0);
      final timeoutSeconds = (playbackDurationSeconds + 5).clamp(2.0, 60.0);
      final timeoutDuration = Duration(
        milliseconds: (timeoutSeconds * 1000).round(),
      );

      await _playbackCompleter!.future.timeout(
        timeoutDuration,
        onTimeout: () {
          if (!_isCancelled) {
            throw TimeoutException('Segment playback timeout', timeoutDuration);
          }
        },
      );
    } finally {
      _cleanup();
    }
  }

  /// Start monitoring playback progress with enhanced precision
  void _startProgressMonitoring() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      // Reduced frequency to 100ms
      if (!_isPlaying || _isCancelled) {
        timer.cancel();
        return;
      }

      try {
        final currentTime =
            _playerController.value.position.inMilliseconds / 1000.0;
        final isActuallyPlaying = _playerController.value.isPlaying;
        final playerState = _playerController.value.playerState;

        // Only call progress callback if video is actually playing
        if (isActuallyPlaying) {
          _onProgress?.call(currentTime);
        }

        if (_segmentEndTime != null) {
          final bufferTolerance = _config.bufferTolerance;
          final timeAccuracy = _config.timeAccuracy;
          final shouldStopByTime =
              currentTime >= (_segmentEndTime! - timeAccuracy);
          final exceededBuffer =
              currentTime > (_segmentEndTime! + bufferTolerance);
          final externalStop =
              playerState == PlayerState.paused ||
              playerState == PlayerState.ended;

          if (exceededBuffer || externalStop || shouldStopByTime) {
            if (_config.enableLogging) {
              final reason = exceededBuffer
                  ? 'buffer tolerance exceeded'
                  : externalStop
                  ? 'player state $playerState'
                  : 'time threshold reached';
              AppLogger.info(
                'Stopping playback at ${currentTime.toStringAsFixed(3)}s (target: ${_segmentEndTime!.toStringAsFixed(3)}s, reason: $reason)',
              );
            }
            _stopSegmentPlayback();
          }
        }
      } catch (e) {
        AppLogger.warning('Error in progress monitoring: $e');
      }
    });
  }

  /// Start timer to force stop at segment end with enhanced safety buffer
  void _startStopTimer(TranscriptItem segment) {
    // Check cancellation before setting up timer
    if (_isCancelled) return;

    final segmentDuration = (segment.end - segment.start).clamp(0.05, 600.0);
    final effectiveSpeed = _currentPlaybackSpeed > 0
        ? _currentPlaybackSpeed
        : 1.0;
    final playbackSeconds = segmentDuration / effectiveSpeed;
    final guardBuffer = (_config.bufferTolerance + 0.3);
    final totalSeconds = playbackSeconds + guardBuffer;
    final totalMillis = (totalSeconds * 1000).round();
    final clampedMillis = totalMillis.clamp(1200, 35000).toInt();

    if (_config.enableLogging) {
      AppLogger.info(
        'Setting safety stop timer for ${totalSeconds.toStringAsFixed(2)}s (segment=${segmentDuration.toStringAsFixed(2)}s, speed=${effectiveSpeed.toStringAsFixed(2)}x)',
      );
    }

    _stopTimer = Timer(Duration(milliseconds: clampedMillis), () {
      try {
        if (_isPlaying && !_isCancelled) {
          final currentTime =
              _playerController.value.position.inMilliseconds / 1000.0;
          AppLogger.warning(
            'Safety stop timer triggered at ${currentTime.toStringAsFixed(3)}s (target ${segment.end.toStringAsFixed(3)}s)',
          );

          if (currentTime <= segment.start + 0.5) {
            _checkPlaybackFailureReason();
          }

          _stopSegmentPlayback();
        }
      } catch (e) {
        AppLogger.warning('Error in safety stop timer: $e');
      }
    });
  }

  /// Stop segment playback
  void _stopSegmentPlayback() {
    if (!_isPlaying) return;

    _isPlaying = false;
    _segmentEndTime = null;

    _cleanupTimersOnly();

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
    _playbackCompleter = null;
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

    if (_config.enableLogging) {
      AppLogger.info('Setting playback speed to ${speed.toStringAsFixed(2)}x');
    }

    _applyPlaybackSpeed(speed);
  }

  /// Get current playback time in seconds
  double get currentTime =>
      _playerController.value.position.inMilliseconds / 1000.0;

  /// Get video duration in seconds
  double get duration =>
      _playerController.metadata.duration.inMilliseconds / 1000.0;

  /// Check if currently playing a segment
  bool get isPlayingSegment => _isPlaying;

  /// Get current playback state
  VideoPlaybackState get playbackState => _getVideoPlaybackState();

  /// Check if playback failure is due to login issues
  void _checkPlaybackFailureReason() {
    try {
      final playerState = _playerController.value.playerState;
      final isReady = _playerController.value.isReady;
      final currentTime =
          _playerController.value.position.inMilliseconds / 1000.0;

      AppLogger.info(
        'Checking playback failure reason: state=$playerState, ready=$isReady, time=$currentTime',
      );

      // 关键检测：如果播放器ready但状态一直不是playing，且时间没有进展
      // 但要确保播放器确实ready且有合理的状态
      if (isReady &&
          playerState != PlayerState.playing &&
          playerState != PlayerState.paused &&
          (playerState == PlayerState.unknown ||
              playerState == PlayerState.unStarted ||
              playerState == PlayerState.buffering) &&
          currentTime <= 1.0) {
        // 时间基本没有进展

        AppLogger.warning(
          'Detected potential login issue: ready but not playing, time not progressing',
        );
        _onPlaybackFailure?.call('login_required');
      } else {
        AppLogger.info(
          'Playback failure doesn\'t seem to be login-related (state=$playerState, ready=$isReady, time=$currentTime)',
        );
      }
    } catch (e) {
      AppLogger.error('Error checking playback failure reason: $e');
    }
  }

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

  /// Formats time in seconds to MM:SS.xx format with centisecond precision
  static String formatTime(double seconds) {
    final totalMilliseconds = (seconds * 1000).round();
    final minutes = totalMilliseconds ~/ 60000;
    final remainingMilliseconds = totalMilliseconds % 60000;
    final wholeSeconds = remainingMilliseconds ~/ 1000;
    final centiseconds =
        (remainingMilliseconds % 1000) ~/ 10; // Get centiseconds (hundredths)

    return '${minutes.toString().padLeft(2, '0')}:${wholeSeconds.toString().padLeft(2, '0')}.${centiseconds.toString().padLeft(2, '0')}';
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
      final shouldMerge =
          current.duration < minDuration ||
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
