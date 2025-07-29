// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appName => '딕테이션 스튜디오';

  @override
  String get profile => '프로필';

  @override
  String get channels => '채널';

  @override
  String get videos => '비디오';

  @override
  String get admin => '관리';

  @override
  String get settings => '설정';

  @override
  String get language => '언어';

  @override
  String get theme => '테마';

  @override
  String get darkMode => '다크 모드';

  @override
  String get lightMode => '라이트 모드';

  @override
  String get systemTheme => '시스템';

  @override
  String get signIn => '로그인';

  @override
  String get signOut => '로그아웃';

  @override
  String get email => '이메일';

  @override
  String get password => '비밀번호';

  @override
  String get forgotPassword => '비밀번호를 잊으셨나요?';

  @override
  String get welcome => '딕테이션 스튜디오에 오신 것을 환영합니다';

  @override
  String get signInToAccess => '개인화된 학습 대시보드에 액세스하려면 로그인하세요';

  @override
  String get loginRequired => '로그인 필요';

  @override
  String get loginRequiredDescription =>
      '비디오 콘텐츠에 액세스하고 진행 상황을 추적하려면 로그인해야 합니다';

  @override
  String get totalTime => '총 시간';

  @override
  String get expires => '만료일';

  @override
  String get plan => '플랜';

  @override
  String get noLimit => '제한 없음';

  @override
  String get dictationActivities => '딕테이션 활동';

  @override
  String get loadingChannels => '채널 로딩 중...';

  @override
  String get loadingVideos => '비디오 로딩 중...';

  @override
  String get unableToLoadChannels => '채널을 로드할 수 없습니다';

  @override
  String get unableToLoadVideos => '비디오를 로드할 수 없습니다';

  @override
  String get tryAgain => '다시 시도';

  @override
  String get refresh => '새로고침';

  @override
  String get noChannelsAvailable => '사용 가능한 채널이 없습니다';

  @override
  String get checkBackLater => '나중에 새 콘텐츠를 확인하세요';

  @override
  String get noResultsFound => '결과를 찾을 수 없습니다';

  @override
  String get tryAdjustingSearch => '검색 또는 필터를 조정해 보세요';

  @override
  String get clearFilters => '필터 지우기';

  @override
  String get searchChannels => '채널 검색...';

  @override
  String get searchVideos => '비디오 검색...';

  @override
  String get languageFilter => '언어 필터';

  @override
  String get filterByLanguage => '언어로 필터링';

  @override
  String get allLanguages => '모든 언어';

  @override
  String get english => '영어';

  @override
  String get chinese => '중국어';

  @override
  String get japanese => '일본어';

  @override
  String get korean => '한국어';

  @override
  String get selectLanguage => '언어 선택';

  @override
  String get sortVideos => '비디오 정렬';

  @override
  String get recent => '최근';

  @override
  String get alphabetical => '알파벳순';

  @override
  String get progress => '진행률';

  @override
  String get done => '완료';

  @override
  String get inProgress => '진행 중';

  @override
  String get notStarted => '시작 안 함';

  @override
  String get completed => '완료됨';

  @override
  String get noVideosFound => '비디오를 찾을 수 없습니다';

  @override
  String get noVideosAvailable => '사용 가능한 비디오가 없습니다';

  @override
  String get noVideosMatchFilter => '검색 및 진행 상황 필터와 일치하는 비디오가 없습니다';

  @override
  String get tryAdjustingTerms => '검색 조건을 조정해 보세요';

  @override
  String get noCompletedVideos => '완료된 비디오가 아직 없습니다';

  @override
  String get noVideosInProgress => '진행 중인 비디오가 없습니다';

  @override
  String get noUnstartedVideos => '시작하지 않은 비디오가 없습니다';

  @override
  String get channelDoesntHaveVideos => '이 채널에는 아직 비디오가 없습니다';

  @override
  String get stats => '통계';

  @override
  String channelsCount(int count) {
    return '$count개 채널';
  }

  @override
  String videosCount(int count) {
    return '$count개 비디오';
  }
}
