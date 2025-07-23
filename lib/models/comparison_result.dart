import 'package:flutter/material.dart';

// Types of comparison results
enum ComparisonType {
  correct,      // User input matches transcript
  incorrect,    // User input doesn't match transcript
  missing,      // User didn't type this word from transcript
  extra,        // User typed this word but it's not in transcript
}

// Represents a single word or character in the comparison result
class ComparisonWord {
  final String text;
  final ComparisonType type;
  final int originalIndex; // Index in the original transcript (-1 for extra words)
  final String? originalWord; // The word it should have been
  final String? expectedWord; // For missing words, what should be there

  ComparisonWord({
    required this.text,
    required this.type,
    required this.originalIndex,
    this.originalWord,
    this.expectedWord,
  });

  // Legacy compatibility
  bool get isCorrect => type == ComparisonType.correct;

  Color get backgroundColor {
    switch (type) {
      case ComparisonType.correct:
        return Colors.green.withOpacity(0.3);
      case ComparisonType.incorrect:
        return Colors.orange.withOpacity(0.3);
      case ComparisonType.missing:
        return Colors.grey.withOpacity(0.3);
      case ComparisonType.extra:
        return Colors.red.withOpacity(0.3);
    }
  }

  Color get textColor {
    switch (type) {
      case ComparisonType.correct:
        return Colors.green.shade800;
      case ComparisonType.incorrect:
        return Colors.orange.shade800;
      case ComparisonType.missing:
        return Colors.grey.shade800;
      case ComparisonType.extra:
        return Colors.red.shade800;
    }
  }

  IconData? get icon {
    switch (type) {
      case ComparisonType.correct:
        return Icons.check_circle_outline;
      case ComparisonType.incorrect:
        return Icons.edit_outlined;
      case ComparisonType.missing:
        return Icons.remove_circle_outline;
      case ComparisonType.extra:
        return Icons.add_circle_outline;
    }
  }
}

// Represents the overall comparison result between user input and transcript
class ComparisonResult {
  final List<ComparisonWord> words;
  final List<ComparisonWord> missedWords; // Words from transcript that user didn't type
  final double accuracy; // Percentage 0-100
  final int correctCount;
  final int totalCount;
  final String userInput;
  final String transcript;

  ComparisonResult({
    required this.words,
    this.missedWords = const [],
    required this.accuracy,
    required this.correctCount,
    required this.totalCount,
    required this.userInput,
    required this.transcript,
  });

  // Create an empty comparison result
  factory ComparisonResult.empty() {
    return ComparisonResult(
      words: [],
      missedWords: [],
      accuracy: 0.0,
      correctCount: 0,
      totalCount: 0,
      userInput: '',
      transcript: '',
    );
  }

  // Check if this is an empty result
  bool get isEmpty => words.isEmpty && userInput.isEmpty;

  // Get formatted accuracy string
  String get accuracyString => '${accuracy.toStringAsFixed(1)}%';

  // Get list of incorrect words for review
  List<ComparisonWord> get incorrectWords => 
      words.where((word) => !word.isCorrect).toList();

  // Get list of correct words
  List<ComparisonWord> get correctWords => 
      words.where((word) => word.isCorrect).toList();

  @override
  String toString() {
    return 'ComparisonResult{accuracy: $accuracy%, correct: $correctCount/$totalCount}';
  }
}

// Configuration for text comparison
class ComparisonConfig {
  final double similarityThreshold; // 0.0 - 1.0
  final bool ignoreCase;
  final bool ignorePunctuation;
  final bool enablePositionWeight;
  final double positionWeight; // Weight given to position matching

  const ComparisonConfig({
    this.similarityThreshold = 0.7,
    this.ignoreCase = true,
    this.ignorePunctuation = true,
    this.enablePositionWeight = true,
    this.positionWeight = 0.3,
  });

  static const ComparisonConfig defaultConfig = ComparisonConfig();
}

// Language detection result
enum DetectedLanguage {
  english('en'),
  chinese('zh'),
  japanese('ja'),
  korean('ko'),
  unknown('unknown');

  const DetectedLanguage(this.code);
  final String code;

  bool get isCJK => this == chinese || this == japanese || this == korean;
  bool get isSpaceDelimited => this == english;
}