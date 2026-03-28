import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/localization/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? Colors.white : Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('settings'),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildSectionHeader(context.tr('appearance')),
          const SizedBox(height: 8),
          _buildSettingsCard(
            context: context,
            children: [
              _buildThemeOption(
                context: context,
                ref: ref,
                title: context.tr('dark_mode'),
                mode: ThemeMode.dark,
                currentMode: settings.themeMode,
                icon: Icons.dark_mode_rounded,
                isTop: true,
              ),
              _buildDivider(isDark),
              _buildThemeOption(
                context: context,
                ref: ref,
                title: context.tr('light_mode'),
                mode: ThemeMode.light,
                currentMode: settings.themeMode,
                icon: Icons.light_mode_rounded,
                isTop: false,
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildSectionHeader(context.tr('language')),
          const SizedBox(height: 8),
          _buildSettingsCard(
            context: context,
            children: [
              _buildLanguageOption(
                context: context,
                ref: ref,
                title: 'English',
                locale: const Locale('en'),
                currentLocale: settings.locale,
                isTop: true,
              ),
              _buildDivider(isDark),
              _buildLanguageOption(
                context: context,
                ref: ref,
                title: '中文',
                locale: const Locale('zh'),
                currentLocale: settings.locale,
                isTop: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required BuildContext context,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required ThemeMode mode,
    required ThemeMode currentMode,
    required IconData icon,
    required bool isTop,
  }) {
    final isSelected = mode == currentMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: isTop ? const Radius.circular(16) : Radius.zero,
          bottom: !isTop ? const Radius.circular(16) : Radius.zero,
        ),
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).primaryColor.withOpacity(0.15)
              : isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected 
              ? Theme.of(context).primaryColor 
              : isDark ? Colors.white70 : Colors.black54,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: Theme.of(context).primaryColor)
          : null,
      onTap: () {
        ref.read(settingsProvider.notifier).updateThemeMode(mode);
      },
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required Locale locale,
    required Locale currentLocale,
    required bool isTop,
  }) {
    final isSelected = locale.languageCode == currentLocale.languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: isTop ? const Radius.circular(16) : Radius.zero,
          bottom: !isTop ? const Radius.circular(16) : Radius.zero,
        ),
      ),
      title: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: Theme.of(context).primaryColor)
          : null,
      onTap: () {
        ref.read(settingsProvider.notifier).updateLocale(locale);
      },
    );
  }
}
