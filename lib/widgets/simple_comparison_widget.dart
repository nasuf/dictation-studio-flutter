import 'package:flutter/material.dart';
import '../models/simple_comparison_result.dart';

class SimpleComparisonWidget extends StatelessWidget {
  final SimpleComparisonResult comparison;
  final bool showOriginal;
  final bool showUserInput;

  const SimpleComparisonWidget({
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
          _buildTextSection(context, comparison.transcriptResult),
          const SizedBox(height: 16),
        ],
        if (showUserInput) ...[
          _buildSectionTitle(context, 'Your Input', Icons.edit),
          const SizedBox(height: 8),
          _buildTextSection(context, comparison.userInputResult),
        ],
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

  Widget _buildTextSection(BuildContext context, List<SimpleComparisonWord> words) {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Wrap(
        spacing: 2,
        runSpacing: 4,
        children: words.map((word) => _buildWordChip(context, word)).toList(),
      ),
    );
  }

  Widget _buildWordChip(BuildContext context, SimpleComparisonWord word) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: word.backgroundColor,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        word.word,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: word.textColor,
          fontWeight: word.isCorrect ? FontWeight.normal : FontWeight.w500,
        ),
      ),
    );
  }
}