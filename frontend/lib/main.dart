// ignore_for_file: constant_identifier_names

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'pianoscope.dart';

import 'l10n/app_localizations.dart';
import 'src/providers/locale_provider.dart';
import 'src/routes.dart';
import 'src/style.dart';

const Size portrait_tight = Size(360, 844);
const Size portrait_square = Size(672, 960);
const Size portrait_pixel6a = Size(412, 915);

const Size landscape_tight = Size(844, 360);
const Size landscape_square = Size(1280, 800);
const Size landscape_pixel6a = Size(412, 915);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(size: portrait_tight, center: true),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
  await RustLib.init();
  final provider = InputProvider();
  await provider.init();
  debugPrint("provided init done");

  final userSettings = UserSettingsProvider();
  await userSettings.init();
  runApp(ChangeNotifierProvider.value(value: provider, child: NanoApp(userSettings: userSettings,)));
}

class NanoApp extends StatelessWidget {
  final UserSettingsProvider userSettings;
  const NanoApp({super.key, required this.userSettings});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: userSettings,
      child: Consumer<UserSettingsProvider>(
        builder: (context, localeProvider, child) {
          return MaterialApp.router(
            title: 'Pianoscope',
            locale: localeProvider.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.lightTheme,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
