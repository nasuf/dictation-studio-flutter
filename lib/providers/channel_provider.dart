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
  Future<void> fetchChannels({String? language, String? visibility}) async {
    // Prevent duplicate requests
    if (_isLoading) return;

    _setLoading(true);
    _clearError();

    try {
      final langFilter = language ?? _languageFilter;
      final visFilter =
          visibility ??
          AppConstants
              .visibilityPublic; // Changed from visibilityPublic to visibilityAll

      AppLogger.info(
        'Fetching channels with language filter: $langFilter, visibility: $visFilter',
      );
      final channelData = await _apiService.getChannels(
        visibility: visFilter,
        language: langFilter,
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

  // Add new channel
  Future<void> addChannel(Channel channel) async {
    try {
      AppLogger.info('Adding new channel: ${channel.name}');
      await _apiService.addChannels([channel]);

      // Add to local list
      _channels.add(channel);
      notifyListeners();

      AppLogger.info('Successfully added channel: ${channel.name}');
    } catch (e) {
      AppLogger.error('Error adding channel: $e');
      rethrow;
    }
  }

  // Update existing channel
  Future<void> updateChannel(
    String channelId, {
    String? name,
    String? imageUrl,
    String? link,
    String? language,
    String? visibility,
  }) async {
    try {
      AppLogger.info('Updating channel: $channelId');

      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (imageUrl != null) updateData['image_url'] = imageUrl;
      if (link != null) updateData['link'] = link;
      if (language != null) updateData['language'] = language;
      if (visibility != null) updateData['visibility'] = visibility;

      await _apiService.updateChannel(channelId, updateData);

      // Update local list
      final index = _channels.indexWhere((c) => c.id == channelId);
      if (index != -1) {
        final updatedChannel = _channels[index].copyWith(
          name: name,
          imageUrl: imageUrl,
          link: link,
          language: language,
          visibility: visibility,
        );
        _channels[index] = updatedChannel;
        notifyListeners();
      }

      AppLogger.info('Successfully updated channel: $channelId');
    } catch (e) {
      AppLogger.error('Error updating channel: $e');
      rethrow;
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
