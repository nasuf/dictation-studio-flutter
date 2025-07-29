import 'transcript_item.dart';

/// State for transcript editing functionality
class TranscriptEditorState {
  final List<TranscriptItem> transcriptItems;
  final Map<int, TranscriptItem> originalItems; // For undo functionality
  final Map<int, bool> userModifiedTimes; // Track which times are user-modified
  final List<TranscriptEditorState> history; // For undo/redo
  final int? currentEditingIndex;
  final int? currentPlayingIndex;
  final Set<int> selectedSegments; // For multi-selection
  final bool isSelectionMode; // Track if we're in selection mode
  final bool isVideoPlaying;
  final double currentVideoTime;
  final double playbackSpeed;
  final bool hasUnsavedChanges;
  final String? errorMessage;

  const TranscriptEditorState({
    this.transcriptItems = const [],
    this.originalItems = const {},
    this.userModifiedTimes = const {},
    this.history = const [],
    this.currentEditingIndex,
    this.currentPlayingIndex,
    this.selectedSegments = const {},
    this.isSelectionMode = false,
    this.isVideoPlaying = false,
    this.currentVideoTime = 0.0,
    this.playbackSpeed = 1.0,
    this.hasUnsavedChanges = false,
    this.errorMessage,
  });

  TranscriptEditorState copyWith({
    List<TranscriptItem>? transcriptItems,
    Map<int, TranscriptItem>? originalItems,
    Map<int, bool>? userModifiedTimes,
    List<TranscriptEditorState>? history,
    int? currentEditingIndex,
    int? currentPlayingIndex,
    Set<int>? selectedSegments,
    bool? isSelectionMode,
    bool? isVideoPlaying,
    double? currentVideoTime,
    double? playbackSpeed,
    bool? hasUnsavedChanges,
    String? errorMessage,
  }) {
    return TranscriptEditorState(
      transcriptItems: transcriptItems ?? this.transcriptItems,
      originalItems: originalItems ?? this.originalItems,
      userModifiedTimes: userModifiedTimes ?? this.userModifiedTimes,
      history: history ?? this.history,
      currentEditingIndex: currentEditingIndex ?? this.currentEditingIndex,
      currentPlayingIndex: currentPlayingIndex ?? this.currentPlayingIndex,
      selectedSegments: selectedSegments ?? this.selectedSegments,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      isVideoPlaying: isVideoPlaying ?? this.isVideoPlaying,
      currentVideoTime: currentVideoTime ?? this.currentVideoTime,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Clear the current editing index
  TranscriptEditorState clearCurrentEditingIndex() {
    return copyWith(currentEditingIndex: -1);
  }

  /// Clear the current playing index
  TranscriptEditorState clearCurrentPlayingIndex() {
    return copyWith(currentPlayingIndex: -1);
  }

  /// Clear error message
  TranscriptEditorState clearError() {
    return copyWith(errorMessage: '');
  }

  /// Check if a specific item has user-modified times
  bool hasUserModifiedTimes(int index) {
    return userModifiedTimes[index] == true;
  }

  /// Get the original item for undo functionality
  TranscriptItem? getOriginalItem(int index) {
    return originalItems[index];
  }

  /// Check if there are any user modifications
  bool get hasAnyUserModifications {
    return userModifiedTimes.values.any((modified) => modified);
  }

  /// Get the current editing item
  TranscriptItem? get currentEditingItem {
    if (currentEditingIndex == null || 
        currentEditingIndex! < 0 || 
        currentEditingIndex! >= transcriptItems.length) {
      return null;
    }
    return transcriptItems[currentEditingIndex!];
  }

  /// Get the current playing item
  TranscriptItem? get currentPlayingItem {
    if (currentPlayingIndex == null || 
        currentPlayingIndex! < 0 || 
        currentPlayingIndex! >= transcriptItems.length) {
      return null;
    }
    return transcriptItems[currentPlayingIndex!];
  }

  /// Check if we can undo
  bool get canUndo => history.isNotEmpty;

  /// Get total transcript duration
  double get totalDuration {
    if (transcriptItems.isEmpty) return 0.0;
    return transcriptItems.last.end;
  }

  /// Get total number of segments
  int get totalSegments => transcriptItems.length;

  /// Get total number of user-modified segments
  int get userModifiedSegments => userModifiedTimes.values.where((m) => m).length;

  /// Check if a segment is selected
  bool isSegmentSelected(int index) => selectedSegments.contains(index);

  /// Get selected segments count
  int get selectedSegmentsCount => selectedSegments.length;

  /// Check if any segments are selected
  bool get hasSelectedSegments => selectedSegments.isNotEmpty;

  /// Get selected segments as a sorted list
  List<int> get selectedSegmentsList {
    final list = selectedSegments.toList();
    list.sort();
    return list;
  }

  /// Check if selected segments are consecutive
  bool get areSelectedSegmentsConsecutive {
    if (selectedSegments.length <= 1) return true;
    
    final sortedList = selectedSegmentsList;
    for (int i = 1; i < sortedList.length; i++) {
      if (sortedList[i] != sortedList[i - 1] + 1) {
        return false;
      }
    }
    return true;
  }

  /// Clear selection
  TranscriptEditorState clearSelection() {
    return copyWith(
      selectedSegments: const <int>{},
      isSelectionMode: false,
    );
  }
}

/// Actions for transcript editing
enum TranscriptEditorAction {
  loadTranscript,
  editText,
  recordStartTime,
  recordEndTime,
  undoTimeChanges,
  playSegment,
  stopPlayback,
  seekToTime,
  addSegment,
  deleteSegment,
  mergeSegments,
  splitSegment,
  saveChanges,
  discardChanges,
  setPlaybackSpeed,
  autoMergeShortSegments,
  applyTextFilter,
  exportTranscript,
}

/// Result of a transcript editor operation
class TranscriptEditorResult {
  final bool success;
  final String? message;
  final TranscriptEditorState? newState;
  final dynamic data;

  const TranscriptEditorResult({
    required this.success,
    this.message,
    this.newState,
    this.data,
  });

  factory TranscriptEditorResult.success({
    String? message,
    TranscriptEditorState? newState,
    dynamic data,
  }) {
    return TranscriptEditorResult(
      success: true,
      message: message,
      newState: newState,
      data: data,
    );
  }

  factory TranscriptEditorResult.failure(String message) {
    return TranscriptEditorResult(
      success: false,
      message: message,
    );
  }
}