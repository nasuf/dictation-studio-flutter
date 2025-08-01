import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../models/transcript_item.dart';
import '../../models/video.dart';
import '../../utils/video_playback_utils.dart';
import '../../utils/logger.dart';
import '../../widgets/admin/transcript_editor_widget.dart';
import '../../services/api_service.dart';

/// Full-screen transcript editor with integrated YouTube player
class VideoTranscriptEditorScreen extends StatefulWidget {
  final Video video;
  final String channelId;
  final List<TranscriptItem> initialTranscript;

  const VideoTranscriptEditorScreen({
    super.key,
    required this.video,
    required this.channelId,
    required this.initialTranscript,
  });

  @override
  State<VideoTranscriptEditorScreen> createState() => _VideoTranscriptEditorScreenState();
}

class _VideoTranscriptEditorScreenState extends State<VideoTranscriptEditorScreen> {
  late YoutubePlayerController _youtubeController;
  bool _isPlayerReady = false;
  bool _hasError = false;
  String? _errorMessage;
  late Video _currentVideo;
  final ApiService _apiService = ApiService();
  final bool _hasUnsavedChanges = false;
  int _modifiedSegmentsCount = 0;

  @override
  void initState() {
    super.initState();
    _currentVideo = widget.video;
    _initializeYouTubePlayer();
  }

  void _initializeYouTubePlayer() {
    try {
      final videoId = VideoPlaybackUtils.extractVideoId(widget.video.link);
      if (videoId == null) {
        throw Exception('Invalid YouTube URL: ${widget.video.link}');
      }

      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          loop: false,
          enableCaption: false, // Disable captions for cleaner editing
          captionLanguage: 'en',
        ),
      );

      _youtubeController.addListener(_onPlayerStateChanged);
    } catch (e) {
      AppLogger.error('Error initializing YouTube player: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to initialize video player: $e';
      });
    }
  }

  void _onPlayerStateChanged() {
    if (_youtubeController.value.isReady && !_isPlayerReady) {
      setState(() {
        _isPlayerReady = true;
      });
      AppLogger.info('YouTube player is ready');
    }

    if (_youtubeController.value.hasError) {
      final error = _youtubeController.value.errorCode;
      AppLogger.error('YouTube player error: $error');
      setState(() {
        _hasError = true;
        _errorMessage = 'Video player error: $error';
      });
    }
  }

  @override
  void dispose() {
    _youtubeController.removeListener(_onPlayerStateChanged);
    _youtubeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_hasError) {
      return _buildErrorScreen(theme);
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        title: const Text('Transcript Editor'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _handleBackPress(),
        ),
      ),
      body: Column(
        children: [
          // Video player section
          _buildVideoPlayerSection(theme),
          
          // Transcript editor section
          Expanded(
            child: _isPlayerReady
              ? _buildTranscriptEditor()
              : _buildLoadingView(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayerSection(ThemeData theme) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Video player
          AspectRatio(
            aspectRatio: 16 / 9,
            child: YoutubePlayer(
              controller: _youtubeController,
              showVideoProgressIndicator: true,
              progressIndicatorColor: theme.colorScheme.primary,
              progressColors: ProgressBarColors(
                playedColor: theme.colorScheme.primary,
                handleColor: theme.colorScheme.primary,
                bufferedColor: theme.colorScheme.primary.withOpacity(0.3),
                backgroundColor: theme.colorScheme.outline.withOpacity(0.3),
              ),
              onReady: () {
                AppLogger.info('YouTube player widget ready');
              },
              onEnded: (metaData) {
                AppLogger.info('Video ended: ${metaData.videoId}');
              },
            ),
          ),
          
          // Video info bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentVideo.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.video_library,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Video ID: ${_currentVideo.videoId}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Video duration display - moved next to Video ID
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        () {
                          // Try to get duration from YouTube controller first
                          if (_youtubeController.value.metaData.duration != Duration.zero) {
                            return _formatDuration(_youtubeController.value.metaData.duration);
                          }
                          // Fallback to transcript data if available
                          if (widget.initialTranscript.isNotEmpty) {
                            final lastSegment = widget.initialTranscript.last;
                            final totalSeconds = lastSegment.end.toInt();
                            final duration = Duration(seconds: totalSeconds);
                            return _formatDuration(duration);
                          }
                          // Default fallback
                          return 'Loading...';
                        }(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 9,
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Refined status toggle button
                    GestureDetector(
                      onTap: _toggleRefinedStatus,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _currentVideo.isRefined 
                            ? theme.colorScheme.surface
                            : theme.colorScheme.error.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _currentVideo.isRefined 
                              ? theme.colorScheme.outline
                              : theme.colorScheme.error,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _currentVideo.isRefined ? Icons.check_circle : Icons.edit,
                              size: 10,
                              color: _currentVideo.isRefined 
                                ? theme.colorScheme.outline
                                : theme.colorScheme.error,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _currentVideo.isRefined ? 'REFINED' : 'UNREFINED',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 9,
                                color: _currentVideo.isRefined 
                                  ? theme.colorScheme.outline
                                  : theme.colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Segment count
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${widget.initialTranscript.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 9,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Modified count (will be updated via state management later)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit,
                            size: 8,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$_modifiedSegmentsCount',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 9,
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptEditor() {
    return TranscriptEditorWithController(
      youtubeController: _youtubeController,
      videoId: widget.video.videoId,
      initialTranscript: widget.initialTranscript,
      onSave: _onSaveTranscript,
      onCancel: _onCancel,
      onModifiedCountChanged: _onModifiedCountChanged,
    );
  }

  void _onModifiedCountChanged(int count) {
    setState(() {
      _modifiedSegmentsCount = count;
    });
  }

  Widget _buildLoadingView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Initializing video player...',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we prepare the transcript editor',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(ThemeData theme) {
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        title: const Text('Transcript Editor'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 72,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                'Failed to Load Video',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'An unknown error occurred',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Error details card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Video Details:',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow('Title', widget.video.title),
                      _buildDetailRow('Video ID', widget.video.videoId),
                      _buildDetailRow('Link', widget.video.link),
                      _buildDetailRow('Channel', widget.channelId),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _retryInitialization,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _retryInitialization() {
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _isPlayerReady = false;
    });
    _initializeYouTubePlayer();
  }

  void _onSaveTranscript(List<TranscriptItem> updatedTranscript) async {
    AppLogger.info('Saving transcript with ${updatedTranscript.length} segments');
    
    try {
      // Show saving indicator
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
              Text('Saving transcript...'),
            ],
          ),
          duration: Duration(seconds: 30), // Long duration while saving
        ),
      );
      
      // Save to API
      await _apiService.saveVideoFullTranscript(
        widget.channelId,
        _currentVideo.videoId,
        updatedTranscript,
      );
      
      // Clear the saving indicator
      ScaffoldMessenger.of(context).clearSnackBars();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Transcript saved successfully'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Don't exit the page - stay in editor for continued editing
      
    } catch (e) {
      AppLogger.error('Error saving transcript: $e');
      
      // Clear the saving indicator
      ScaffoldMessenger.of(context).clearSnackBars();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save transcript: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _onCancel() {
    // Check for unsaved changes
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'Are you sure you want to leave? Any unsaved changes will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue Editing'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close editor
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
  
  void _toggleRefinedStatus() async {
    final newRefinedStatus = !_currentVideo.isRefined;
    
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                newRefinedStatus 
                  ? 'Marking video as refined...' 
                  : 'Marking video as unrefined...'
              ),
            ],
          ),
          duration: const Duration(seconds: 10),
        ),
      );
      
      // Call API to update refined status
      await _apiService.markVideoRefined(
        widget.channelId,
        _currentVideo.videoId,
        newRefinedStatus,
      );
      
      // Clear loading indicator
      ScaffoldMessenger.of(context).clearSnackBars();
      
      // Update local state
      setState(() {
        _currentVideo = Video(
          videoId: _currentVideo.videoId,
          title: _currentVideo.title,
          link: _currentVideo.link,
          visibility: _currentVideo.visibility,
          createdAt: _currentVideo.createdAt,
          updatedAt: _currentVideo.updatedAt,
          isRefined: newRefinedStatus,
          refinedAt: _currentVideo.refinedAt,
        );
      });
      
      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _currentVideo.isRefined 
              ? 'Video marked as refined' 
              : 'Video marked as unrefined'
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
      
    } catch (e) {
      AppLogger.error('Error updating refined status: $e');
      
      // Clear loading indicator
      ScaffoldMessenger.of(context).clearSnackBars();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update refined status: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _handleBackPress() {
    if (_hasUnsavedChanges) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text(
            'You have unsaved changes. Are you sure you want to leave? Your changes will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue Editing'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close editor
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Leave Without Saving'),
            ),
          ],
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }
}