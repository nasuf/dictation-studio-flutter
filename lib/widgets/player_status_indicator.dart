import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class PlayerStatusIndicator extends StatelessWidget {
  final YoutubePlayerController controller;
  final bool isPlaying;

  const PlayerStatusIndicator({
    super.key,
    required this.controller,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<YoutubePlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(value).withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getStatusIcon(value),
                size: 12,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                _getStatusText(value),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(YoutubePlayerValue value) {
    if (!value.isReady) {
      return Colors.orange;
    }
    
    switch (value.playerState) {
      case PlayerState.playing:
        return Colors.green;
      case PlayerState.paused:
        return Colors.blue;
      case PlayerState.buffering:
        return Colors.amber;
      case PlayerState.ended:
        return Colors.grey;
      case PlayerState.cued:
        return Colors.teal;
      case PlayerState.unStarted:
        return Colors.blue; // Ready to play, not an error
      default:
        return Colors.blue; // Default to ready state, not error
    }
  }

  IconData _getStatusIcon(YoutubePlayerValue value) {
    if (!value.isReady) {
      return Icons.hourglass_empty;
    }
    
    switch (value.playerState) {
      case PlayerState.playing:
        return Icons.play_circle_filled;
      case PlayerState.paused:
        return Icons.pause_circle_filled;
      case PlayerState.buffering:
        return Icons.sync;
      case PlayerState.ended:
        return Icons.stop_circle;
      case PlayerState.cued:
        return Icons.queue_play_next;
      case PlayerState.unStarted:
        return Icons.play_circle_outline; // Ready to play
      default:
        return Icons.play_circle_outline; // Default to ready state
    }
  }

  String _getStatusText(YoutubePlayerValue value) {
    if (!value.isReady) {
      return 'Loading...';
    }
    
    switch (value.playerState) {
      case PlayerState.playing:
        return 'Playing';
      case PlayerState.paused:
        return 'Paused';
      case PlayerState.buffering:
        return 'Buffering';
      case PlayerState.ended:
        return 'Ended';
      case PlayerState.cued:
        return 'Cued';
      case PlayerState.unStarted:
        return 'Ready';
      default:
        return 'Ready'; // Default to ready state
    }
  }
}