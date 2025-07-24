import '../models/simple_comparison_result.dart';
import '../models/comparison_result.dart';  // For DetectedLanguage enum
import 'language_utils.dart';

class PreciseTextComparison {
  /// Compare input with transcript using React version's exact logic
  static SimpleComparisonResult compareInputWithTranscript(
    String userInput,
    String transcript,
  ) {
    if (userInput.trim().isEmpty && transcript.trim().isEmpty) {
      return SimpleComparisonResult.empty();
    }

    // Step 1: Normalize apostrophes
    final normalizedInput = userInput.replaceAll(RegExp(r"['''`]"), "'");
    final normalizedTranscript = transcript.replaceAll(RegExp(r"['''`]"), "'");

    // Step 2: Detect language and split words
    final language = LanguageUtils.detectLanguage(normalizedTranscript);
    
    final cleanedInput = LanguageUtils.cleanString(normalizedInput, language);
    final cleanedTranscript = LanguageUtils.cleanString(normalizedTranscript, language);
    
    final inputWords = LanguageUtils.splitWords(cleanedInput, language);
    final transcriptWords = LanguageUtils.splitWords(cleanedTranscript, language);
    final originalTranscriptWords = LanguageUtils.splitWords(normalizedTranscript, language);
    final originalInputWords = LanguageUtils.splitWords(normalizedInput, language);

    // Step 3: Find optimal matching
    final matchingResult = _findOptimalMatching(
      inputWords,
      transcriptWords,
      originalTranscriptWords,
      language,
    );

    // Step 4: Create transcript result (original text with highlighting)
    final transcriptResult = _createTranscriptResult(
      originalTranscriptWords,
      matchingResult.usedOriginalIndices,
    );

    // Step 5: Create user input result (user input with highlighting)  
    final userInputResult = _createUserInputResult(
      originalInputWords,
      inputWords,
      matchingResult.matchMap,
      language,
    );

    // Step 6: Calculate accuracy
    final correctWords = matchingResult.inputResult.where((w) => w.isCorrect).length;
    final accuracy = transcriptWords.isNotEmpty 
        ? (correctWords / transcriptWords.length * 100).clamp(0.0, 100.0)
        : 0.0;

    return SimpleComparisonResult(
      transcriptResult: transcriptResult,
      userInputResult: userInputResult,
      accuracy: accuracy,
      userInput: userInput,
      transcript: transcript,
    );
  }

  /// Find optimal word matching using position-weighted algorithm
  static _MatchingResult _findOptimalMatching(
    List<String> inputWords,
    List<String> transcriptWords,
    List<String> originalTranscriptWords,
    DetectedLanguage language,
  ) {
    if (language.isCJK) {
      return _matchCJKWords(inputWords, transcriptWords, originalTranscriptWords);
    } else {
      return _matchEnglishWords(inputWords, transcriptWords, originalTranscriptWords, language);
    }
  }

  /// Match CJK words using similarity-based matching
  static _MatchingResult _matchCJKWords(
    List<String> inputWords,
    List<String> transcriptWords,
    List<String> originalTranscriptWords,
  ) {
    final usedIndices = <int>{};
    final inputResult = <_WordResult>[];
    final matchMap = <int, int>{};

    for (int inputIndex = 0; inputIndex < inputWords.length; inputIndex++) {
      final word = inputWords[inputIndex];
      final similarityThreshold = word.length == 1 ? 0.6 : 0.8;
      
      int bestMatchIndex = -1;
      double bestScore = 0;

      for (int transcriptIndex = 0; transcriptIndex < transcriptWords.length; transcriptIndex++) {
        if (!usedIndices.contains(transcriptIndex)) {
          final similarity = LanguageUtils.calculateSimilarity(word, transcriptWords[transcriptIndex]);
          if (similarity > similarityThreshold) {
            final positionWeight = _calculatePositionWeight(inputIndex, transcriptIndex, inputWords.length, transcriptWords.length);
            final combinedScore = similarity * 0.7 + positionWeight * 0.3;

            if (combinedScore > bestScore) {
              bestMatchIndex = transcriptIndex;
              bestScore = combinedScore;
            }
          }
        }
      }

      if (bestMatchIndex != -1) {
        usedIndices.add(bestMatchIndex);
        matchMap[inputIndex] = bestMatchIndex;
        inputResult.add(_WordResult(
          word: originalTranscriptWords[bestMatchIndex],
          isCorrect: true,
        ));
      } else {
        inputResult.add(_WordResult(
          word: word,
          isCorrect: false,
        ));
      }
    }

    final usedOriginalIndices = usedIndices.toSet();
    
    return _MatchingResult(
      inputResult: inputResult,
      usedOriginalIndices: usedOriginalIndices,
      matchMap: matchMap,
    );
  }

  /// Match English words using exact matching with position weighting
  static _MatchingResult _matchEnglishWords(
    List<String> inputWords,
    List<String> transcriptWords,
    List<String> originalTranscriptWords,
    DetectedLanguage language,
  ) {
    // Create mapping from cleaned transcript indices to original indices
    final cleanedToOriginalMap = <int, int>{};
    int cleanedIndex = 0;
    
    for (int originalIndex = 0; originalIndex < originalTranscriptWords.length; originalIndex++) {
      final cleanedWord = LanguageUtils.cleanString(originalTranscriptWords[originalIndex], language);
      if (cleanedWord.trim().isNotEmpty) {
        cleanedToOriginalMap[cleanedIndex] = originalIndex;
        cleanedIndex++;
      }
    }

    // Find all possible matches and sort by position weight
    final allMatches = <_PossibleMatch>[];
    
    for (int inputIndex = 0; inputIndex < inputWords.length; inputIndex++) {
      for (int transcriptIndex = 0; transcriptIndex < transcriptWords.length; transcriptIndex++) {
        if (_areWordsEquivalent(inputWords[inputIndex], transcriptWords[transcriptIndex], language)) {
          final positionWeight = _calculatePositionWeight(
            inputIndex, transcriptIndex, inputWords.length, transcriptWords.length);
          allMatches.add(_PossibleMatch(
            inputIndex: inputIndex,
            transcriptIndex: transcriptIndex,
            score: positionWeight,
          ));
        }
      }
    }

    // Sort by score (highest first)
    allMatches.sort((a, b) => b.score.compareTo(a.score));

    // Greedily assign matches, avoiding conflicts
    final usedInputIndices = <int>{};
    final usedTranscriptIndices = <int>{};
    final matchMap = <int, int>{};

    for (final match in allMatches) {
      if (!usedInputIndices.contains(match.inputIndex) && 
          !usedTranscriptIndices.contains(match.transcriptIndex)) {
        matchMap[match.inputIndex] = match.transcriptIndex;
        usedInputIndices.add(match.inputIndex);
        usedTranscriptIndices.add(match.transcriptIndex);
      }
    }

    // Build input result
    final inputResult = <_WordResult>[];
    for (int inputIndex = 0; inputIndex < inputWords.length; inputIndex++) {
      if (matchMap.containsKey(inputIndex)) {
        final cleanedTranscriptIndex = matchMap[inputIndex]!;
        final originalTranscriptIndex = cleanedToOriginalMap[cleanedTranscriptIndex];
        if (originalTranscriptIndex != null) {
          inputResult.add(_WordResult(
            word: originalTranscriptWords[originalTranscriptIndex],
            isCorrect: true,
          ));
        } else {
          inputResult.add(_WordResult(
            word: inputWords[inputIndex],
            isCorrect: false,
          ));
        }
      } else {
        inputResult.add(_WordResult(
          word: inputWords[inputIndex],
          isCorrect: false,
        ));
      }
    }

    // Map used indices to original indices
    final usedOriginalIndices = <int>{};
    for (var cleanedIdx in usedTranscriptIndices) {
      final originalIdx = cleanedToOriginalMap[cleanedIdx];
      if (originalIdx != null) {
        usedOriginalIndices.add(originalIdx);
      }
    }

    return _MatchingResult(
      inputResult: inputResult,
      usedOriginalIndices: usedOriginalIndices,
      matchMap: matchMap,
    );
  }

  /// Check if words are equivalent (exact match or number/word conversion)
  static bool _areWordsEquivalent(String word1, String word2, DetectedLanguage language) {
    if (language != DetectedLanguage.english) {
      return word1 == word2;
    }

    final lower1 = word1.toLowerCase();
    final lower2 = word2.toLowerCase();

    // Direct case-insensitive comparison
    if (lower1 == lower2) return true;

    // Number-word conversions using existing utility
    return LanguageUtils.areWordsEquivalent(word1, word2, language);
  }

  /// Calculate position weight for better matching
  static double _calculatePositionWeight(int inputIndex, int transcriptIndex, int inputLength, int transcriptLength) {
    if (inputLength == 0 || transcriptLength == 0) return 0;

    final inputRatio = inputIndex / (inputLength - 1).clamp(1, double.infinity);
    final transcriptRatio = transcriptIndex / (transcriptLength - 1).clamp(1, double.infinity);

    final positionDiff = (inputRatio - transcriptRatio).abs();
    final weight = (1 - positionDiff).clamp(0.0, 1.0);

    return weight;
  }

  /// Create transcript result with highlighting
  static List<SimpleComparisonWord> _createTranscriptResult(
    List<String> originalTranscriptWords,
    Set<int> usedOriginalIndices,
  ) {
    return originalTranscriptWords.asMap().entries.map((entry) {
      final index = entry.key;
      final word = entry.value;
      
      // Check if word is pure punctuation (should be marked as correct)
      final isPunctuation = _isPunctuation(word);
      final isMatched = usedOriginalIndices.contains(index);
      final isCorrect = isMatched || isPunctuation;
      
      return SimpleComparisonWord(
        word: word,
        isCorrect: isCorrect,
      );
    }).toList();
  }

  /// Create user input result with highlighting
  static List<SimpleComparisonWord> _createUserInputResult(
    List<String> originalInputWords,
    List<String> cleanedInputWords,
    Map<int, int> matchMap,
    DetectedLanguage language,
  ) {
    return originalInputWords.asMap().entries.map((entry) {
      final originalIndex = entry.key;
      final originalWord = entry.value;
      
      // Find corresponding cleaned input index
      int cleanedInputIndex = -1;
      int currentCleanedIndex = 0;
      
      for (int i = 0; i <= originalIndex; i++) {
        final cleanedWord = LanguageUtils.cleanString(originalInputWords[i], language);
        if (cleanedWord.trim().isNotEmpty) {
          if (i == originalIndex) {
            cleanedInputIndex = currentCleanedIndex;
            break;
          }
          currentCleanedIndex++;
        }
      }
      
      // Check if this word was matched correctly
      bool isCorrect = false;
      if (cleanedInputIndex >= 0 && matchMap.containsKey(cleanedInputIndex)) {
        isCorrect = true;
      }
      
      // Pure punctuation should be marked as correct
      if (_isPunctuation(originalWord)) {
        isCorrect = true;
      }
      
      return SimpleComparisonWord(
        word: originalWord,
        isCorrect: isCorrect,
      );
    }).toList();
  }

  /// Check if a word is pure punctuation
  static bool _isPunctuation(String word) {
    final withoutPunctuation = word.replaceAll(RegExp(r'[^\w\s]'), '');
    return withoutPunctuation.trim().isEmpty;
  }
}

/// Internal helper classes
class _WordResult {
  final String word;
  final bool isCorrect;

  _WordResult({required this.word, required this.isCorrect});
}

class _MatchingResult {
  final List<_WordResult> inputResult;
  final Set<int> usedOriginalIndices;
  final Map<int, int> matchMap;

  _MatchingResult({
    required this.inputResult,
    required this.usedOriginalIndices,
    required this.matchMap,
  });
}

class _PossibleMatch {
  final int inputIndex;
  final int transcriptIndex;
  final double score;

  _PossibleMatch({
    required this.inputIndex,
    required this.transcriptIndex,
    required this.score,
  });
}