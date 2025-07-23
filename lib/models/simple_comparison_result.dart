import 'package:flutter/material.dart';

/// Simple comparison word with only correct/incorrect states
class SimpleComparisonWord {
  final String word;
  final bool isCorrect;

  SimpleComparisonWord({
    required this.word,
    required this.isCorrect,
  });

  Color get backgroundColor {
    return isCorrect 
        ? const Color(0x4D7CEECE)  // Light green background (#7CEECE with 30% opacity)
        : const Color(0x4DFFAAA5); // Light red background (#FFAAA5 with 30% opacity)
  }

  Color get textColor {
    return isCorrect 
        ? const Color(0xFF00827F)  // Dark green text
        : const Color(0xFFC41E3A); // Dark red text
  }
}

/// Simple comparison result with only transcript and user input results
class SimpleComparisonResult {
  final List<SimpleComparisonWord> transcriptResult; // Original text with highlighting
  final List<SimpleComparisonWord> userInputResult;  // User input with highlighting
  final double accuracy; // Percentage 0-100
  final String userInput;
  final String transcript;

  SimpleComparisonResult({
    required this.transcriptResult,
    required this.userInputResult,
    required this.accuracy,
    required this.userInput,
    required this.transcript,
  });

  factory SimpleComparisonResult.empty() {
    return SimpleComparisonResult(
      transcriptResult: [],
      userInputResult: [],
      accuracy: 0.0,
      userInput: '',
      transcript: '',
    );
  }

  bool get isEmpty => transcriptResult.isEmpty && userInput.isEmpty;
  String get accuracyString => '${accuracy.toStringAsFixed(1)}%';
}