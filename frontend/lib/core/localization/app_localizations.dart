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
      // Auth
      'login': 'Login',
      'register': 'Register',
      'username': 'Username',
      'password': 'Password',
      'confirm_password': 'Confirm Password',
      'nickname': 'Nickname',
      'email': 'Email',
      'bio': 'Bio',
      'login_button': 'Log In',
      'register_button': 'Sign Up',
      'no_account': "Don't have an account?",
      'have_account': 'Already have an account?',
      'login_error': 'Incorrect username or password',
      'register_error_username': 'Username already exists',
      'register_error_email': 'Email already registered',
      // Profile
      'save': 'Save',
      'avatar_url': 'Avatar URL',
      'banner_url': 'Banner URL',
      'followers': 'Followers',
      'following': 'Following',
      'follow': 'Follow',
      'unfollow': 'Unfollow',
      'following_state': 'Following',
      'logout': 'Log Out',
      'guest_user': 'Guest',
      'login_to_view': 'Log in to view your content',
      'login_prompt': 'Log in to unlock all features',
      'profile_updated': 'Profile updated',
      'password_mismatch': 'Passwords do not match',
      'field_required': 'This field is required',
      'register_success': 'Registration successful',
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
      // Auth
      'login': '登录',
      'register': '注册',
      'username': '用户名',
      'password': '密码',
      'confirm_password': '确认密码',
      'nickname': '昵称',
      'email': '邮箱',
      'bio': '个人简介',
      'login_button': '登录',
      'register_button': '注册',
      'no_account': '还没有账号？',
      'have_account': '已有账号？',
      'login_error': '用户名或密码错误',
      'register_error_username': '用户名已存在',
      'register_error_email': '邮箱已被注册',
      // Profile
      'save': '保存',
      'avatar_url': '头像链接',
      'banner_url': '横幅链接',
      'followers': '粉丝',
      'following': '关注',
      'follow': '关注',
      'unfollow': '取消关注',
      'following_state': '已关注',
      'logout': '退出登录',
      'guest_user': '访客用户',
      'login_to_view': '登录后查看你的内容',
      'login_prompt': '登录以解锁全部功能',
      'profile_updated': '资料已更新',
      'password_mismatch': '两次输入的密码不一致',
      'field_required': '此项为必填',
      'register_success': '注册成功',
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
