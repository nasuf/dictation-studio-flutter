import 'package:flutter/foundation.dart';
import '../models/channel.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

class ChannelProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Channel> _channels = [];
  bool _isLoading = false;
  String? _error;
  String _languageFilter = AppConstants.languageAll;

  // Getters
  List<Channel> get channels => _channels;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get languageFilter => _languageFilter;

  // Filter channels by language (computed property)
  List<Channel> get filteredChannels {
    if (_languageFilter == AppConstants.languageAll) {
      return _channels;
    }
    return _channels
        .where((channel) => channel.language == _languageFilter)
        .toList();
  }

  // Fetch channels from API
  Future<void> fetchChannels() async {
    // Prevent duplicate requests
    if (_isLoading) return;

    _setLoading(true);
    _clearError();

    try {
      AppLogger.info(
        'Fetching channels with language filter: $_languageFilter',
      );
      final channelData = await _apiService.getChannels(
        language: _languageFilter,
        visibility: AppConstants.visibilityPublic,
      );
      _channels = channelData;
      AppLogger.info('Successfully fetched ${_channels.length} channels');
    } catch (e) {
      AppLogger.error('Error fetching channels: $e');
      _setError('Failed to load channels: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Set language filter and fetch channels
  void setLanguageFilter(String language) {
    if (_languageFilter == language) return; // Avoid unnecessary requests

    _languageFilter = language;
    AppLogger.info('Language filter changed to: $language');
    notifyListeners(); // Update UI with filtered results immediately
    fetchChannels(); // Fetch new data
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  // Clear error manually (for retry functionality)
  void clearError() {
    _clearError();
    notifyListeners();
  }
}
