import 'dart:math';
import '../models/comparison_result.dart';
import '../models/transcript_item.dart';

class LanguageUtils {
  // Number word mappings for English
  static const Map<String, String> _numberToWord = {
    '0': 'zero', '1': 'one', '2': 'two', '3': 'three', '4': 'four',
    '5': 'five', '6': 'six', '7': 'seven', '8': 'eight', '9': 'nine',
    '10': 'ten', '11': 'eleven', '12': 'twelve', '13': 'thirteen',
    '14': 'fourteen', '15': 'fifteen', '16': 'sixteen', '17': 'seventeen',
    '18': 'eighteen', '19': 'nineteen', '20': 'twenty', '30': 'thirty',
    '40': 'forty', '50': 'fifty', '60': 'sixty', '70': 'seventy',
    '80': 'eighty', '90': 'ninety', '100': 'hundred', '1000': 'thousand',
    '1000000': 'million', '1000000000': 'billion',
  };

  // Reverse mapping for word to number
  static final Map<String, String> _wordToNumber = {
    for (var entry in _numberToWord.entries) entry.value: entry.key
  };

  // English abbreviations that don't end sentences
  static const Set<String> _englishAbbreviations = {
    'mr', 'mrs', 'ms', 'dr', 'prof', 'sr', 'jr', 'st', 'ave', 'blvd',
    'dept', 'univ', 'assn', 'bros', 'etc', 'vs', 'inc', 'ltd', 'co',
    'corp', 'gov', 'edu', 'org', 'net', 'com', 'mil', 'int'
  };

  /// Detects the language of the given text
  static DetectedLanguage detectLanguage(String text) {
    if (text.trim().isEmpty) return DetectedLanguage.unknown;

    final cleanText = text.replaceAll(RegExp(r'\s+'), '');
    final length = cleanText.length;
    if (length == 0) return DetectedLanguage.unknown;

    int chineseCount = 0;
    int japaneseCount = 0;
    int koreanCount = 0;
    int englishCount = 0;

    for (int i = 0; i < cleanText.length; i++) {
      final codeUnit = cleanText.codeUnitAt(i);
      
      // Chinese characters (CJK Unified Ideographs)
      if ((codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) ||
          (codeUnit >= 0x3400 && codeUnit <= 0x4DBF) ||
          (codeUnit >= 0x20000 && codeUnit <= 0x2A6DF)) {
        chineseCount++;
      }
      // Japanese Hiragana and Katakana
      else if ((codeUnit >= 0x3040 && codeUnit <= 0x309F) || // Hiragana
               (codeUnit >= 0x30A0 && codeUnit <= 0x30FF)) { // Katakana
        japaneseCount++;
      }
      // Korean Hangul
      else if ((codeUnit >= 0xAC00 && codeUnit <= 0xD7AF) || // Hangul Syllables
               (codeUnit >= 0x1100 && codeUnit <= 0x11FF) || // Hangul Jamo
               (codeUnit >= 0x3130 && codeUnit <= 0x318F)) { // Hangul Compatibility Jamo
        koreanCount++;
      }
      // English letters
      else if ((codeUnit >= 0x0041 && codeUnit <= 0x005A) || // A-Z
               (codeUnit >= 0x0061 && codeUnit <= 0x007A)) { // a-z
        englishCount++;
      }
    }

    // Determine language based on highest count
    final maxCount = [chineseCount, japaneseCount, koreanCount, englishCount].reduce(max);
    
    if (maxCount == 0) return DetectedLanguage.unknown;
    
    if (chineseCount == maxCount) return DetectedLanguage.chinese;
    if (japaneseCount == maxCount) return DetectedLanguage.japanese;
    if (koreanCount == maxCount) return DetectedLanguage.korean;
    if (englishCount == maxCount) return DetectedLanguage.english;
    
    return DetectedLanguage.unknown;
  }

  /// Cleans a string by removing punctuation and normalizing
  static String cleanString(String text, DetectedLanguage language) {
    if (text.isEmpty) return '';

    String cleaned = text.trim();

    // Remove punctuation based on language
    switch (language) {
      case DetectedLanguage.english:
        // Keep apostrophes for contractions
        cleaned = cleaned.replaceAll(RegExp(r"[^\w\s']"), '');
        break;
      case DetectedLanguage.chinese:
        cleaned = cleaned.replaceAll(
          RegExp(r'[《》「」『』，。！？、：；（）【】""'']'), ''
        );
        break;
      case DetectedLanguage.japanese:
      case DetectedLanguage.korean:
        cleaned = cleaned.replaceAll(
          RegExp(r'[。、！？：；（）【】「」『』""'']'), ''
        );
        break;
      case DetectedLanguage.unknown:
        cleaned = cleaned.replaceAll(RegExp(r'[^\w\s]'), '');
        break;
    }

    // Normalize whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return cleaned.toLowerCase();
  }

  /// Splits text into words/characters based on language
  static List<String> splitWords(String text, DetectedLanguage language) {
    if (text.isEmpty) return [];

    switch (language) {
      case DetectedLanguage.english:
        return text.split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .toList();
      
      case DetectedLanguage.chinese:
      case DetectedLanguage.japanese:
      case DetectedLanguage.korean:
        // Split by characters for CJK languages
        return text.split('')
            .where((char) => char.trim().isNotEmpty)
            .toList();
      
      case DetectedLanguage.unknown:
        // Default to space splitting
        return text.split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .toList();
    }
  }

  /// Calculates similarity between two strings using Levenshtein distance
  static double calculateSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final maxLength = max(a.length, b.length);
    final distance = _levenshteinDistance(a, b);
    
    return 1.0 - (distance / maxLength);
  }

  /// Calculates Levenshtein distance between two strings
  static int _levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => 0),
    );

    // Initialize first row and column
    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    // Fill the matrix
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,      // deletion
          matrix[i][j - 1] + 1,      // insertion
          matrix[i - 1][j - 1] + cost // substitution
        ].reduce(min);
      }
    }

    return matrix[a.length][b.length];
  }

  /// Checks if two words are equivalent (including number conversions)
  static bool areWordsEquivalent(String word1, String word2, DetectedLanguage language) {
    if (word1 == word2) return true;

    // For English, check number-word equivalents
    if (language == DetectedLanguage.english) {
      final normalizedWord1 = word1.toLowerCase();
      final normalizedWord2 = word2.toLowerCase();
      
      // Check direct number-word mapping
      if (_numberToWord[normalizedWord1] == normalizedWord2 ||
          _numberToWord[normalizedWord2] == normalizedWord1) {
        return true;
      }
      
      // Check reverse mapping
      if (_wordToNumber[normalizedWord1] == normalizedWord2 ||
          _wordToNumber[normalizedWord2] == normalizedWord1) {
        return true;
      }
    }

    return false;
  }

  /// Checks if a sentence is complete based on language-specific rules
  static bool isCompleteSentence(String text, DetectedLanguage language) {
    if (text.trim().isEmpty) return false;

    final trimmed = text.trim();
    
    switch (language) {
      case DetectedLanguage.english:
        // Check for sentence-ending punctuation
        if (!RegExp(r'[.!?]$').hasMatch(trimmed)) return false;
        
        // Check for abbreviations that don't end sentences
        final words = trimmed.toLowerCase().split(RegExp(r'\s+'));
        if (words.isNotEmpty) {
          final lastWord = words.last.replaceAll(RegExp(r'[.!?]$'), '');
          if (_englishAbbreviations.contains(lastWord)) return false;
        }
        return true;
        
      case DetectedLanguage.chinese:
        return RegExp(r'[。！？]$').hasMatch(trimmed);
        
      case DetectedLanguage.japanese:
      case DetectedLanguage.korean:
        return RegExp(r'[。！？]$').hasMatch(trimmed);
        
      case DetectedLanguage.unknown:
        return RegExp(r'[.!?。！？]$').hasMatch(trimmed);
    }
  }

  /// Calculates position weight for word matching
  static double calculatePositionWeight(
    int inputIndex,
    int transcriptIndex,
    int inputLength,
    int transcriptLength,
  ) {
    if (inputLength <= 1 || transcriptLength <= 1) return 1.0;
    
    final inputRatio = inputIndex / (inputLength - 1);
    final transcriptRatio = transcriptIndex / (transcriptLength - 1);
    final positionDiff = (inputRatio - transcriptRatio).abs();
    
    return max(0.0, 1.0 - positionDiff);
  }

  /// Auto-merges transcript items based on punctuation and timing
  static List<TranscriptItem> autoMergeTranscriptItems(
    List<TranscriptItem> transcript,
    double maxDuration,
  ) {
    if (transcript.isEmpty) return [];

    final merged = <TranscriptItem>[];
    TranscriptItem? current;

    for (final item in transcript) {
      if (current == null) {
        current = item;
        continue;
      }

      final language = detectLanguage(current.transcript);
      final shouldMerge = !isCompleteSentence(current.transcript, language) &&
                         (item.start - current.start) <= maxDuration;

      if (shouldMerge) {
        // Merge with current item
        current = TranscriptItem(
          start: current.start,
          end: item.end,
          transcript: '${current.transcript} ${item.transcript}',
          index: current.index,
        );
      } else {
        // Save current and start new
        merged.add(current);
        current = item;
      }
    }

    // Add the last item
    if (current != null) {
      merged.add(current);
    }

    return merged;
  }
}