import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/locale_provider.dart';

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
                SizedBox(height: 8),
                Text(
                  'Language',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ],
            ),
          ),

          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text('English'),
            onTap: () {
              localeProvider.setLocale(const Locale('en'));
              Navigator.pop(context); // Close the menu
            },
          ),

          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text('Francais'),
            onTap: () {
              localeProvider.setLocale(const Locale('fr'));
              Navigator.pop(context); // Close the menu
            },
          ),

          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text('Deutsch'),
            onTap: () {
              localeProvider.setLocale(const Locale('de'));
              Navigator.pop(context); // Close the menu
            },
          ),
        ],
      ),
    );
  }
}
