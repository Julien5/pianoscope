import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/user_settings_provider.dart';
import '../style.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  void _setLocale(UserSettingsProvider userSettings, String value) async {
    await userSettings.setLocale(value);
  }

  @override
  Widget build(BuildContext context) {
    final userSettings = context.watch<UserSettingsProvider>();
    final activeLanguage = userSettings.locale.languageCode;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        _LanguageTile(
          label: 'English',
          isActive: activeLanguage == 'en',
          onTap: () {
            _setLocale(userSettings, 'en');
            GoRouter.of(context).pop();
          },
        ),
        _LanguageTile(
          label: 'Français',
          isActive: activeLanguage == 'fr',
          onTap: () {
            _setLocale(userSettings, 'fr');
            GoRouter.of(context).pop();
          },
        ),
        _LanguageTile(
          label: 'Deutsch',
          isActive: activeLanguage == 'de',
          onTap: () {
            _setLocale(userSettings, 'de');
            GoRouter.of(context).pop();
          },
        ),
      ],
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.flag),
        title: Text(label),
        trailing: isActive
            ? const Icon(Icons.check, color: AppColors.primary, size: 20)
            : null,
        onTap: onTap,
      ),
    );
  }
}
