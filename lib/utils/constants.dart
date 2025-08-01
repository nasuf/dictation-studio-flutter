class AppConstants {
  // API Configuration is now handled by AppEnvironment
  // This class only contains UI and other constants

  // Visibility Options - Match React UI values
  static const String visibilityPublic = 'public';
  static const String visibilityPrivate = 'private';
  static const String visibilityAll = 'all';

  // Languages - Match React UI values
  static const String languageEnglish = 'en';
  static const String languageChinese = 'zh';
  static const String languageTraditionalChinese = 'zh_TW';
  static const String languageJapanese = 'ja';
  static const String languageKorean = 'ko';
  static const String languageAll = 'all';

  // UI Constants
  static const double cardBorderRadius = 12.0;
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;

  // Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Grid configuration
  static const int channelGridCrossAxisCount = 2;
  static const int videoGridCrossAxisCount = 2;
  static const double gridMainAxisSpacing = 16.0;
  static const double gridCrossAxisSpacing = 16.0;

  // Image aspect ratios
  static const double channelImageAspectRatio = 16 / 9;
  static const double videoThumbnailAspectRatio = 16 / 9;

  // Language Options Map - Match React UI structure
  static const Map<String, String> languageOptions = {
    'All': languageAll,
    'English': languageEnglish,
    'Chinese': languageChinese,
    'Traditional Chinese': languageTraditionalChinese,
    'Japanese': languageJapanese,
    'Korean': languageKorean,
  };

  // Visibility Options Map - Match React UI structure
  static const Map<String, String> visibilityOptions = {
    'All': visibilityAll,
    'Public': visibilityPublic,
    'Private': visibilityPrivate,
  };
}

class LanguageHelper {
  static const Map<String, String> languageNames = {
    AppConstants.languageEnglish: 'English',
    AppConstants.languageChinese: 'Chinese',
    AppConstants.languageTraditionalChinese: 'Traditional Chinese',
    AppConstants.languageJapanese: 'Japanese',
    AppConstants.languageKorean: 'Korean',
  };

  static String getLanguageName(String code) {
    return languageNames[code] ?? code.toUpperCase();
  }

  static List<String> getSupportedLanguages() {
    return languageNames.keys.toList();
  }
}
