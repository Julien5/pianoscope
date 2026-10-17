import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../routes.dart';
import '../style.dart';

class SettingsDrawer extends StatelessWidget {
  final bool hasSmallHeader;
  const SettingsDrawer({super.key, required this.hasSmallHeader});

  Widget _header({required bool compact}) {
    // mainAxisAlignment.end needs a bounded height, which both the SizedBox
    // and DrawerHeader supply.
    const title = Text('Pianoscope', style: AppDrawerStyle.brandTextStyle);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppDrawerStyle.headerGradient,
        ),
      ),
      child: compact
          ? SizedBox(
              height: AppDrawerStyle.smallHeaderHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title],
                ),
              ),
            )
          : DrawerHeader(
              margin: EdgeInsets.zero,
              decoration: const BoxDecoration(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title],
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(compact: hasSmallHeader),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              children: [
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
          ),
        ],
      ),
    );
  }
}
