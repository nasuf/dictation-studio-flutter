import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

class AdminStats {
  final int totalUsers;
  final int activeUsers;
  final int totalChannels;
  final int totalVideos;

  AdminStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.totalChannels,
    required this.totalVideos,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      totalUsers: json['totalUsers'] ?? 0,
      activeUsers: json['activeUsers'] ?? 0,
      totalChannels: json['totalChannels'] ?? 0,
      totalVideos: json['totalVideos'] ?? 0,
    );
  }

  AdminStats copyWith({
    int? totalUsers,
    int? activeUsers,
    int? totalChannels,
    int? totalVideos,
  }) {
    return AdminStats(
      totalUsers: totalUsers ?? this.totalUsers,
      activeUsers: activeUsers ?? this.activeUsers,
      totalChannels: totalChannels ?? this.totalChannels,
      totalVideos: totalVideos ?? this.totalVideos,
    );
  }
}

class AdminProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  AdminStats? _adminStats;
  bool _isLoading = false;
  String? _error;
  bool _hasLoadedStats = false;

  // Getters
  AdminStats? get adminStats => _adminStats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLoadedStats => _hasLoadedStats;

  // Load admin statistics
  Future<void> loadAdminStats({bool forceRefresh = false}) async {
    // Only load if we haven't loaded before or if it's a forced refresh
    if (!forceRefresh && _hasLoadedStats) {
      AppLogger.info('📊 Admin stats already loaded, skipping...');
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('📊 Loading admin statistics...');

      // Fetch all required data in parallel
      final results = await Future.wait([
        _fetchUserStats(),
        _fetchChannelAndVideoStats(),
      ]);

      final userStats = results[0];
      final channelVideoStats = results[1];

      _adminStats = AdminStats(
        totalUsers: userStats['total'] ?? 0,
        activeUsers: userStats['active'] ?? 0,
        totalChannels: channelVideoStats['channels'] ?? 0,
        totalVideos: channelVideoStats['videos'] ?? 0,
      );

      _hasLoadedStats = true;
      AppLogger.success('✅ Admin statistics loaded successfully');
      AppLogger.info(
        'Stats: ${_adminStats!.totalUsers} users, ${_adminStats!.activeUsers} active, ${_adminStats!.totalChannels} channels, ${_adminStats!.totalVideos} videos',
      );
    } catch (e) {
      AppLogger.error('❌ Failed to load admin statistics: $e');
      _setError('Failed to load admin statistics: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Refresh admin statistics
  Future<void> refreshAdminStats() async {
    AppLogger.info('🔄 Manual refresh of admin statistics');
    await loadAdminStats(forceRefresh: true);
  }

  // Fetch user statistics (total and active users)
  Future<Map<String, int>> _fetchUserStats() async {
    try {
      final response = await _apiService.getAllUsers();
      final users = response['users'] as List;

      int totalUsers = users.length;
      int activeUsers = 0;

      // Count active users (users who have dictation progress)
      for (final user in users) {
        if (_checkUserHasDictationInput(user)) {
          activeUsers++;
        }
      }

      AppLogger.info('👥 User stats: $totalUsers total, $activeUsers active');
      return {'total': totalUsers, 'active': activeUsers};
    } catch (e) {
      AppLogger.error('❌ Failed to fetch user stats: $e');
      throw Exception('Failed to fetch user statistics');
    }
  }

  // Fetch channel and video counts using efficient backend endpoint
  Future<Map<String, int>> _fetchChannelAndVideoStats() async {
    try {
      final response = await _apiService.getAdminStats();

      final channelCount = response['total_channels'] ?? 0;
      final videoCount = response['total_videos'] ?? 0;

      AppLogger.info('📺 Channel count: $channelCount');
      AppLogger.info('🎬 Video count: $videoCount');

      return {'channels': channelCount, 'videos': videoCount};
    } catch (e) {
      AppLogger.error('❌ Failed to fetch channel and video stats: $e');
      throw Exception('Failed to fetch channel and video statistics');
    }
  }

  // Check if user has real dictation input (is an active user)
  bool _checkUserHasDictationInput(Map<String, dynamic> user) {
    final dictationProgress = user['dictation_progress'];
    if (dictationProgress == null) {
      return false;
    }

    // Check if any channel has meaningful user input
    for (final channelKey in dictationProgress.keys) {
      final channelProgress = dictationProgress[channelKey];

      // Check if user has made any input
      if (channelProgress != null &&
          channelProgress['userInput'] != null &&
          channelProgress['userInput'] is Map) {
        final inputEntries = (channelProgress['userInput'] as Map).entries;

        // Check if there are any non-empty user inputs
        for (final entry in inputEntries) {
          final inputValue = entry.value;
          if (inputValue != null &&
              inputValue is String &&
              inputValue.trim().isNotEmpty) {
            return true;
          }
        }
      }
    }

    return false;
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // Reset state when user logs out
  void reset() {
    _adminStats = null;
    _isLoading = false;
    _error = null;
    _hasLoadedStats = false;
    notifyListeners();
  }
}
