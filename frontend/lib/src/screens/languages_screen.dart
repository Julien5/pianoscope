import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/user_settings_provider.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  void _setLocale(UserSettingsProvider userSettings, String value) async {
    await userSettings.setLocale(value);
  }

  @override
  Widget build(BuildContext context) {
    UserSettingsProvider userSettings = context.watch();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ListTile(
          leading: const Icon(Icons.flag),
          title: const Text('English'),
          onTap: () {
            _setLocale(userSettings, 'en');
            GoRouter.of(context).pop();
          },
        ),

        ListTile(
          leading: const Icon(Icons.flag),
          title: const Text('Francais'),
          onTap: () {
            _setLocale(userSettings, 'fr');
            GoRouter.of(context).pop();
          },
        ),

        ListTile(
          leading: const Icon(Icons.flag),
          title: const Text('Deutsch'),
          onTap: () {
            _setLocale(userSettings, 'de');
            GoRouter.of(context).pop();
          },
        ),
      ],
    );
  }
}
