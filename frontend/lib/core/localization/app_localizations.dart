import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'profile': 'Profile',
      'settings': 'Settings',
      'language': 'Language',
      'theme': 'Theme',
      'theme_mode': 'Theme',
      'dark_mode': 'Dark',
      'light_mode': 'Light',
      'system_default': 'System Default',
      'english': 'English',
      'chinese': '中文',
      'my_lens': 'My Lens',
      'my_post': 'My Post',
      'favorite': 'Favorite',
      'edit_profile': 'Edit Profile',
      'lens': 'Lens',
      'posts': 'Posts',
      'likes': 'Likes',
      'uses': 'uses',
      'appearance': 'Appearance',
      'general': 'General',
      'good_morning': 'Good morning, Creator',
      'my_recent_lens': 'My Recent Lens',
      'trending_templates': 'Trending Templates',
      'topics_and_challenges': 'Topics & Challenges',
      'view_all': 'View All',
      'filter': 'Filter',
      'discover': 'Discover',
      'messages': 'Messages',
      'search': 'Search',
    },
    'zh': {
      'profile': '个人主页',
      'settings': '设置',
      'language': '语言',
      'theme': '主题',
      'theme_mode': '主题',
      'dark_mode': '深色',
      'light_mode': '浅色',
      'system_default': '跟随系统',
      'english': 'English',
      'chinese': '中文',
      'my_lens': '我的滤镜',
      'my_post': '我的帖子',
      'favorite': '收藏夹',
      'edit_profile': '编辑资料',
      'lens': '滤镜',
      'posts': '帖子',
      'likes': '获赞',
      'uses': '次使用',
      'appearance': '外观',
      'general': '通用',
      'good_morning': '早上好，创作者',
      'my_recent_lens': '我最近使用的滤镜',
      'trending_templates': '热门模板',
      'topics_and_challenges': '话题与挑战',
      'view_all': '查看全部',
      'filter': '筛选',
      'discover': '发现',
      'messages': '消息',
      'search': '搜索',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// 扩展方便调用
extension AppLocalizationsExtension on BuildContext {
  String tr(String key) {
    return AppLocalizations.of(this)?.translate(key) ?? key;
  }
}
