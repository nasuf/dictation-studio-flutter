import 'package:flutter/material.dart';
import '../generated/app_localizations.dart';

class CompactProgressBar extends StatefulWidget {
  final double completion;
  final double accuracy;
  final int timeSpent;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  const CompactProgressBar({
    super.key,
    required this.completion,
    required this.accuracy,
    required this.timeSpent,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  @override
  State<CompactProgressBar> createState() => _CompactProgressBarState();
}

class _CompactProgressBarState extends State<CompactProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(CompactProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

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
    final progressColor = theme.colorScheme.primary;
    final accuracyColor = _getAccuracyColor(widget.accuracy);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        onTap: widget.onToggleExpanded,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Compact progress bar - always visible
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Single clean progress bar without any text labels
                  _buildCleanProgressBar(theme, progressColor, accuracyColor),
                  const SizedBox(height: 8),
                  // Only expand/collapse indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.isExpanded 
                            ? AppLocalizations.of(context)!.hideComparison 
                            : AppLocalizations.of(context)!.showComparison,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Expanded details section
            AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, child) {
                return ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: _expandAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    // Detailed stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          context,
                          AppLocalizations.of(context)!.progress,
                          '${widget.completion.toStringAsFixed(1)}%',
                          progressColor,
                          Icons.trending_up,
                        ),
                        _buildStatItem(
                          context,
                          AppLocalizations.of(context)!.accuracy,
                          '${widget.accuracy.toStringAsFixed(1)}%',
                          accuracyColor,
                          Icons.gps_fixed,
                        ),
                        _buildStatItem(
                          context,
                          AppLocalizations.of(context)!.time,
                          _formatTime(widget.timeSpent),
                          theme.colorScheme.onSurface.withOpacity(0.7),
                          Icons.access_time,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Legend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem(
                          AppLocalizations.of(context)!.progress,
                          progressColor.withOpacity(0.3),
                        ),
                        const SizedBox(width: 16),
                        _buildLegendItem(
                          AppLocalizations.of(context)!.accuracy,
                          accuracyColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build clean progress bar without any text labels - no duplication
  Widget _buildCleanProgressBar(ThemeData theme, Color progressColor, Color accuracyColor) {
    // Use different background colors for light and dark modes
    final backgroundColor = theme.brightness == Brightness.dark 
        ? const Color(0xFF374151) // Dark gray for dark mode
        : const Color(0xFFE5E7EB); // Light gray for light mode
    
    return Container(
          height: 24, // Similar to React version h-6 (24px)
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12), // Rounded full
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Completion progress bar (blue layer)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  width: double.infinity,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: widget.completion / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: progressColor, // Blue color for completion
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                // Accuracy progress bar (green layer with opacity, overlaid)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  width: double.infinity,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: widget.accuracy / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: accuracyColor.withOpacity(0.7), // Green with opacity
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: color,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}