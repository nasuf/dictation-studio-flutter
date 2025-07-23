import '../models/comparison_result.dart';
import 'language_utils.dart';

class TextComparisonUtils {
  /// Compares user input with transcript and returns detailed comparison result
  static ComparisonResult compareInputWithTranscript(
    String userInput,
    String transcript, {
    ComparisonConfig config = ComparisonConfig.defaultConfig,
  }) {
    if (userInput.trim().isEmpty && transcript.trim().isEmpty) {
      return ComparisonResult.empty();
    }

    // Detect language
    final language = LanguageUtils.detectLanguage(transcript);
    
    // Clean and split text
    final cleanUserInput = LanguageUtils.cleanString(userInput, language);
    final cleanTranscript = LanguageUtils.cleanString(transcript, language);
    
    final userWords = LanguageUtils.splitWords(cleanUserInput, language);
    final transcriptWords = LanguageUtils.splitWords(cleanTranscript, language);

    if (userWords.isEmpty) {
      // User hasn't typed anything
      return ComparisonResult(
        words: [],
        accuracy: 0.0,
        correctCount: 0,
        totalCount: transcriptWords.length,
        userInput: userInput,
        transcript: transcript,
      );
    }

    // Perform matching based on language
    final matchResult = language.isCJK 
        ? _matchWordsCJK(userWords, transcriptWords, config)
        : _matchWordsEnglish(userWords, transcriptWords, config);

    // Generate comparison words for UI display
    final comparisonWords = _generateComparisonWords(
      userWords, 
      transcriptWords, 
      matchResult.matches,
      language,
    );

    // Generate missed words
    final missedWords = _generateMissedWords(
      transcriptWords,
      matchResult.matches,
    );

    // Calculate accuracy
    final accuracy = matchResult.correctCount / transcriptWords.length * 100;

    return ComparisonResult(
      words: comparisonWords,
      missedWords: missedWords,
      accuracy: accuracy.clamp(0.0, 100.0),
      correctCount: matchResult.correctCount,
      totalCount: transcriptWords.length,
      userInput: userInput,
      transcript: transcript,
    );
  }

  /// Matches words for CJK languages using similarity and position weighting
  static _MatchResult _matchWordsCJK(
    List<String> userWords,
    List<String> transcriptWords,
    ComparisonConfig config,
  ) {
    final matches = List<int?>.filled(userWords.length, null);
    final usedTranscriptIndices = <int>{};
    int correctCount = 0;

    // Create similarity matrix
    final similarities = List.generate(
      userWords.length,
      (i) => List.generate(transcriptWords.length, (j) {
        double similarity = LanguageUtils.calculateSimilarity(
          userWords[i], 
          transcriptWords[j],
        );
        
        // Apply position weight if enabled
        if (config.enablePositionWeight) {
          final positionWeight = LanguageUtils.calculatePositionWeight(
            i, j, userWords.length, transcriptWords.length,
          );
          similarity = similarity * (1 - config.positionWeight) + 
                      positionWeight * config.positionWeight;
        }
        
        return similarity;
      }),
    );

    // Find best matches greedily
    while (true) {
      double bestSimilarity = 0;
      int bestUserIndex = -1;
      int bestTranscriptIndex = -1;

      // Find the best unmatched pair
      for (int i = 0; i < userWords.length; i++) {
        if (matches[i] != null) continue;
        
        for (int j = 0; j < transcriptWords.length; j++) {
          if (usedTranscriptIndices.contains(j)) continue;
          
          if (similarities[i][j] > bestSimilarity && 
              similarities[i][j] >= config.similarityThreshold) {
            bestSimilarity = similarities[i][j];
            bestUserIndex = i;
            bestTranscriptIndex = j;
          }
        }
      }

      // If no good match found, break
      if (bestUserIndex == -1) break;

      // Make the match
      matches[bestUserIndex] = bestTranscriptIndex;
      usedTranscriptIndices.add(bestTranscriptIndex);
      correctCount++;
    }

    return _MatchResult._(matches, correctCount);
  }

  /// Matches words for English using global optimization approach
  static _MatchResult _matchWordsEnglish(
    List<String> userWords,
    List<String> transcriptWords,
    ComparisonConfig config,
  ) {
    final matches = List<int?>.filled(userWords.length, null);
    final usedTranscriptIndices = <int>{};
    int correctCount = 0;

    // First pass: exact matches
    for (int i = 0; i < userWords.length; i++) {
      for (int j = 0; j < transcriptWords.length; j++) {
        if (usedTranscriptIndices.contains(j)) continue;
        
        if (userWords[i] == transcriptWords[j] ||
            LanguageUtils.areWordsEquivalent(
              userWords[i], 
              transcriptWords[j], 
              DetectedLanguage.english,
            )) {
          matches[i] = j;
          usedTranscriptIndices.add(j);
          correctCount++;
          break;
        }
      }
    }

    // Second pass: similarity-based matching with position weight
    for (int i = 0; i < userWords.length; i++) {
      if (matches[i] != null) continue;
      
      double bestScore = 0;
      int bestMatch = -1;
      
      for (int j = 0; j < transcriptWords.length; j++) {
        if (usedTranscriptIndices.contains(j)) continue;
        
        double similarity = LanguageUtils.calculateSimilarity(
          userWords[i], 
          transcriptWords[j],
        );
        
        if (config.enablePositionWeight) {
          final positionWeight = LanguageUtils.calculatePositionWeight(
            i, j, userWords.length, transcriptWords.length,
          );
          similarity = similarity * (1 - config.positionWeight) + 
                      positionWeight * config.positionWeight;
        }
        
        if (similarity > bestScore && similarity >= config.similarityThreshold) {
          bestScore = similarity;
          bestMatch = j;
        }
      }
      
      if (bestMatch != -1) {
        matches[i] = bestMatch;
        usedTranscriptIndices.add(bestMatch);
        correctCount++;
      }
    }

    return _MatchResult._(matches, correctCount);
  }

  /// Generates comparison words for UI display with enhanced difference annotation
  static List<ComparisonWord> _generateComparisonWords(
    List<String> userWords,
    List<String> transcriptWords,
    List<int?> matches,
    DetectedLanguage language,
  ) {
    final comparisonWords = <ComparisonWord>[];
    
    for (int i = 0; i < userWords.length; i++) {
      final matchIndex = matches[i];
      
      if (matchIndex != null) {
        // User word matches transcript word
        comparisonWords.add(ComparisonWord(
          text: userWords[i],
          type: ComparisonType.correct,
          originalIndex: matchIndex,
          originalWord: transcriptWords[matchIndex],
        ));
      } else {
        // User word doesn't match any transcript word - could be incorrect or extra
        comparisonWords.add(ComparisonWord(
          text: userWords[i],
          type: ComparisonType.extra,
          originalIndex: -1,
          originalWord: null,
        ));
      }
    }
    
    return comparisonWords;
  }

  /// Generates missed words that user didn't type
  static List<ComparisonWord> _generateMissedWords(
    List<String> transcriptWords,
    List<int?> matches,
  ) {
    // Find which transcript words weren't matched
    final matchedIndices = <int>{};
    for (int i = 0; i < matches.length; i++) {
      if (matches[i] != null) {
        matchedIndices.add(matches[i]!);
      }
    }
    
    final missedWords = <ComparisonWord>[];
    for (int i = 0; i < transcriptWords.length; i++) {
      if (!matchedIndices.contains(i)) {
        missedWords.add(ComparisonWord(
          text: transcriptWords[i],
          type: ComparisonType.missing,
          originalIndex: i,
          expectedWord: transcriptWords[i],
        ));
      }
    }
    
    return missedWords;
  }

  /// Gets missed words that the user didn't type
  static List<String> getMissedWords(
    String userInput,
    String transcript, {
    ComparisonConfig config = ComparisonConfig.defaultConfig,
  }) {
    final result = compareInputWithTranscript(userInput, transcript, config: config);
    final language = LanguageUtils.detectLanguage(transcript);
    
    final cleanTranscript = LanguageUtils.cleanString(transcript, language);
    final transcriptWords = LanguageUtils.splitWords(cleanTranscript, language);
    
    // Find which transcript words weren't matched
    final matchedIndices = <int>{};
    for (final word in result.words) {
      if (word.isCorrect && word.originalIndex >= 0) {
        matchedIndices.add(word.originalIndex);
      }
    }
    
    final missedWords = <String>[];
    for (int i = 0; i < transcriptWords.length; i++) {
      if (!matchedIndices.contains(i)) {
        missedWords.add(transcriptWords[i]);
      }
    }
    
    return missedWords;
  }

  /// Calculates overall accuracy for multiple comparisons
  static double calculateOverallAccuracy(List<ComparisonResult> results) {
    if (results.isEmpty) return 0.0;
    
    int totalCorrect = 0;
    int totalWords = 0;
    
    for (final result in results) {
      totalCorrect += result.correctCount;
      totalWords += result.totalCount;
    }
    
    return totalWords > 0 ? (totalCorrect / totalWords * 100) : 0.0;
  }

  /// Formats comparison result for display
  static String formatComparisonResult(ComparisonResult result) {
    if (result.isEmpty) return 'No input to compare';
    
    return '${result.correctCount}/${result.totalCount} correct (${result.accuracyString})';
  }
}

/// Internal class for matching results
class _MatchResult {
  final List<int?> matches; // matches[i] = j means userWords[i] matches transcriptWords[j]
  final int correctCount;

  _MatchResult._(this.matches, this.correctCount);
}