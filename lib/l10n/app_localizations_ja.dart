// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'ディクテーションスタジオ';

  @override
  String get profile => 'プロフィール';

  @override
  String get channels => 'チャンネル';

  @override
  String get videos => 'ビデオ';

  @override
  String get admin => '管理';

  @override
  String get settings => '設定';

  @override
  String get language => '言語';

  @override
  String get theme => 'テーマ';

  @override
  String get darkMode => 'ダークモード';

  @override
  String get lightMode => 'ライトモード';

  @override
  String get systemTheme => 'システム';

  @override
  String get signIn => 'サインイン';

  @override
  String get signOut => 'サインアウト';

  @override
  String get email => 'メール';

  @override
  String get password => 'パスワード';

  @override
  String get forgotPassword => 'パスワードを忘れた場合';

  @override
  String get welcome => 'ディクテーションスタジオへようこそ';

  @override
  String get signInToAccess => 'パーソナライズされた学習ダッシュボードにアクセスするにはサインインしてください';

  @override
  String get loginRequired => 'ログインが必要';

  @override
  String get loginRequiredDescription => 'ビデオコンテンツにアクセスして進捗を追跡するにはサインインが必要です';

  @override
  String get totalTime => '合計時間';

  @override
  String get expires => '有効期限';

  @override
  String get plan => 'プラン';

  @override
  String get noLimit => '制限なし';

  @override
  String get dictationActivities => 'ディクテーション活動';

  @override
  String get loadingChannels => 'チャンネルを読み込み中...';

  @override
  String get loadingVideos => 'ビデオを読み込み中...';

  @override
  String get unableToLoadChannels => 'チャンネルを読み込めません';

  @override
  String get unableToLoadVideos => 'ビデオを読み込めません';

  @override
  String get tryAgain => '再試行';

  @override
  String get refresh => '更新';

  @override
  String get noChannelsAvailable => '利用可能なチャンネルがありません';

  @override
  String get checkBackLater => '後で新しいコンテンツをチェックしてください';

  @override
  String get noResultsFound => '結果が見つかりません';

  @override
  String get tryAdjustingSearch => '検索またはフィルターを調整してみてください';

  @override
  String get clearFilters => 'フィルターをクリア';

  @override
  String get searchChannels => 'チャンネルを検索...';

  @override
  String get searchVideos => 'ビデオを検索...';

  @override
  String get languageFilter => '言語フィルター';

  @override
  String get filterByLanguage => '言語でフィルター';

  @override
  String get allLanguages => 'すべての言語';

  @override
  String get english => '英語';

  @override
  String get chinese => '中国語';

  @override
  String get japanese => '日本語';

  @override
  String get korean => '韓国語';

  @override
  String get selectLanguage => '言語を選択';

  @override
  String get sortVideos => 'ビデオを並び替え';

  @override
  String get recent => '最近';

  @override
  String get alphabetical => 'アルファベット順';

  @override
  String get progress => '進捗';

  @override
  String get done => '完了';

  @override
  String get inProgress => '進行中';

  @override
  String get notStarted => '未開始';

  @override
  String get completed => '完了済み';

  @override
  String get noVideosFound => 'ビデオが見つかりません';

  @override
  String get noVideosAvailable => '利用可能なビデオがありません';

  @override
  String get noVideosMatchFilter => '検索と進捗フィルターに一致するビデオがありません';

  @override
  String get tryAdjustingTerms => '検索条件を調整してみてください';

  @override
  String get noCompletedVideos => '完了したビデオはまだありません';

  @override
  String get noVideosInProgress => '進行中のビデオがありません';

  @override
  String get noUnstartedVideos => '未開始のビデオがありません';

  @override
  String get channelDoesntHaveVideos => 'このチャンネルにはまだビデオがありません';

  @override
  String get stats => '統計';

  @override
  String channelsCount(int count) {
    return '$count チャンネル';
  }

  @override
  String videosCount(int count) {
    return '$count ビデオ';
  }
}
