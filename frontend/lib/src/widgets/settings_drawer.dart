import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/locale_provider.dart';
import '../routes.dart';

class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: true);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Drawer Header / Title section
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Language',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ],
            ),
          ),

          ListTile(
            leading: const Icon(Icons.device_hub),
            title: const Text('Devices'),
            onTap: () {
              Scaffold.of(context).closeDrawer();
              GoRouter.of(context).go(Routes.devices);
            },
          ),

          ListTile(
            leading: const Icon(Icons.music_note),
            title: const Text('Clefs'),
            onTap: () {
              Scaffold.of(context).closeDrawer();
              debugPrint("go to clefs");
              GoRouter.of(context).go(Routes.clefs);
            },
          ),

          ListTile(title: const Divider()),

          ListTile(title: const Text("Languages")),

          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text('English'),
            onTap: () {
              localeProvider.setLocale(const Locale('en'));
              Scaffold.of(context).closeDrawer();
            },
          ),

          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text('Francais'),
            onTap: () {
              localeProvider.setLocale(const Locale('fr'));
              Scaffold.of(context).closeDrawer();
            },
          ),

          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text('Deutsch'),
            onTap: () {
              localeProvider.setLocale(const Locale('de'));
              Scaffold.of(context).closeDrawer();
            },
          ),
        ],
      ),
    );
  }
}
