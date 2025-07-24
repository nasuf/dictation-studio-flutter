import 'package:flutter/material.dart';
import '../models/comparison_result.dart';

class EnhancedComparisonTextWidget extends StatelessWidget {
  final ComparisonResult comparison;
  final bool showOriginal;
  final bool showUserInput;

  const EnhancedComparisonTextWidget({
    super.key,
    required this.comparison,
    this.showOriginal = true,
    this.showUserInput = true,
  });

  @override
  Widget build(BuildContext context) {
    if (comparison.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showOriginal) ...[
          _buildSectionTitle(context, 'Original Text', Icons.text_fields),
          const SizedBox(height: 8),
          _buildOriginalText(context),
          const SizedBox(height: 16),
        ],
        if (showUserInput) ...[
          _buildSectionTitle(context, 'Your Input', Icons.edit),
          const SizedBox(height: 8),
          _buildUserInputText(context),
          const SizedBox(height: 16),
        ],
        _buildLegend(context),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildOriginalText(BuildContext context) {
    final theme = Theme.of(context);
    
    // Create a list combining matched and missed words in original order  
    final allWords = <ComparisonWord>[];
    
    // Add all words from user input
    allWords.addAll(comparison.words);
    
    // Add missed words at their original positions
    for (final missedWord in comparison.missedWords) {
      allWords.add(missedWord);
    }
    
    // Sort by original index to maintain text order
    allWords.sort((a, b) {
      if (a.originalIndex == -1) return 1; // Extra words go to end
      if (b.originalIndex == -1) return -1;
      return a.originalIndex.compareTo(b.originalIndex);
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: allWords
            .where((word) => word.type != ComparisonType.extra)
            .map((word) => _buildWordChip(context, word, isOriginal: true))
            .toList(),
      ),
    );
  }

  Widget _buildUserInputText(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: comparison.words
            .map((word) => _buildWordChip(context, word, isOriginal: false))
            .toList(),
      ),
    );
  }

  Widget _buildWordChip(
    BuildContext context, 
    ComparisonWord word,
    {required bool isOriginal}
  ) {
    final theme = Theme.of(context);
    
    // For original text, show missing words differently
    if (isOriginal && word.type == ComparisonType.missing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.grey.withOpacity(0.5),
            style: BorderStyle.solid,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.remove_circle_outline,
              size: 12,
              color: Colors.grey.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              word.text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: word.backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: word.textColor.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (word.icon != null) ...[
            Icon(
              word.icon,
              size: 12,
              color: word.textColor,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            word.text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: word.textColor,
              fontWeight: word.type == ComparisonType.correct 
                  ? FontWeight.normal 
                  : FontWeight.w500,
            ),
          ),
          if (word.type == ComparisonType.incorrect && word.originalWord != null) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward,
              size: 10,
              color: word.textColor.withOpacity(0.7),
            ),
            const SizedBox(width: 4),
            Text(
              word.originalWord!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Legend:',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _LegendItem(
                icon: Icons.check_circle_outline,
                color: Colors.green,
                label: 'Correct',
              ),
              _LegendItem(
                icon: Icons.edit_outlined,
                color: Colors.orange,
                label: 'Incorrect',
              ),
              _LegendItem(
                icon: Icons.remove_circle_outline,
                color: Colors.grey,
                label: 'Missing',
              ),
              _LegendItem(
                icon: Icons.add_circle_outline,
                color: Colors.red,
                label: 'Extra',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _LegendItem({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Colors.grey[700],
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}