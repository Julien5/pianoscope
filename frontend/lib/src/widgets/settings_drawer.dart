import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../routes.dart';

class SettingsDrawer extends StatelessWidget {
  final bool hasSmallHeader;
  const SettingsDrawer({super.key, required this.hasSmallHeader});

  @override
  Widget build(BuildContext context) {
    Widget normalHeader = DrawerHeader(
      decoration: BoxDecoration(color: Colors.blue),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Pianoscope',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ],
      ),
    );

    Widget smallHeader = SizedBox(
      height: 80,
      child: DrawerHeader(
        decoration: BoxDecoration(color: Colors.blue),
        margin: EdgeInsetsGeometry.all(0),
        padding: EdgeInsetsGeometry.all(0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pianoscope',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ],
        ),
      ),
    );
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          hasSmallHeader ? smallHeader : normalHeader,
          ListTile(
            leading: const Icon(Icons.device_hub),
            title: Text(AppLocalizations.of(context)!.selectInput),
            onTap: () {
              Scaffold.of(context).closeDrawer();
              GoRouter.of(context).go(Routes.devices);
            },
          ),

          /*
          ListTile(
            leading: const Icon(Icons.music_note),
            title: Text(AppLocalizations.of(context)!.selectClef),
            onTap: () {
              Scaffold.of(context).closeDrawer();
              GoRouter.of(context).push(Routes.clefs);
            },
          ),*/
          ListTile(
            leading: const Icon(Icons.flag),
            title: Text(AppLocalizations.of(context)!.languages),
            onTap: () {
              Scaffold.of(context).closeDrawer();
              GoRouter.of(context).push(Routes.languages);
            },
          ),
        ],
      ),
    );
  }
}
