// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '听写工作室';

  @override
  String get profile => '个人中心';

  @override
  String get channels => '频道';

  @override
  String get videos => '视频';

  @override
  String get admin => '管理';

  @override
  String get settings => '设置';

  @override
  String get language => '语言';

  @override
  String get theme => '主题';

  @override
  String get darkMode => '深色模式';

  @override
  String get lightMode => '浅色模式';

  @override
  String get systemTheme => '系统';

  @override
  String get signIn => '登录';

  @override
  String get signOut => '退出登录';

  @override
  String get email => '邮箱';

  @override
  String get password => '密码';

  @override
  String get forgotPassword => '忘记密码？';

  @override
  String get welcome => '欢迎使用听写工作室';

  @override
  String get signInToAccess => '登录以访问您的个性化学习仪表板';

  @override
  String get loginRequired => '需要登录';

  @override
  String get loginRequiredDescription => '您需要登录才能访问视频内容并跟踪学习进度';

  @override
  String get totalTime => '总时长';

  @override
  String get expires => '到期时间';

  @override
  String get plan => '套餐';

  @override
  String get noLimit => '无限制';

  @override
  String get dictationActivities => '听写活动';

  @override
  String get loadingChannels => '加载频道中...';

  @override
  String get loadingVideos => '加载视频中...';

  @override
  String get unableToLoadChannels => '无法加载频道';

  @override
  String get unableToLoadVideos => '无法加载视频';

  @override
  String get tryAgain => '重试';

  @override
  String get refresh => '刷新';

  @override
  String get noChannelsAvailable => '暂无可用频道';

  @override
  String get checkBackLater => '稍后再来查看新内容';

  @override
  String get noResultsFound => '未找到结果';

  @override
  String get tryAdjustingSearch => '尝试调整您的搜索或筛选条件';

  @override
  String get clearFilters => '清除筛选';

  @override
  String get searchChannels => '搜索频道...';

  @override
  String get searchVideos => '搜索视频...';

  @override
  String get languageFilter => '语言筛选';

  @override
  String get filterByLanguage => '按语言筛选';

  @override
  String get allLanguages => '所有语言';

  @override
  String get english => '英语';

  @override
  String get chinese => '中文';

  @override
  String get japanese => '日语';

  @override
  String get korean => '韩语';

  @override
  String get selectLanguage => '选择语言';

  @override
  String get sortVideos => '视频排序';

  @override
  String get recent => '最近';

  @override
  String get alphabetical => '字母顺序';

  @override
  String get progress => '进度';

  @override
  String get done => '已完成';

  @override
  String get inProgress => '进行中';

  @override
  String get notStarted => '未开始';

  @override
  String get completed => '已完成';

  @override
  String get noVideosFound => '未找到视频';

  @override
  String get noVideosAvailable => '暂无可用视频';

  @override
  String get noVideosMatchFilter => '没有视频匹配您的搜索和进度筛选';

  @override
  String get tryAdjustingTerms => '尝试调整您的搜索条件';

  @override
  String get noCompletedVideos => '暂无已完成的视频';

  @override
  String get noVideosInProgress => '暂无进行中的视频';

  @override
  String get noUnstartedVideos => '暂无未开始的视频';

  @override
  String get channelDoesntHaveVideos => '该频道暂时没有任何视频';

  @override
  String get stats => '统计';

  @override
  String channelsCount(int count) {
    return '$count 个频道';
  }

  @override
  String videosCount(int count) {
    return '$count 个视频';
  }
}
