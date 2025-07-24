import 'package:flutter/material.dart';

/// Simple progress bar widget with clean design
class DictationProgressBar extends StatelessWidget {
  final double completion; // 0-100
  final double accuracy; // 0-100
  final int currentIndex;
  final int totalSentences;
  final int timeSpent; // in seconds

  const DictationProgressBar({
    super.key,
    required this.completion,
    required this.accuracy,
    required this.currentIndex,
    required this.totalSentences,
    required this.timeSpent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Single row with key metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Progress
              _buildMetricItem(
                context,
                '${completion.toStringAsFixed(0)}%',
                'Progress',
                _getProgressColor(completion),
                Icons.trending_up,
              ),
              // Accuracy
              _buildMetricItem(
                context,
                '${accuracy.toStringAsFixed(0)}%',
                'Accuracy',
                _getAccuracyColor(accuracy),
                Icons.check_circle_outline,
              ),
              // Time
              _buildMetricItem(
                context,
                _formatTime(timeSpent),
                'Time',
                theme.colorScheme.primary,
                Icons.schedule,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Single progress indicator
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (completion / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: _getProgressColor(completion),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Sentence info
          Text(
            'Sentence ${currentIndex + 1} of $totalSentences',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    BuildContext context,
    String value,
    String label,
    Color color,
    IconData icon,
  ) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }


  Color _getProgressColor(double progress) {
    if (progress >= 90) return Colors.green;
    if (progress >= 50) return Colors.blue;
    return Colors.orange;
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return Colors.green;
    if (accuracy >= 70) return Colors.orange;
    return Colors.red;
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m ${secs}s';
    }
  }
}

/// Compact progress widget for dictation
class ProgressDisplayWidget extends StatelessWidget {
  final double completion; // 0-100
  final double accuracy; // 0-100
  final int currentIndex;
  final int totalSentences;
  final int timeSpent; // in seconds

  const ProgressDisplayWidget({
    super.key,
    required this.completion,
    required this.accuracy,
    required this.currentIndex,
    required this.totalSentences,
    required this.timeSpent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Circular progress
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 4.0,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                CircularProgressIndicator(
                  value: completion / 100,
                  strokeWidth: 4.0,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgressColor(completion),
                  ),
                ),
                Center(
                  child: Text(
                    '${completion.toStringAsFixed(0)}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accuracy: ${accuracy.toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _getAccuracyColor(accuracy),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sentence ${currentIndex + 1}/$totalSentences',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          // Time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(Icons.schedule, size: 16, color: theme.colorScheme.primary),
              const SizedBox(height: 2),
              Text(
                _formatTime(timeSpent),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 90) return Colors.green;
    if (progress >= 50) return Colors.blue;
    return Colors.orange;
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return Colors.green;
    if (accuracy >= 70) return Colors.orange;
    return Colors.red;
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m ${secs}s';
    }
  }
}

/// Enhanced progress display with additional statistics only
class DetailedProgressDisplayWidget extends StatelessWidget {
  final double completion;
  final double accuracy;
  final int currentIndex;
  final int totalSentences;
  final int timeSpent;
  final int correctWords;
  final int totalWords;
  final double averageWordsPerMinute;

  const DetailedProgressDisplayWidget({
    super.key,
    required this.completion,
    required this.accuracy,
    required this.currentIndex,
    required this.totalSentences,
    required this.timeSpent,
    required this.correctWords,
    required this.totalWords,
    this.averageWordsPerMinute = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Additional Statistics',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            // Only show additional stats, no duplicate progress info
            _StatRow(
              icon: Icons.spellcheck,
              label: 'Words Correct',
              value: '$correctWords / $totalWords',
              color: _getAccuracyColor(accuracy),
            ),

            if (averageWordsPerMinute > 0)
              _StatRow(
                icon: Icons.speed,
                label: 'Typing Speed',
                value: '${averageWordsPerMinute.toStringAsFixed(1)} WPM',
                color: theme.colorScheme.primary,
              ),

            if (timeSpent > 0)
              _StatRow(
                icon: Icons.timeline,
                label: 'Completion Rate',
                value: '${(completion / (timeSpent / 60)).toStringAsFixed(1)}% per min',
                color: theme.colorScheme.secondary,
              ),
          ],
        ),
      ),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return Colors.green;
    if (accuracy >= 70) return Colors.orange;
    return Colors.red;
  }
}

/// Individual statistic row
class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact progress indicator for minimal space
class CompactProgressWidget extends StatelessWidget {
  final double completion;
  final double accuracy;
  final bool showPercentage;

  const CompactProgressWidget({
    super.key,
    required this.completion,
    required this.accuracy,
    this.showPercentage = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Completion indicator
        SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            children: [
              CircularProgressIndicator(
                value: completion / 100,
                strokeWidth: 3.0,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getProgressColor(completion),
                ),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
              if (showPercentage)
                Center(
                  child: Text(
                    '${completion.toStringAsFixed(0)}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Accuracy chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: _getAccuracyColor(accuracy).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: _getAccuracyColor(accuracy).withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.track_changes,
                size: 12,
                color: _getAccuracyColor(accuracy),
              ),
              const SizedBox(width: 4),
              Text(
                '${accuracy.toStringAsFixed(0)}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _getAccuracyColor(accuracy),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 90) return Colors.green;
    if (progress >= 50) return Colors.blue;
    return Colors.orange;
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return Colors.green;
    if (accuracy >= 70) return Colors.orange;
    return Colors.red;
  }
}
