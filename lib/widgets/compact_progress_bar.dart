import 'package:flutter/material.dart';
import '../generated/app_localizations.dart';

class CompactProgressBar extends StatelessWidget {
  final double completion;
  final double accuracy;
  final int timeSpent;

  const CompactProgressBar({
    super.key,
    required this.completion,
    required this.accuracy,
    required this.timeSpent,
  });

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return Colors.green;
    if (accuracy >= 80) return Colors.lightGreen;
    if (accuracy >= 70) return Colors.orange;
    return Colors.red;
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progressColor = theme.colorScheme.primary;
    final accuracyColor = _getAccuracyColor(accuracy);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: isDark ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
        ) : null,
        color: isDark ? null : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(
          color: const Color(0xFF3A3A3F).withValues(alpha: 0.4),
          width: 0.5,
        ) : Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: isDark ? [
          const BoxShadow(
            color: Color(0xFF000000),
            blurRadius: 8,
            offset: Offset(0, 2),
            spreadRadius: 0,
          ),
        ] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Progress percentage
            Expanded(
              child: _buildQuickStat(
                context,
                '${completion.toStringAsFixed(0)}%', 
                AppLocalizations.of(context)!.progress,
                progressColor,
                Icons.trending_up_outlined,
                isDark,
              ),
            ),
            // Accuracy percentage  
            Expanded(
              child: _buildQuickStat(
                context,
                '${accuracy.toStringAsFixed(0)}%',
                AppLocalizations.of(context)!.accuracy, 
                accuracyColor,
                Icons.gps_fixed_outlined,
                isDark,
              ),
            ),
            // Time spent
            Expanded(
              child: _buildQuickStat(
                context,
                _formatTime(timeSpent),
                AppLocalizations.of(context)!.time,
                isDark ? const Color(0xFF8E8E93) : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                Icons.access_time_outlined,
                isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Quick stat display for compact view
  Widget _buildQuickStat(
    BuildContext context,
    String value,
    String label,
    Color color,
    IconData icon,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: isDark ? const Color(0xFFE8E8EA) : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? const Color(0xFF8E8E93) : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}