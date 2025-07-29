import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../controllers/transcript_editor_controller.dart';
import '../../models/transcript_item.dart';
import '../../utils/video_playback_utils.dart';
import '../../services/api_service.dart';
import '../../utils/logger.dart';

/// Wrapper widget that connects YouTube controller to transcript editor
class TranscriptEditorWithController extends StatefulWidget {
  final YoutubePlayerController youtubeController;
  final String videoId;
  final List<TranscriptItem> initialTranscript;
  final Function(List<TranscriptItem>)? onSave;
  final VoidCallback? onCancel;

  const TranscriptEditorWithController({
    super.key,
    required this.youtubeController,
    required this.videoId,
    required this.initialTranscript,
    this.onSave,
    this.onCancel,
  });

  @override
  State<TranscriptEditorWithController> createState() =>
      _TranscriptEditorWithControllerState();
}

class _TranscriptEditorWithControllerState
    extends State<TranscriptEditorWithController> {
  late TranscriptEditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TranscriptEditorController();
    _controller.initialize(widget.youtubeController);
    _loadTranscript();
  }

  Future<void> _loadTranscript() async {
    await _controller.loadTranscript(widget.initialTranscript);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TranscriptEditorController>.value(
      value: _controller,
      child: TranscriptEditorWidget(
        videoId: widget.videoId,
        initialTranscript: widget.initialTranscript,
        onSave: widget.onSave,
        onCancel: widget.onCancel,
      ),
    );
  }
}

/// Main transcript editor widget with video player and editing controls
class TranscriptEditorWidget extends StatefulWidget {
  final String videoId;
  final List<TranscriptItem> initialTranscript;
  final Function(List<TranscriptItem>)? onSave;
  final VoidCallback? onCancel;

  const TranscriptEditorWidget({
    super.key,
    required this.videoId,
    required this.initialTranscript,
    this.onSave,
    this.onCancel,
  });

  @override
  State<TranscriptEditorWidget> createState() => _TranscriptEditorWidgetState();
}

class _TranscriptEditorWidgetState extends State<TranscriptEditorWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<TranscriptEditorController>(
      builder: (context, controller, child) {
        if (controller.state.errorMessage != null) {
          return _buildErrorView(theme, controller.state.errorMessage!);
        }

        return Column(
          children: [
            _buildVideoControls(theme, controller),
            _buildTranscriptHeader(theme, controller),
            Expanded(child: _buildTranscriptList(theme, controller)),
          ],
        );
      },
    );
  }

  Widget _buildVideoControls(
    ThemeData theme,
    TranscriptEditorController controller,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Current time - compact display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              VideoPlaybackUtils.formatTime(controller.state.currentVideoTime),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Stop button - compact
          SizedBox(
            height: 32,
            child: ElevatedButton.icon(
              onPressed: controller.state.isVideoPlaying
                  ? () => controller.stopPlayback()
                  : null,
              icon: Icon(
                controller.state.isVideoPlaying ? Icons.stop : Icons.play_arrow,
                size: 16,
              ),
              label: Text(
                controller.state.isVideoPlaying ? 'Stop' : 'Stopped',
                style: const TextStyle(fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: controller.state.isVideoPlaying
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
              ),
            ),
          ),

          const Spacer(),

          // Playback speed - compact dropdown
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Speed:', style: theme.textTheme.bodySmall),
              const SizedBox(width: 6),
              DropdownButton<double>(
                value: controller.state.playbackSpeed,
                isDense: true,
                underline: Container(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                items: const [
                  DropdownMenuItem(value: 0.25, child: Text('0.25x')),
                  DropdownMenuItem(value: 0.5, child: Text('0.5x')),
                  DropdownMenuItem(value: 0.75, child: Text('0.75x')),
                  DropdownMenuItem(value: 1.0, child: Text('1.0x')),
                  DropdownMenuItem(value: 1.25, child: Text('1.25x')),
                  DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                  DropdownMenuItem(value: 2.0, child: Text('2.0x')),
                ],
                onChanged: (speed) {
                  if (speed != null) {
                    controller.setPlaybackSpeed(speed);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptHeader(
    ThemeData theme,
    TranscriptEditorController controller,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (controller.state.userModifiedSegments > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${controller.state.userModifiedSegments} modified',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          const Spacer(),

          // Selection mode and actions
          if (controller.state.isSelectionMode) ...[
            // Selected segments info
            if (controller.state.hasSelectedSegments) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${controller.state.selectedSegmentsCount} selected',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Merge button (only show if segments are consecutive)
              if (controller.state.areSelectedSegmentsConsecutive &&
                  controller.state.selectedSegmentsCount > 1)
                IconButton(
                  onPressed: () => _mergeSelectedSegments(controller),
                  icon: const Icon(Icons.merge_type),
                  tooltip: 'Merge selected segments',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    foregroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              const SizedBox(width: 4),
            ],

            // Clear selection button
            IconButton(
              onPressed: controller.clearSelection,
              icon: const Icon(Icons.close),
              tooltip: 'Clear selection',
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.error.withOpacity(0.1),
                foregroundColor: theme.colorScheme.error,
                padding: const EdgeInsets.all(8),
              ),
            ),
            const SizedBox(width: 8),

            // Restore, Cancel and Save buttons in selection mode - smaller size
            SizedBox(
              height: 32,
              child: OutlinedButton(
                onPressed: () => _restoreOriginalTranscript(controller),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                  backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
                  foregroundColor: theme.colorScheme.secondary,
                ),
                child: const Text('Restore'),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 32,
              child: OutlinedButton(
                onPressed: widget.onCancel,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 6),
            Consumer<TranscriptEditorController>(
              builder: (context, controller, child) {
                return SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: controller.state.hasUnsavedChanges
                        ? () => _saveTranscript(controller)
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text('Save'),
                  ),
                );
              },
            ),
          ] else ...[
            // Trim spaces button
            IconButton(
              onPressed: () => _trimAllSpaces(controller),
              icon: const Icon(Icons.space_bar),
              tooltip: 'Trim all spaces',
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
                foregroundColor: theme.colorScheme.secondary,
                padding: const EdgeInsets.all(8),
              ),
            ),
            const SizedBox(width: 4),

            // Selection mode toggle button
            IconButton(
              onPressed: controller.toggleSelectionMode,
              icon: const Icon(Icons.checklist),
              tooltip: 'Selection mode',
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.all(8),
              ),
            ),
            const SizedBox(width: 8),

            // Restore, Cancel and Save buttons in normal mode - smaller size
            SizedBox(
              height: 32,
              child: OutlinedButton(
                onPressed: () => _restoreOriginalTranscript(controller),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                  backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
                  foregroundColor: theme.colorScheme.secondary,
                ),
                child: const Text('Restore'),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 32,
              child: OutlinedButton(
                onPressed: widget.onCancel,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 6),
            Consumer<TranscriptEditorController>(
              builder: (context, controller, child) {
                return SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: controller.state.hasUnsavedChanges
                        ? () => _saveTranscript(controller)
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text('Save'),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTranscriptList(
    ThemeData theme,
    TranscriptEditorController controller,
  ) {
    if (controller.state.transcriptItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.subtitles_off,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No transcript segments',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: controller.state.transcriptItems.length,
      itemBuilder: (context, index) {
        return _buildTranscriptSegmentCard(
          theme,
          controller,
          controller.state.transcriptItems[index],
          index,
        );
      },
    );
  }

  Widget _buildTranscriptSegmentCard(
    ThemeData theme,
    TranscriptEditorController controller,
    TranscriptItem item,
    int index,
  ) {
    final isEditing = controller.state.currentEditingIndex == index;
    final isPlaying = controller.state.currentPlayingIndex == index;
    final hasUserModifications = controller.state.hasUserModifiedTimes(index);
    final isSelected = controller.state.isSegmentSelected(index);
    final isSelectionMode = controller.state.isSelectionMode;

    return GestureDetector(
      onTap: isSelectionMode
          ? () => controller.toggleSegmentSelection(index)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : null,
        ),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: isPlaying ? 4 : 1,
          color: _getSegmentCardColor(theme, isPlaying, isSelected),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with segment info and actions
                Row(
                  children: [
                    // Selection checkbox (only in selection mode)
                    if (isSelectionMode) ...[
                      Checkbox(
                        value: isSelected,
                        onChanged: (_) =>
                            controller.toggleSegmentSelection(index),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 8),
                    ],

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (hasUserModifications)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Modified',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const Spacer(),
                    _buildSegmentActions(theme, controller, index),
                  ],
                ),
                const SizedBox(height: 12),

                // Time controls
                _buildTimeControls(theme, controller, item, index),
                const SizedBox(height: 12),

                // Transcript text
                _buildTranscriptText(theme, controller, item, index, isEditing),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentActions(
    ThemeData theme,
    TranscriptEditorController controller,
    int index,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play/Stop segment button
        IconButton(
          onPressed: () {
            if (controller.state.currentPlayingIndex == index && controller.state.isVideoPlaying) {
              // Currently playing this segment, so stop it
              controller.stopPlayback();
            } else {
              // Not playing or playing different segment, so play this segment
              controller.playSegment(index);
            }
          },
          icon: Icon(
            (controller.state.currentPlayingIndex == index && controller.state.isVideoPlaying)
                ? Icons.stop
                : Icons.play_arrow,
          ),
          tooltip: (controller.state.currentPlayingIndex == index && controller.state.isVideoPlaying)
              ? 'Stop Segment'
              : 'Play Segment',
          style: IconButton.styleFrom(
            backgroundColor: (controller.state.currentPlayingIndex == index && controller.state.isVideoPlaying)
                ? theme.colorScheme.error.withOpacity(0.1)
                : theme.colorScheme.primary.withOpacity(0.1),
            foregroundColor: (controller.state.currentPlayingIndex == index && controller.state.isVideoPlaying)
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 4),

        // Seek to start button
        IconButton(
          onPressed: () {
            final item = controller.state.transcriptItems[index];
            controller.seekToTime(item.start);
          },
          icon: const Icon(Icons.skip_next),
          tooltip: 'Go to Start',
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
            foregroundColor: theme.colorScheme.secondary,
          ),
        ),
        const SizedBox(width: 4),

        // More actions menu
        PopupMenuButton<String>(
          onSelected: (action) =>
              _handleSegmentAction(controller, index, action),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit Text'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'add_after',
              child: Row(
                children: [
                  Icon(Icons.add),
                  SizedBox(width: 8),
                  Text('Add Segment After'),
                ],
              ),
            ),
            if (controller.state.hasUserModifiedTimes(index))
              const PopupMenuItem(
                value: 'undo_times',
                child: Row(
                  children: [
                    Icon(Icons.undo),
                    SizedBox(width: 8),
                    Text('Undo Time Changes'),
                  ],
                ),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Text(
                    'Delete',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeControls(
    ThemeData theme,
    TranscriptEditorController controller,
    TranscriptItem item,
    int index,
  ) {
    return Row(
      children: [
        // Start time
        Expanded(
          child: _buildTimeControl(
            theme,
            'Start',
            item.start,
            () => controller.recordStartTime(index),
            controller.state.hasUserModifiedTimes(index),
          ),
        ),
        const SizedBox(width: 12),

        // End time
        Expanded(
          child: _buildTimeControl(
            theme,
            'End',
            item.end,
            () => controller.recordEndTime(index),
            controller.state.hasUserModifiedTimes(index),
          ),
        ),
        const SizedBox(width: 12),

        // Duration
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            VideoPlaybackUtils.formatTime(item.duration),
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeControl(
    ThemeData theme,
    String label,
    double time,
    VoidCallback onRecord,
    bool isModified,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isModified
            ? theme.colorScheme.secondary.withOpacity(0.1)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: isModified
            ? Border.all(color: theme.colorScheme.secondary.withOpacity(0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isModified ? theme.colorScheme.secondary : null,
                ),
              ),
              GestureDetector(
                onTap: onRecord,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.radio_button_checked,
                    size: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            VideoPlaybackUtils.formatTime(time),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptText(
    ThemeData theme,
    TranscriptEditorController controller,
    TranscriptItem item,
    int index,
    bool isEditing,
  ) {
    if (isEditing) {
      return TextFormField(
        initialValue: item.transcript,
        maxLines: 3,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Transcript Text',
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
        ),
        onFieldSubmitted: (value) {
          controller.editTranscriptText(index, value);
        },
        onEditingComplete: () {
          controller.stopEditing();
        },
      );
    }

    return GestureDetector(
      onDoubleTap: () => controller.startEditing(index),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
        ),
        child: Text(
          item.transcript.isEmpty ? 'Double tap to edit...' : item.transcript,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: item.transcript.isEmpty
                ? theme.colorScheme.onSurfaceVariant
                : null,
            fontStyle: item.transcript.isEmpty ? FontStyle.italic : null,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'Error',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Consumer<TranscriptEditorController>(
            builder: (context, controller, child) {
              return ElevatedButton(
                onPressed: () => controller.clearError(),
                child: const Text('Dismiss'),
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleSegmentAction(
    TranscriptEditorController controller,
    int index,
    String action,
  ) {
    switch (action) {
      case 'edit':
        controller.startEditing(index);
        break;
      case 'add_after':
        controller.addSegment(afterIndex: index);
        break;
      case 'undo_times':
        controller.undoTimeChanges(index);
        break;
      case 'delete':
        _confirmDelete(controller, index);
        break;
    }
  }

  void _confirmDelete(TranscriptEditorController controller, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Segment'),
        content: Text('Are you sure you want to delete segment #${index + 1}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              controller.deleteSegment(index);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _saveTranscript(TranscriptEditorController controller) {
    if (widget.onSave != null) {
      widget.onSave!(controller.state.transcriptItems);
    }
  }

  /// Get appropriate card color based on state
  Color _getSegmentCardColor(ThemeData theme, bool isPlaying, bool isSelected) {
    if (isPlaying) {
      return theme.colorScheme.primaryContainer.withOpacity(0.5);
    } else if (isSelected) {
      return theme.colorScheme.primary.withOpacity(0.1);
    } else {
      return theme.colorScheme.surface;
    }
  }

  /// Handle merge selected segments action
  void _mergeSelectedSegments(TranscriptEditorController controller) async {
    final result = await controller.mergeSelectedSegments();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Merge operation completed'),
          backgroundColor: result.success
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// Handle trim all spaces action
  void _trimAllSpaces(TranscriptEditorController controller) async {
    final result = await controller.trimAllSpaces();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Trim spaces operation completed'),
          backgroundColor: result.success
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// Handle restore original transcript action
  void _restoreOriginalTranscript(TranscriptEditorController controller) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Original Transcript'),
        content: const Text(
          'Are you sure you want to restore the original transcript? All current changes will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Restoring original transcript...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      // Call restore API
      final result = await ApiService().restoreOriginalTranscript(widget.videoId);
      
      AppLogger.info('Restore transcript API response: $result');

      // Clear loading indicator
      ScaffoldMessenger.of(context).clearSnackBars();

      // Parse and reload transcript data
      if (result.containsKey('transcript') && result['transcript'] is List) {
        final transcriptList = result['transcript'] as List;
        final restoredItems = <TranscriptItem>[];
        
        for (int i = 0; i < transcriptList.length; i++) {
          final item = transcriptList[i];
          if (item is Map<String, dynamic>) {
            final transcriptItem = TranscriptItem(
              start: (item['start'] as num?)?.toDouble() ?? 0.0,
              end: (item['end'] as num?)?.toDouble() ?? 1.0,
              transcript: (item['transcript'] ?? '').toString().trim(),
              index: i,
            );
            restoredItems.add(transcriptItem);
          }
        }

        // Reload the transcript in the controller
        await controller.loadTranscript(restoredItems);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Original transcript restored successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        throw Exception('Invalid response format from restore API');
      }

    } catch (e) {
      AppLogger.error('Error restoring original transcript: $e');
      
      // Clear loading indicator
      ScaffoldMessenger.of(context).clearSnackBars();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore original transcript: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
