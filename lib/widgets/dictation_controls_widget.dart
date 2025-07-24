import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Widget containing playback and navigation controls for dictation
class DictationControlsWidget extends StatelessWidget {
  final VoidCallback onPlayCurrent;
  final VoidCallback onPlayNext;
  final VoidCallback onPlayPrevious;
  final VoidCallback onRevealSentence;
  final bool canGoNext;
  final bool canGoPrevious;
  final bool isPlaying;
  final bool isCurrentSentenceRevealed;

  const DictationControlsWidget({
    super.key,
    required this.onPlayCurrent,
    required this.onPlayNext,
    required this.onPlayPrevious,
    required this.onRevealSentence,
    required this.canGoNext,
    required this.canGoPrevious,
    required this.isPlaying,
    required this.isCurrentSentenceRevealed,
  });

  // Check if running on mobile platform
  bool _isMobile() {
    return defaultTargetPlatform == TargetPlatform.iOS || 
           defaultTargetPlatform == TargetPlatform.android;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Main control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Previous button
                _ControlButton(
                  onPressed: canGoPrevious ? onPlayPrevious : null,
                  icon: Icons.skip_previous,
                  label: 'Previous',
                  tooltip: 'Play previous sentence (Ctrl)',
                ),
                
                // Play/Repeat current button
                _ControlButton(
                  onPressed: onPlayCurrent,
                  icon: isPlaying ? Icons.volume_up : Icons.play_arrow,
                  label: isPlaying ? 'Playing...' : 'Play',
                  tooltip: 'Play current sentence (Tab)',
                  isPrimary: true,
                ),
                
                // Next button
                _ControlButton(
                  onPressed: canGoNext ? onPlayNext : null,
                  icon: Icons.skip_next,
                  label: 'Next',
                  tooltip: 'Save and play next sentence (Enter)',
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Secondary controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onRevealSentence,
                  icon: Icon(isCurrentSentenceRevealed ? Icons.visibility_off : Icons.visibility),
                  label: Text(isCurrentSentenceRevealed ? 'Hide Text' : 'Show Text'),
                ),
              ],
            ),
            
            // Only show keyboard shortcuts on non-mobile platforms
            if (!_isMobile()) ...[
              const SizedBox(height: 12),
              _buildKeyboardShortcuts(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboardShortcuts(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Keyboard Shortcuts:',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          const _ShortcutInfo(
            shortcutKey: 'Tab',
            action: 'Repeat current sentence',
          ),
          const _ShortcutInfo(
            shortcutKey: 'Ctrl',
            action: 'Play previous sentence',
          ),
          const _ShortcutInfo(
            shortcutKey: 'Enter',
            action: 'Save and go to next sentence',
          ),
        ],
      ),
    );
  }
}

/// Individual control button widget
class _ControlButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final String? tooltip;
  final bool isPrimary;

  const _ControlButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.tooltip,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        isPrimary
            ? ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16.0),
                  shape: const CircleBorder(),
                ),
                child: Icon(icon, size: 24),
              )
            : IconButton(
                onPressed: onPressed,
                icon: Icon(icon, size: 24),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(16.0),
                ),
              ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
      ],
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}

/// Keyboard shortcut information display
class _ShortcutInfo extends StatelessWidget {
  final String shortcutKey;
  final String action;

  const _ShortcutInfo({
    required this.shortcutKey,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Text(
              shortcutKey,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              action,
              style: theme.textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Enhanced dictation controls with additional features
class EnhancedDictationControlsWidget extends StatefulWidget {
  final VoidCallback onPlayCurrent;
  final VoidCallback onPlayNext;
  final VoidCallback onPlayPrevious;
  final VoidCallback onRevealSentence;
  final VoidCallback? onShowSettings;
  final VoidCallback? onShowHelp;
  final bool canGoNext;
  final bool canGoPrevious;
  final bool isPlaying;
  final double playbackSpeed;
  final bool autoRepeat;
  final int currentIndex;
  final int totalSentences;

  const EnhancedDictationControlsWidget({
    super.key,
    required this.onPlayCurrent,
    required this.onPlayNext,
    required this.onPlayPrevious,
    required this.onRevealSentence,
    this.onShowSettings,
    this.onShowHelp,
    required this.canGoNext,
    required this.canGoPrevious,
    required this.isPlaying,
    this.playbackSpeed = 1.0,
    this.autoRepeat = false,
    required this.currentIndex,
    required this.totalSentences,
  });

  @override
  State<EnhancedDictationControlsWidget> createState() => 
      _EnhancedDictationControlsWidgetState();
}

class _EnhancedDictationControlsWidgetState 
    extends State<EnhancedDictationControlsWidget> {
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(theme),
            
            const SizedBox(height: 16),
            
            // Main controls
            DictationControlsWidget(
              onPlayCurrent: widget.onPlayCurrent,
              onPlayNext: widget.onPlayNext,
              onPlayPrevious: widget.onPlayPrevious,
              onRevealSentence: widget.onRevealSentence,
              canGoNext: widget.canGoNext,
              canGoPrevious: widget.canGoPrevious,
              isPlaying: widget.isPlaying,
              isCurrentSentenceRevealed: false, // Default to false for enhanced widget
            ),
            
            const SizedBox(height: 16),
            
            // Additional controls
            _buildAdditionalControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(ThemeData theme) {
    final progress = widget.totalSentences > 0 
        ? widget.currentIndex / widget.totalSentences 
        : 0.0;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sentence ${widget.currentIndex + 1} of ${widget.totalSentences}',
              style: theme.textTheme.labelMedium,
            ),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
        ),
      ],
    );
  }

  Widget _buildAdditionalControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (widget.onShowSettings != null)
          OutlinedButton.icon(
            onPressed: widget.onShowSettings,
            icon: const Icon(Icons.settings),
            label: const Text('Settings'),
          ),
        
        OutlinedButton.icon(
          onPressed: () => _showSpeedInfo(),
          icon: const Icon(Icons.speed),
          label: Text('${widget.playbackSpeed}x'),
        ),
        
        if (widget.onShowHelp != null)
          OutlinedButton.icon(
            onPressed: widget.onShowHelp,
            icon: const Icon(Icons.help_outline),
            label: const Text('Help'),
          ),
      ],
    );
  }

  void _showSpeedInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Playback speed: ${widget.playbackSpeed}x'
          '${widget.autoRepeat ? " (Auto-repeat enabled)" : ""}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}