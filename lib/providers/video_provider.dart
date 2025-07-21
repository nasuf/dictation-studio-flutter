import 'package:flutter/foundation.dart';
import '../models/video.dart';
import '../models/progress.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

class VideoProvider with ChangeNotifier {
  List<Video> _videos = [];
  Map<String, double> _progress = {};
  bool _isLoading = false;
  String? _error;
  String? _currentChannelId;
  bool _isUnauthorized = false;

  // Getters
  List<Video> get videos => _videos;
  Map<String, double> get progress => _progress;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentChannelId => _currentChannelId;
  bool get isUnauthorized => _isUnauthorized;

  // Get sorted videos (prioritize videos with progress, then by created date)
  List<Video> get sortedVideos {
    final List<Video> sorted = List.from(_videos);

    sorted.sort((a, b) {
      // Get progress for both videos
      final progressA = _progress[a.videoId] ?? 0.0;
      final progressB = _progress[b.videoId] ?? 0.0;

      // Check if videos have progress (> 0)
      final hasProgressA = progressA > 0;
      final hasProgressB = progressB > 0;

      // If one has progress and the other doesn't, prioritize the one with progress
      if (hasProgressA && !hasProgressB) {
        return -1; // a comes first
      }
      if (!hasProgressA && hasProgressB) {
        return 1; // b comes first
      }

      // If both have progress or both don't have progress, sort by created_at (descending)
      return b.createdAt.compareTo(a.createdAt);
    });

    // Debug sorting
    if (kDebugMode && sorted.isNotEmpty) {
      AppLogger.debug('🔄 VideoProvider sorting:');
      AppLogger.debug('  Total videos: ${sorted.length}');
      AppLogger.debug(
        '  Videos with progress: ${sorted.where((v) => (_progress[v.videoId] ?? 0.0) > 0).length}',
      );
      AppLogger.debug('  First 3 videos after sorting:');
      for (int i = 0; i < sorted.length && i < 3; i++) {
        final video = sorted[i];
        final progress = _progress[video.videoId] ?? 0.0;
        AppLogger.debug('    ${i + 1}. ${video.title} - ${progress}%');
      }
    }

    return sorted;
  }

  // Fetch videos for a specific channel
  Future<void> fetchVideos(
    String channelId, {
    String visibility = AppConstants.visibilityPublic,
    String? language,
    bool showLoading = true,
  }) async {
    if (showLoading) {
      _setLoading(true);
    }
    _setError(null);
    _setUnauthorized(false);
    _currentChannelId = channelId;

    try {
      // Fetch videos and progress in parallel
      final futures = await Future.wait([
        apiService.getVideoList(
          channelId,
          visibility: visibility,
          language: language,
        ),
        apiService.getChannelProgress(channelId),
      ]);

      final videoResponse = futures[0] as VideoListResponse;
      final progressResponse = futures[1] as ChannelProgress;

      _videos = videoResponse.videos;
      _progress = progressResponse.progress;

      if (kDebugMode) {
        AppLogger.debug(
          'Fetched ${_videos.length} videos for channel $channelId',
        );
        AppLogger.debug(
          'Progress data: ${_progress.keys.length} videos with progress',
        );
      }

      notifyListeners();
    } catch (e) {
      if (e.toString().contains('401')) {
        _setUnauthorized(true);
      } else {
        _setError(e.toString());
      }

      if (kDebugMode) {
        AppLogger.error('Error fetching videos: $e');
      }
    } finally {
      if (showLoading) {
        _setLoading(false);
      }
    }
  }

  // Refresh videos for current channel
  Future<void> refreshVideos() async {
    if (_currentChannelId != null) {
      await fetchVideos(_currentChannelId!, showLoading: false);
    }
  }

  // Get progress for a specific video
  double getVideoProgress(String videoId) {
    return _progress[videoId] ?? 0.0;
  }

  // Check if video has progress
  bool hasProgress(String videoId) {
    return _progress.containsKey(videoId) && _progress[videoId]! > 0;
  }

  // Update progress for a video
  void updateVideoProgress(String videoId, double progressValue) {
    _progress[videoId] = progressValue;
    notifyListeners();
  }

  // Get video by ID
  Video? getVideoById(String videoId) {
    try {
      return _videos.firstWhere((video) => video.videoId == videoId);
    } catch (e) {
      return null;
    }
  }

  // Save progress to server
  Future<void> saveVideoProgress(ProgressData progressData) async {
    try {
      await apiService.saveUserProgress(progressData);
      // Update local progress
      updateVideoProgress(progressData.videoId, progressData.overallCompletion);

      if (kDebugMode) {
        AppLogger.debug(
          'Progress saved for video ${progressData.videoId}: ${progressData.overallCompletion}%',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error('Error saving progress: $e');
      }
      // Don't show error to user, just log it
    }
  }

  // Check dictation quota
  Future<bool> checkQuota(String channelId, String videoId) async {
    try {
      return await apiService.checkDictationQuota(channelId, videoId);
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error('Error checking quota: $e');
      }
      return false;
    }
  }

  // Register dictation video
  Future<void> registerVideo(String channelId, String videoId) async {
    try {
      await apiService.registerDictationVideo(channelId, videoId);

      if (kDebugMode) {
        AppLogger.debug('Video registered: $videoId');
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error('Error registering video: $e');
      }
      rethrow;
    }
  }

  // Clear error
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  // Clear unauthorized state
  void clearUnauthorized() {
    if (_isUnauthorized) {
      _isUnauthorized = false;
      notifyListeners();
    }
  }

  // Clear all data
  void clear() {
    _videos.clear();
    _progress.clear();
    _currentChannelId = null;
    _error = null;
    _isUnauthorized = false;
    _isLoading = false;
    notifyListeners();
  }

  // Private methods
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  void _setUnauthorized(bool unauthorized) {
    if (_isUnauthorized != unauthorized) {
      _isUnauthorized = unauthorized;
      notifyListeners();
    }
  }
}
