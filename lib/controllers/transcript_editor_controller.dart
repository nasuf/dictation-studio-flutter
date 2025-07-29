import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/transcript_item.dart';
import '../models/transcript_editor_state.dart';
import '../utils/video_playback_utils.dart';
import '../utils/logger.dart';

/// Controller for transcript editing functionality
class TranscriptEditorController extends ChangeNotifier {
  TranscriptEditorState _state = const TranscriptEditorState();
  VideoPlaybackController? _playbackController;
  YoutubePlayerController? _youtubeController;
  Timer? _videoTimeTracker;

  TranscriptEditorState get state => _state;

  /// Initialize the controller with a YouTube player controller
  void initialize(YoutubePlayerController youtubeController) {
    _youtubeController = youtubeController;
    _playbackController = VideoPlaybackController(
      youtubeController,
      onStateChange: _onPlaybackStateChange,
      onProgress: _onPlaybackProgress,
      onPlaybackFailure: _onPlaybackFailure,
    );
    
    // Start tracking video time
    _startVideoTimeTracking();
  }

  /// Load transcript items for editing
  Future<TranscriptEditorResult> loadTranscript(List<TranscriptItem> items) async {
    try {
      // Create a backup of original items for undo functionality
      final originalItems = <int, TranscriptItem>{};
      for (int i = 0; i < items.length; i++) {
        originalItems[i] = items[i];
      }

      _state = _state.copyWith(
        transcriptItems: List.from(items),
        originalItems: originalItems,
        userModifiedTimes: {},
        hasUnsavedChanges: false,
        errorMessage: null,
      );

      notifyListeners();
      return TranscriptEditorResult.success(
        message: 'Transcript loaded successfully',
        newState: _state,
      );
    } catch (e) {
      AppLogger.error('Error loading transcript: $e');
      return TranscriptEditorResult.failure('Failed to load transcript: $e');
    }
  }

  /// Edit transcript text for a specific segment
  Future<TranscriptEditorResult> editTranscriptText(int index, String newText) async {
    if (index < 0 || index >= _state.transcriptItems.length) {
      return TranscriptEditorResult.failure('Invalid segment index');
    }

    try {
      final items = List<TranscriptItem>.from(_state.transcriptItems);
      final currentItem = items[index];
      
      // Update the transcript text
      items[index] = TranscriptItem(
        start: currentItem.start,
        end: currentItem.end,
        transcript: newText.trim(),
        index: currentItem.index,
      );

      _state = _state.copyWith(
        transcriptItems: items,
        hasUnsavedChanges: true,
        currentEditingIndex: -1, // Clear editing state
      );

      notifyListeners();
      return TranscriptEditorResult.success(
        message: 'Text updated successfully',
        newState: _state,
      );
    } catch (e) {
      AppLogger.error('Error editing transcript text: $e');
      return TranscriptEditorResult.failure('Failed to update text: $e');
    }
  }

  /// Record start time for a segment using current video time
  Future<TranscriptEditorResult> recordStartTime(int index) async {
    if (index < 0 || index >= _state.transcriptItems.length) {
      return TranscriptEditorResult.failure('Invalid segment index');
    }

    if (_youtubeController == null) {
      return TranscriptEditorResult.failure('Video player not initialized');
    }

    try {
      final currentTime = _youtubeController!.value.position.inMilliseconds / 1000.0;
      final items = List<TranscriptItem>.from(_state.transcriptItems);
      final currentItem = items[index];
      
      // Update start time and ensure end time is after start time
      final newEndTime = currentItem.end <= currentTime ? currentTime + 1.0 : currentItem.end;
      
      items[index] = TranscriptItem(
        start: currentTime,
        end: newEndTime,
        transcript: currentItem.transcript,
        index: currentItem.index,
      );

      // Always update previous segment's end time to match current segment's start time
      if (index > 0) {
        final prevItem = items[index - 1];
        items[index - 1] = TranscriptItem(
          start: prevItem.start,
          end: currentTime, // Set previous segment's end time to match current start time
          transcript: prevItem.transcript,
          index: prevItem.index,
        );
        
        // Mark previous segment as user-modified too since we changed its end time
        final userModifiedTimes = Map<int, bool>.from(_state.userModifiedTimes);
        userModifiedTimes[index] = true;
        userModifiedTimes[index - 1] = true; // Mark previous segment as modified
        
        _state = _state.copyWith(
          transcriptItems: items,
          userModifiedTimes: userModifiedTimes,
          hasUnsavedChanges: true,
        );
      } else {
        // Only current segment modified if it's the first one
        final userModifiedTimes = Map<int, bool>.from(_state.userModifiedTimes);
        userModifiedTimes[index] = true;
        
        _state = _state.copyWith(
          transcriptItems: items,
          userModifiedTimes: userModifiedTimes,
          hasUnsavedChanges: true,
        );
      }

      notifyListeners();
      
      final message = index > 0 
        ? 'Start time recorded: ${VideoPlaybackUtils.formatTime(currentTime)} (previous segment end time updated)'
        : 'Start time recorded: ${VideoPlaybackUtils.formatTime(currentTime)}';
        
      return TranscriptEditorResult.success(
        message: message,
        newState: _state,
      );
    } catch (e) {
      AppLogger.error('Error recording start time: $e');
      return TranscriptEditorResult.failure('Failed to record start time: $e');
    }
  }

  /// Record end time for a segment using current video time
  Future<TranscriptEditorResult> recordEndTime(int index) async {
    if (index < 0 || index >= _state.transcriptItems.length) {
      return TranscriptEditorResult.failure('Invalid segment index');
    }

    if (_youtubeController == null) {
      return TranscriptEditorResult.failure('Video player not initialized');
    }

    try {
      final currentTime = _youtubeController!.value.position.inMilliseconds / 1000.0;
      final items = List<TranscriptItem>.from(_state.transcriptItems);
      final currentItem = items[index];
      
      // Ensure end time is after start time
      if (currentTime <= currentItem.start) {
        return TranscriptEditorResult.failure('End time must be after start time');
      }

      // Update current segment's end time
      items[index] = TranscriptItem(
        start: currentItem.start,
        end: currentTime,
        transcript: currentItem.transcript,
        index: currentItem.index,
      );

      // Always update next segment's start time to match current segment's end time
      if (index < items.length - 1) {
        final nextItem = items[index + 1];
        items[index + 1] = TranscriptItem(
          start: currentTime, // Set next segment's start time to match current end time
          end: nextItem.end > currentTime ? nextItem.end : currentTime + 1.0,
          transcript: nextItem.transcript,
          index: nextItem.index,
        );
        
        // Mark next segment as user-modified too since we changed its start time
        final userModifiedTimes = Map<int, bool>.from(_state.userModifiedTimes);
        userModifiedTimes[index] = true;
        userModifiedTimes[index + 1] = true; // Mark next segment as modified
        
        _state = _state.copyWith(
          transcriptItems: items,
          userModifiedTimes: userModifiedTimes,
          hasUnsavedChanges: true,
        );
      } else {
        // Only current segment modified if it's the last one
        final userModifiedTimes = Map<int, bool>.from(_state.userModifiedTimes);
        userModifiedTimes[index] = true;
        
        _state = _state.copyWith(
          transcriptItems: items,
          userModifiedTimes: userModifiedTimes,
          hasUnsavedChanges: true,
        );
      }

      notifyListeners();
      
      final message = index < items.length - 1 
        ? 'End time recorded: ${VideoPlaybackUtils.formatTime(currentTime)} (next segment start time updated)'
        : 'End time recorded: ${VideoPlaybackUtils.formatTime(currentTime)}';
        
      return TranscriptEditorResult.success(
        message: message,
        newState: _state,
      );
    } catch (e) {
      AppLogger.error('Error recording end time: $e');
      return TranscriptEditorResult.failure('Failed to record end time: $e');
    }
  }

  /// Undo time changes for a segment
  Future<TranscriptEditorResult> undoTimeChanges(int index) async {
    if (index < 0 || index >= _state.transcriptItems.length) {
      return TranscriptEditorResult.failure('Invalid segment index');
    }

    final originalItem = _state.getOriginalItem(index);
    if (originalItem == null) {
      return TranscriptEditorResult.failure('No original data to restore');
    }

    try {
      final items = List<TranscriptItem>.from(_state.transcriptItems);
      final currentItem = items[index];
      
      // Restore original start and end times
      items[index] = TranscriptItem(
        start: originalItem.start,
        end: originalItem.end,
        transcript: currentItem.transcript, // Keep current text
        index: currentItem.index,
      );

      // Remove user-modified flag
      final userModifiedTimes = Map<int, bool>.from(_state.userModifiedTimes);
      userModifiedTimes.remove(index);

      _state = _state.copyWith(
        transcriptItems: items,
        userModifiedTimes: userModifiedTimes,
        hasUnsavedChanges: true,
      );

      notifyListeners();
      return TranscriptEditorResult.success(
        message: 'Times restored to original values',
        newState: _state,
      );
    } catch (e) {
      AppLogger.error('Error undoing time changes: $e');
      return TranscriptEditorResult.failure('Failed to undo changes: $e');
    }
  }

  /// Play a specific transcript segment
  Future<TranscriptEditorResult> playSegment(int index) async {
    if (index < 0 || index >= _state.transcriptItems.length) {
      return TranscriptEditorResult.failure('Invalid segment index');
    }

    if (_playbackController == null) {
      return TranscriptEditorResult.failure('Video controller not initialized');
    }

    try {
      final segment = _state.transcriptItems[index];
      
      _state = _state.copyWith(
        currentPlayingIndex: index,
        isVideoPlaying: true,
      );
      notifyListeners();

      await _playbackController!.playSegment(segment);
      
      return TranscriptEditorResult.success(
        message: 'Playing segment ${index + 1}',
        newState: _state,
      );
    } catch (e) {
      AppLogger.error('Error playing segment: $e');
      _state = _state.copyWith(
        currentPlayingIndex: -1,
        isVideoPlaying: false,
      );
      notifyListeners();
      return TranscriptEditorResult.failure('Failed to play segment: $e');
    }
  }

  /// Stop current playback
  Future<TranscriptEditorResult> stopPlayback() async {
    if (_playbackController == null) {
      return TranscriptEditorResult.failure('Video controller not initialized');
    }

    try {
      await _playbackController!.stop();
      
      _state = _state.copyWith(
        currentPlayingIndex: -1,
        isVideoPlaying: false,
      );
      notifyListeners();

      return TranscriptEditorResult.success(
        message: 'Playback stopped',
        newState: _state,
      );
    } catch (e) {
      AppLogger.error('Error stopping playback: $e');
      return TranscriptEditorResult.failure('Failed to stop playback: $e');
    }
  }

  /// Seek video to specific time
  Future<TranscriptEditorResult> seekToTime(double time) async {
    if (_youtubeController == null) {
      return TranscriptEditorResult.failure('Video player not initialized');
    }

    try {
      final duration = Duration(milliseconds: (time * 1000).round());
      _youtubeController!.seekTo(duration);
      
      return TranscriptEditorResult.success(
        message: 'Seeking to ${VideoPlaybackUtils.formatTime(time)}',
      );
    } catch (e) {
      AppLogger.error('Error seeking to time: $e');
      return TranscriptEditorResult.failure('Failed to seek: $e');
    }
  }

  /// Set playback speed
  Future<TranscriptEditorResult> setPlaybackSpeed(double speed) async {
    if (_playbackController == null) {
      return TranscriptEditorResult.failure('Video controller not initialized');
    }

    try {
      await _playbackController!.setPlaybackSpeed(speed);
      
      _state = _state.copyWith(playbackSpeed: speed);
      notifyListeners();

      return TranscriptEditorResult.success(
        message: 'Playback speed set to ${speed}x',
        newState: _state,
      );
    } catch (e) {
      AppLogger.error('Error setting playback speed: $e');
      return TranscriptEditorResult.failure('Failed to set speed: $e');
    }
  }

  /// Start editing a specific segment
  void startEditing(int index) {
    _state = _state.copyWith(currentEditingIndex: index);
    notifyListeners();
  }

  /// Stop editing current segment
  void stopEditing() {
    _state = _state.clearCurrentEditingIndex();
    notifyListeners();
  }

  /// Handle playback state changes
  void _onPlaybackStateChange(VideoPlaybackState state) {
    final isPlaying = state == VideoPlaybackState.playing;
    if (_state.isVideoPlaying != isPlaying) {
      _state = _state.copyWith(isVideoPlaying: isPlaying);
      notifyListeners();
    }
  }

  /// Handle playback progress updates
  void _onPlaybackProgress(double currentTime) {
    if (_state.currentVideoTime != currentTime) {
      _state = _state.copyWith(currentVideoTime: currentTime);
      notifyListeners();
    }
  }

  /// Handle playback failures
  void _onPlaybackFailure(String reason) {
    _state = _state.copyWith(
      errorMessage: 'Playback failed: $reason',
      isVideoPlaying: false,
      currentPlayingIndex: -1,
    );
    notifyListeners();
  }

  /// Start tracking video time for UI updates
  void _startVideoTimeTracking() {
    _videoTimeTracker?.cancel();
    _videoTimeTracker = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_youtubeController != null && _youtubeController!.value.isReady) {
        final currentTime = _youtubeController!.value.position.inMilliseconds / 1000.0;
        if (_state.currentVideoTime != currentTime) {
          _state = _state.copyWith(currentVideoTime: currentTime);
          notifyListeners();
        }
      }
    });
  }

  /// Add a new transcript segment
  Future<TranscriptEditorResult> addSegment({
    required int afterIndex,
    double? startTime,
    double? endTime,
    String? text,
  }) async {
    try {
      final items = List<TranscriptItem>.from(_state.transcriptItems);
      
      // Determine start and end times
      final segmentStart = startTime ?? _state.currentVideoTime;
      final segmentEnd = endTime ?? (segmentStart + 3.0); // Default 3 seconds
      
      final newSegment = TranscriptItem(
        start: segmentStart,
        end: segmentEnd,
        transcript: text ?? '',
        index: items.length,
      );

      // Insert at the specified position
      items.insert(afterIndex + 1, newSegment);

      // Update indices
      for (int i = 0; i < items.length; i++) {
        items[i] = TranscriptItem(
          start: items[i].start,
          end: items[i].end,
          transcript: items[i].transcript,
          index: i,
        );
      }

      _state = _state.copyWith(
        transcriptItems: items,
        hasUnsavedChanges: true,
      );

      notifyListeners();
      return TranscriptEditorResult.success(
        message: 'New segment added',
        newState: _state,
      );
    } catch (e) {
      AppLogger.error('Error adding segment: $e');
      return TranscriptEditorResult.failure('Failed to add segment: $e');
    }
  }

  /// Delete a transcript segment
  Future<TranscriptEditorResult> deleteSegment(int index) async {
    if (index < 0 || index >= _state.transcriptItems.length) {
      return TranscriptEditorResult.failure('Invalid segment index');
    }

    try {
      final items = List<TranscriptItem>.from(_state.transcriptItems);
      items.removeAt(index);

      // Update indices
      for (int i = 0; i < items.length; i++) {
        items[i] = TranscriptItem(
          start: items[i].start,
          end: items[i].end,
          transcript: items[i].transcript,
          index: i,
        );
      }

      // Update user modified times map
      final userModifiedTimes = Map<int, bool>.from(_state.userModifiedTimes);
      userModifiedTimes.remove(index);

      _state = _state.copyWith(
        transcriptItems: items,
        userModifiedTimes: userModifiedTimes,
        hasUnsavedChanges: true,
        currentEditingIndex: -1,
        currentPlayingIndex: -1,
      );

      notifyListeners();
      return TranscriptEditorResult.success(
        message: 'Segment deleted',
        newState: _state,
      );
    } catch (e) {
      AppLogger.error('Error deleting segment: $e');
      return TranscriptEditorResult.failure('Failed to delete segment: $e');
    }
  }

  /// Clear any error message
  void clearError() {
    if (_state.errorMessage != null) {
      _state = _state.clearError();
      notifyListeners();
    }
  }

  /// Toggle selection mode
  void toggleSelectionMode() {
    if (_state.isSelectionMode) {
      // Exit selection mode and clear selections
      _state = _state.clearSelection();
    } else {
      // Enter selection mode
      _state = _state.copyWith(isSelectionMode: true);
    }
    notifyListeners();
  }

  /// Toggle segment selection
  void toggleSegmentSelection(int index) {
    if (index < 0 || index >= _state.transcriptItems.length) return;

    final newSelectedSegments = Set<int>.from(_state.selectedSegments);
    
    if (newSelectedSegments.contains(index)) {
      newSelectedSegments.remove(index);
    } else {
      newSelectedSegments.add(index);
    }

    _state = _state.copyWith(
      selectedSegments: newSelectedSegments,
      isSelectionMode: newSelectedSegments.isNotEmpty,
    );
    notifyListeners();
  }

  /// Select range of segments
  void selectSegmentRange(int startIndex, int endIndex) {
    if (startIndex < 0 || endIndex >= _state.transcriptItems.length || startIndex > endIndex) {
      return;
    }

    final newSelectedSegments = <int>{};
    for (int i = startIndex; i <= endIndex; i++) {
      newSelectedSegments.add(i);
    }

    _state = _state.copyWith(
      selectedSegments: newSelectedSegments,
      isSelectionMode: true,
    );
    notifyListeners();
  }

  /// Clear selection
  void clearSelection() {
    _state = _state.clearSelection();
    notifyListeners();
  }

  /// Merge selected segments
  Future<TranscriptEditorResult> mergeSelectedSegments() async {
    if (!_state.hasSelectedSegments) {
      return TranscriptEditorResult.failure('No segments selected');
    }

    if (!_state.areSelectedSegmentsConsecutive) {
      return TranscriptEditorResult.failure('Selected segments must be consecutive');
    }

    try {
      final selectedList = _state.selectedSegmentsList;
      final firstIndex = selectedList.first;

      final items = List<TranscriptItem>.from(_state.transcriptItems);
      
      // Get the segments to merge
      final segmentsToMerge = selectedList.map((i) => items[i]).toList();
      
      // Create merged segment
      final mergedSegment = TranscriptItem(
        start: segmentsToMerge.first.start,
        end: segmentsToMerge.last.end,
        transcript: segmentsToMerge
            .map((s) => s.transcript.trim())
            .where((text) => text.isNotEmpty)
            .join(' ')
            .trim(),
        index: firstIndex,
      );

      // Remove old segments (in reverse order to maintain indices)
      for (int i = selectedList.length - 1; i >= 0; i--) {
        items.removeAt(selectedList[i]);
      }

      // Insert merged segment at the first position
      items.insert(firstIndex, mergedSegment);

      // Update indices for all segments
      for (int i = 0; i < items.length; i++) {
        items[i] = TranscriptItem(
          start: items[i].start,
          end: items[i].end,
          transcript: items[i].transcript,
          index: i,
        );
      }

      // Update user modified times (remove old entries and mark merged segment as modified)
      final userModifiedTimes = Map<int, bool>.from(_state.userModifiedTimes);
      for (int index in selectedList) {
        userModifiedTimes.remove(index);
      }
      userModifiedTimes[firstIndex] = true;

      _state = _state.copyWith(
        transcriptItems: items,
        userModifiedTimes: userModifiedTimes,
        hasUnsavedChanges: true,
        selectedSegments: const <int>{},
        isSelectionMode: false,
      );

      notifyListeners();
      return TranscriptEditorResult.success(
        message: 'Merged ${selectedList.length} segments into one',
        newState: _state,
      );
    } catch (e) {
      AppLogger.error('Error merging segments: $e');
      return TranscriptEditorResult.failure('Failed to merge segments: $e');
    }
  }

  /// Apply trim spaces to all segments
  Future<TranscriptEditorResult> trimAllSpaces() async {
    try {
      final items = _state.transcriptItems.map((item) {
        // Trim leading/trailing spaces and normalize internal spaces
        final trimmedText = item.transcript
            .trim()
            .replaceAll(RegExp(r'\s+'), ' '); // Replace multiple spaces with single space

        return TranscriptItem(
          start: item.start,
          end: item.end,
          transcript: trimmedText,
          index: item.index,
        );
      }).toList();

      _state = _state.copyWith(
        transcriptItems: items,
        hasUnsavedChanges: true,
      );

      notifyListeners();
      return TranscriptEditorResult.success(
        message: 'Trimmed spaces in all segments',
        newState: _state,
      );
    } catch (e) {
      AppLogger.error('Error trimming spaces: $e');
      return TranscriptEditorResult.failure('Failed to trim spaces: $e');
    }
  }

  @override
  void dispose() {
    _videoTimeTracker?.cancel();
    _playbackController?.dispose();
    super.dispose();
  }
}