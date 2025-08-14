import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Dictation Studio'**
  String get appName;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @channels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get channels;

  /// No description provided for @videos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get videos;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @systemTheme.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemTheme;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signingOut.
  ///
  /// In en, this message translates to:
  /// **'Signing Out...'**
  String get signingOut;

  /// No description provided for @areYouSureSignOut.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get areYouSureSignOut;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Dictation Studio'**
  String get welcome;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createAccount;

  /// No description provided for @signInToAccess.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access your personalized learning dashboard'**
  String get signInToAccess;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @pleaseEnterFullName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name'**
  String get pleaseEnterFullName;

  /// No description provided for @pleaseEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterEmail;

  /// No description provided for @pleaseEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get pleaseEnterValidEmail;

  /// No description provided for @pleaseEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @pleaseConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get pleaseConfirmPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @chooseAvatar.
  ///
  /// In en, this message translates to:
  /// **'Choose Avatar'**
  String get chooseAvatar;

  /// No description provided for @registrationSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Registration Successful'**
  String get registrationSuccessful;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @googleLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Google login failed'**
  String get googleLoginFailed;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinLength;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get dontHaveAccount;

  /// No description provided for @connectingToGoogle.
  ///
  /// In en, this message translates to:
  /// **'Connecting to Google...'**
  String get connectingToGoogle;

  /// No description provided for @googleLoginInitiated.
  ///
  /// In en, this message translates to:
  /// **'Google login initiated successfully. Please complete the login in your browser.'**
  String get googleLoginInitiated;

  /// No description provided for @pleaseCheckEmail.
  ///
  /// In en, this message translates to:
  /// **'Please check your email to verify your account.'**
  String get pleaseCheckEmail;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @learnLanguages.
  ///
  /// In en, this message translates to:
  /// **'Learn Languages'**
  String get learnLanguages;

  /// No description provided for @practiceListening.
  ///
  /// In en, this message translates to:
  /// **'Practice Listening'**
  String get practiceListening;

  /// No description provided for @improveSkills.
  ///
  /// In en, this message translates to:
  /// **'Improve Skills'**
  String get improveSkills;

  /// No description provided for @welcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Dictation Studio'**
  String get welcomeMessage;

  /// No description provided for @appDescription.
  ///
  /// In en, this message translates to:
  /// **'Improve your language skills with our interactive dictation exercises'**
  String get appDescription;

  /// No description provided for @feature1Title.
  ///
  /// In en, this message translates to:
  /// **'Multi-language Support'**
  String get feature1Title;

  /// No description provided for @feature1Description.
  ///
  /// In en, this message translates to:
  /// **'Practice with English, Chinese, Japanese, Korean and more'**
  String get feature1Description;

  /// No description provided for @feature2Title.
  ///
  /// In en, this message translates to:
  /// **'Personalized Learning'**
  String get feature2Title;

  /// No description provided for @feature2Description.
  ///
  /// In en, this message translates to:
  /// **'Track your progress and get personalized recommendations'**
  String get feature2Description;

  /// No description provided for @feature3Title.
  ///
  /// In en, this message translates to:
  /// **'Rich Content'**
  String get feature3Title;

  /// No description provided for @feature3Description.
  ///
  /// In en, this message translates to:
  /// **'Curated audio content to enhance your listening and spelling skills'**
  String get feature3Description;

  /// No description provided for @youtubeLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'YouTube Login Required'**
  String get youtubeLoginRequired;

  /// No description provided for @youtubeLoginDescription1.
  ///
  /// In en, this message translates to:
  /// **'To watch and practice with YouTube videos, you need to log in to your YouTube/Google account.'**
  String get youtubeLoginDescription1;

  /// No description provided for @youtubeLoginDescription2.
  ///
  /// In en, this message translates to:
  /// **'This allows the app to access video content properly.'**
  String get youtubeLoginDescription2;

  /// No description provided for @youtubeLoginQuestion.
  ///
  /// In en, this message translates to:
  /// **'Would you like to log in now?'**
  String get youtubeLoginQuestion;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get logIn;

  /// No description provided for @savingProgress.
  ///
  /// In en, this message translates to:
  /// **'Saving progress...'**
  String get savingProgress;

  /// No description provided for @progressSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Progress saved successfully'**
  String get progressSavedSuccessfully;

  /// No description provided for @failedToSaveSettings.
  ///
  /// In en, this message translates to:
  /// **'Failed to save settings'**
  String get failedToSaveSettings;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get themeMode;

  /// No description provided for @themeSettings.
  ///
  /// In en, this message translates to:
  /// **'Theme Settings'**
  String get themeSettings;

  /// No description provided for @alwaysUseLight.
  ///
  /// In en, this message translates to:
  /// **'Always use light theme'**
  String get alwaysUseLight;

  /// No description provided for @alwaysUseDark.
  ///
  /// In en, this message translates to:
  /// **'Always use dark theme'**
  String get alwaysUseDark;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system setting'**
  String get followSystem;

  /// No description provided for @switchToLight.
  ///
  /// In en, this message translates to:
  /// **'Switch to Light Mode'**
  String get switchToLight;

  /// No description provided for @switchToDark.
  ///
  /// In en, this message translates to:
  /// **'Switch to Dark Mode'**
  String get switchToDark;

  /// No description provided for @failedToSaveProgress.
  ///
  /// In en, this message translates to:
  /// **'Failed to save progress'**
  String get failedToSaveProgress;

  /// No description provided for @videoNotReady.
  ///
  /// In en, this message translates to:
  /// **'Video player not ready. Please wait and try again.'**
  String get videoNotReady;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @transcriptNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Transcript Not Available'**
  String get transcriptNotAvailable;

  /// No description provided for @transcriptNotAvailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This video may not have transcript data available yet, or there might be a network issue.'**
  String get transcriptNotAvailableMessage;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @youHaveCompleted.
  ///
  /// In en, this message translates to:
  /// **'You have completed this dictation exercise!'**
  String get youHaveCompleted;

  /// No description provided for @accuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get accuracy;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get minutes;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @loadingDictation.
  ///
  /// In en, this message translates to:
  /// **'Loading dictation resource...'**
  String get loadingDictation;

  /// No description provided for @loginToYoutube.
  ///
  /// In en, this message translates to:
  /// **'Login to YouTube'**
  String get loginToYoutube;

  /// No description provided for @resetProgress.
  ///
  /// In en, this message translates to:
  /// **'Reset Progress'**
  String get resetProgress;

  /// No description provided for @playbackSettings.
  ///
  /// In en, this message translates to:
  /// **'Playback Settings'**
  String get playbackSettings;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback Speed'**
  String get playbackSpeed;

  /// No description provided for @autoRepeat.
  ///
  /// In en, this message translates to:
  /// **'Auto Repeat'**
  String get autoRepeat;

  /// No description provided for @repeatCount.
  ///
  /// In en, this message translates to:
  /// **'Repeat Count'**
  String get repeatCount;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @settingsSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully'**
  String get settingsSavedSuccessfully;

  /// No description provided for @resetProgressConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset your progress for this video?'**
  String get resetProgressConfirm;

  /// No description provided for @thisWill.
  ///
  /// In en, this message translates to:
  /// **'This will:'**
  String get thisWill;

  /// No description provided for @clearAllInputs.
  ///
  /// In en, this message translates to:
  /// **'• Clear all your text inputs'**
  String get clearAllInputs;

  /// No description provided for @resetToBeginning.
  ///
  /// In en, this message translates to:
  /// **'• Reset your position to the beginning'**
  String get resetToBeginning;

  /// No description provided for @loseAllProgress.
  ///
  /// In en, this message translates to:
  /// **'• You will lose all progress for this video'**
  String get loseAllProgress;

  /// No description provided for @cannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get cannotBeUndone;

  /// No description provided for @resetting.
  ///
  /// In en, this message translates to:
  /// **'Resetting...'**
  String get resetting;

  /// No description provided for @resetCompleted.
  ///
  /// In en, this message translates to:
  /// **'Reset completed'**
  String get resetCompleted;

  /// No description provided for @resetFailed.
  ///
  /// In en, this message translates to:
  /// **'Reset failed'**
  String get resetFailed;

  /// No description provided for @sentenceOf.
  ///
  /// In en, this message translates to:
  /// **'Sentence {current} of {total}'**
  String sentenceOf(int current, int total);

  /// No description provided for @hideComparison.
  ///
  /// In en, this message translates to:
  /// **'Hide comparison'**
  String get hideComparison;

  /// No description provided for @showComparison.
  ///
  /// In en, this message translates to:
  /// **'Show comparison'**
  String get showComparison;

  /// No description provided for @original.
  ///
  /// In en, this message translates to:
  /// **'Original:'**
  String get original;

  /// No description provided for @typeWhatYouHear.
  ///
  /// In en, this message translates to:
  /// **'Type what you hear...'**
  String get typeWhatYouHear;

  /// No description provided for @loginRequired.
  ///
  /// In en, this message translates to:
  /// **'Login Required'**
  String get loginRequired;

  /// No description provided for @loginRequiredDescription.
  ///
  /// In en, this message translates to:
  /// **'You need to sign in to access video content and track your progress'**
  String get loginRequiredDescription;

  /// No description provided for @totalTime.
  ///
  /// In en, this message translates to:
  /// **'Total Time'**
  String get totalTime;

  /// No description provided for @expires.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get expires;

  /// No description provided for @plan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get plan;

  /// No description provided for @noLimit.
  ///
  /// In en, this message translates to:
  /// **'No Limit'**
  String get noLimit;

  /// No description provided for @dictationActivities.
  ///
  /// In en, this message translates to:
  /// **'Dictation Activities'**
  String get dictationActivities;

  /// No description provided for @loadingChannels.
  ///
  /// In en, this message translates to:
  /// **'Loading channels...'**
  String get loadingChannels;

  /// No description provided for @loadingVideos.
  ///
  /// In en, this message translates to:
  /// **'Loading videos...'**
  String get loadingVideos;

  /// No description provided for @unableToLoadChannels.
  ///
  /// In en, this message translates to:
  /// **'Unable to load channels'**
  String get unableToLoadChannels;

  /// No description provided for @unableToLoadVideos.
  ///
  /// In en, this message translates to:
  /// **'Unable to load videos'**
  String get unableToLoadVideos;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @noChannelsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No channels available'**
  String get noChannelsAvailable;

  /// No description provided for @checkBackLater.
  ///
  /// In en, this message translates to:
  /// **'Check back later for new content'**
  String get checkBackLater;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// No description provided for @tryAdjustingSearch.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search or filter'**
  String get tryAdjustingSearch;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @searchChannels.
  ///
  /// In en, this message translates to:
  /// **'Search channels...'**
  String get searchChannels;

  /// No description provided for @searchVideos.
  ///
  /// In en, this message translates to:
  /// **'Search videos...'**
  String get searchVideos;

  /// No description provided for @languageFilter.
  ///
  /// In en, this message translates to:
  /// **'Language Filter'**
  String get languageFilter;

  /// No description provided for @filterByLanguage.
  ///
  /// In en, this message translates to:
  /// **'Filter by Language'**
  String get filterByLanguage;

  /// No description provided for @allLanguages.
  ///
  /// In en, this message translates to:
  /// **'All Languages'**
  String get allLanguages;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get chinese;

  /// No description provided for @traditionalChinese.
  ///
  /// In en, this message translates to:
  /// **'Traditional Chinese'**
  String get traditionalChinese;

  /// No description provided for @japanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get japanese;

  /// No description provided for @korean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get korean;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @sortVideos.
  ///
  /// In en, this message translates to:
  /// **'Sort Videos'**
  String get sortVideos;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @alphabetical.
  ///
  /// In en, this message translates to:
  /// **'Alphabetical'**
  String get alphabetical;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get inProgress;

  /// No description provided for @notStarted.
  ///
  /// In en, this message translates to:
  /// **'Not Started'**
  String get notStarted;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'completed'**
  String get completed;

  /// No description provided for @noVideosFound.
  ///
  /// In en, this message translates to:
  /// **'No videos found'**
  String get noVideosFound;

  /// No description provided for @noVideosAvailable.
  ///
  /// In en, this message translates to:
  /// **'No videos available'**
  String get noVideosAvailable;

  /// No description provided for @noVideosMatchFilter.
  ///
  /// In en, this message translates to:
  /// **'No videos match your search and progress filter'**
  String get noVideosMatchFilter;

  /// No description provided for @tryAdjustingTerms.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search terms'**
  String get tryAdjustingTerms;

  /// No description provided for @noCompletedVideos.
  ///
  /// In en, this message translates to:
  /// **'No completed videos yet'**
  String get noCompletedVideos;

  /// No description provided for @noVideosInProgress.
  ///
  /// In en, this message translates to:
  /// **'No videos in progress'**
  String get noVideosInProgress;

  /// No description provided for @noUnstartedVideos.
  ///
  /// In en, this message translates to:
  /// **'No unstarted videos'**
  String get noUnstartedVideos;

  /// No description provided for @channelDoesntHaveVideos.
  ///
  /// In en, this message translates to:
  /// **'This channel doesn\'t have any videos yet'**
  String get channelDoesntHaveVideos;

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get stats;

  /// No description provided for @channelsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} channels'**
  String channelsCount(int count);

  /// No description provided for @videosCount.
  ///
  /// In en, this message translates to:
  /// **'{count} videos'**
  String videosCount(int count);

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @dictationProgress.
  ///
  /// In en, this message translates to:
  /// **'Dictation Progress'**
  String get dictationProgress;

  /// No description provided for @noProgressDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No dictation progress available'**
  String get noProgressDataAvailable;

  /// No description provided for @startDictationToSeeProgress.
  ///
  /// In en, this message translates to:
  /// **'Start practicing dictation to see your progress here'**
  String get startDictationToSeeProgress;

  /// No description provided for @selectChannelToViewProgress.
  ///
  /// In en, this message translates to:
  /// **'Select a channel to view progress'**
  String get selectChannelToViewProgress;

  /// No description provided for @loadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load data'**
  String get loadError;

  /// No description provided for @viewYourDictationHistory.
  ///
  /// In en, this message translates to:
  /// **'View your dictation practice history and progress'**
  String get viewYourDictationHistory;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
