import 'package:flutter/material.dart';
import '../models/comparison_result.dart';

/// Widget to display text comparison results with color coding
class ComparisonTextWidget extends StatelessWidget {
  final ComparisonResult comparison;
  final double fontSize;
  final FontWeight fontWeight;

  const ComparisonTextWidget({
    super.key,
    required this.comparison,
    this.fontSize = 16.0,
    this.fontWeight = FontWeight.normal,
  });

  @override
  Widget build(BuildContext context) {
    if (comparison.isEmpty || comparison.words.isEmpty) {
      return Text(
        comparison.userInput.isEmpty 
            ? 'No input to display' 
            : comparison.userInput,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: Colors.grey,
        ),
      );
    }

    return Wrap(
      children: comparison.words.map((word) => _buildWordWidget(word)).toList(),
    );
  }

  Widget _buildWordWidget(ComparisonWord word) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1.0, vertical: 1.0),
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: word.backgroundColor,
        borderRadius: BorderRadius.circular(4.0),
        border: word.isCorrect 
            ? null 
            : Border.all(color: Colors.red.shade300, width: 1.0),
      ),
      child: Tooltip(
        message: word.isCorrect 
            ? 'Correct' 
            : 'Incorrect${word.originalWord != null ? " (should be: ${word.originalWord})" : ""}',
        child: Text(
          word.text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: word.textColor,
          ),
        ),
      ),
    );
  }
}

/// Widget to display comparison statistics
class ComparisonStatsWidget extends StatelessWidget {
  final ComparisonResult comparison;
  final bool showDetails;

  const ComparisonStatsWidget({
    super.key,
    required this.comparison,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    if (comparison.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final accuracyColor = _getAccuracyColor(comparison.accuracy);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.assessment,
                  color: accuracyColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Accuracy: ${comparison.accuracyString}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: accuracyColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            if (showDetails) ...[
              const SizedBox(height: 8),
              Text(
                'Correct: ${comparison.correctCount}/${comparison.totalCount} words',
                style: theme.textTheme.bodyMedium,
              ),
              
              if (comparison.incorrectWords.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Errors:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4.0,
                  children: comparison.incorrectWords.take(5).map((word) {
                    return Chip(
                      label: Text(
                        word.text,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.red.shade100,
                      side: BorderSide(color: Colors.red.shade300),
                    );
                  }).toList(),
                ),
                
                if (comparison.incorrectWords.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '... and ${comparison.incorrectWords.length - 5} more',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ],
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

/// Widget to display side-by-side comparison
class SideBySideComparisonWidget extends StatelessWidget {
  final ComparisonResult comparison;

  const SideBySideComparisonWidget({
    super.key,
    required this.comparison,
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
              'Comparison',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Input:',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          comparison.userInput.isEmpty 
                              ? '(No input)'
                              : comparison.userInput,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 16),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expected:',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          comparison.transcript,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Corrected Text:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: ComparisonTextWidget(comparison: comparison),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}