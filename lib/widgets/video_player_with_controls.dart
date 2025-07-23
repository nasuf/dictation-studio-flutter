import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../utils/video_playback_utils.dart';
import 'player_status_indicator.dart';

class VideoPlayerWithControls extends StatefulWidget {
  final YoutubePlayerController youtubeController;
  final VideoPlaybackController playbackController;
  final VoidCallback? onPlayCurrent;
  final VoidCallback? onPlayNext;
  final VoidCallback? onPlayPrevious;
  final bool canGoNext;
  final bool canGoPrevious;
  final bool isPlaying;
  final Widget? fallbackWidget;

  const VideoPlayerWithControls({
    super.key,
    required this.youtubeController,
    required this.playbackController,
    this.onPlayCurrent,
    this.onPlayNext,
    this.onPlayPrevious,
    this.canGoNext = true,
    this.canGoPrevious = true,
    this.isPlaying = false,
    this.fallbackWidget,
  });

  @override
  State<VideoPlayerWithControls> createState() => _VideoPlayerWithControlsState();
}

class _VideoPlayerWithControlsState extends State<VideoPlayerWithControls> {
  bool _showControls = true;
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onTap: () => setState(() => _showControls = !_showControls),
          child: Stack(
            children: [
              // YouTube player or fallback
              _buildVideoPlayer(),
              
              // Control overlay
              if (_showControls || _isHovering)
                _buildControlOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    // Always use the fallback widget (the YouTube player) provided by the parent
    return widget.fallbackWidget ?? Container(
      color: Colors.black,
      child: const Center(
        child: Text(
          'Video player not available',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildControlOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
          ),
        ),
        child: Column(
          children: [
            // Top controls with player status
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Player status indicator
                  PlayerStatusIndicator(
                    controller: widget.youtubeController,
                    isPlaying: widget.isPlaying,
                  ),
                  
                  // Removed eye icon as requested by user
                  const SizedBox.shrink(),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Bottom controls
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Previous sentence button
                  _buildControlButton(
                    icon: Icons.skip_previous,
                    onPressed: widget.canGoPrevious ? widget.onPlayPrevious : null,
                    tooltip: 'Previous Sentence',
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Play current sentence button
                  _buildLargePlayButton(),
                  
                  const SizedBox(width: 16),
                  
                  // Next sentence button
                  _buildControlButton(
                    icon: Icons.skip_next,
                    onPressed: widget.canGoNext ? widget.onPlayNext : null,
                    tooltip: 'Next Sentence',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargePlayButton() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: widget.onPlayCurrent,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: widget.isPlaying
                  ? const Icon(
                      Icons.pause,
                      color: Colors.white,
                      size: 32,
                      key: ValueKey('pause'),
                    )
                  : const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                      key: ValueKey('play'),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    VoidCallback? onPressed,
    String? tooltip,
    Color? backgroundColor,
  }) {
    final button = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.black54,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Icon(
            icon,
            color: onPressed != null ? Colors.white : Colors.white54,
            size: 20,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        child: button,
      );
    }

    return button;
  }
}

// Additional helper widget for video player status
class VideoPlayerStatus extends StatelessWidget {
  final YoutubePlayerController controller;
  final bool isPlaying;

  const VideoPlayerStatus({
    super.key,
    required this.controller,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPlaying ? Icons.play_circle_filled : Icons.pause_circle_filled,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            isPlaying ? 'Playing' : 'Paused',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}