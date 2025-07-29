// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Dictation Studio';

  @override
  String get profile => 'Profile';

  @override
  String get channels => 'Channels';

  @override
  String get videos => 'Videos';

  @override
  String get admin => 'Admin';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get systemTheme => 'System';

  @override
  String get signIn => 'Sign In';

  @override
  String get signOut => 'Sign Out';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get welcome => 'Welcome to Dictation Studio';

  @override
  String get signInToAccess =>
      'Sign in to access your personalized learning dashboard';

  @override
  String get loginRequired => 'Login Required';

  @override
  String get loginRequiredDescription =>
      'You need to sign in to access video content and track your progress';

  @override
  String get totalTime => 'Total Time';

  @override
  String get expires => 'Expires';

  @override
  String get plan => 'Plan';

  @override
  String get noLimit => 'No Limit';

  @override
  String get dictationActivities => 'Dictation Activities';

  @override
  String get loadingChannels => 'Loading channels...';

  @override
  String get loadingVideos => 'Loading videos...';

  @override
  String get unableToLoadChannels => 'Unable to load channels';

  @override
  String get unableToLoadVideos => 'Unable to load videos';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get refresh => 'Refresh';

  @override
  String get noChannelsAvailable => 'No channels available';

  @override
  String get checkBackLater => 'Check back later for new content';

  @override
  String get noResultsFound => 'No results found';

  @override
  String get tryAdjustingSearch => 'Try adjusting your search or filter';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get searchChannels => 'Search channels...';

  @override
  String get searchVideos => 'Search videos...';

  @override
  String get languageFilter => 'Language Filter';

  @override
  String get filterByLanguage => 'Filter by Language';

  @override
  String get allLanguages => 'All Languages';

  @override
  String get english => 'English';

  @override
  String get chinese => 'Chinese';

  @override
  String get japanese => 'Japanese';

  @override
  String get korean => 'Korean';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get sortVideos => 'Sort Videos';

  @override
  String get recent => 'Recent';

  @override
  String get alphabetical => 'Alphabetical';

  @override
  String get progress => 'Progress';

  @override
  String get done => 'Done';

  @override
  String get inProgress => 'In Progress';

  @override
  String get notStarted => 'Not Started';

  @override
  String get completed => 'Completed';

  @override
  String get noVideosFound => 'No videos found';

  @override
  String get noVideosAvailable => 'No videos available';

  @override
  String get noVideosMatchFilter =>
      'No videos match your search and progress filter';

  @override
  String get tryAdjustingTerms => 'Try adjusting your search terms';

  @override
  String get noCompletedVideos => 'No completed videos yet';

  @override
  String get noVideosInProgress => 'No videos in progress';

  @override
  String get noUnstartedVideos => 'No unstarted videos';

  @override
  String get channelDoesntHaveVideos =>
      'This channel doesn\'t have any videos yet';

  @override
  String get stats => 'Stats';

  @override
  String channelsCount(int count) {
    return '$count channels';
  }

  @override
  String videosCount(int count) {
    return '$count videos';
  }
}
