import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pianoscope/l10n/app_localizations.dart';
import 'package:pianoscope/pianoscope.dart';
import 'package:pianoscope/src/providers/user_settings_provider.dart';
import 'package:pianoscope/src/routes.dart';
import 'package:pianoscope/src/widgets/feedback_dialog.dart';
import 'package:pianoscope/src/widgets/feedback_hero_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helper.dart';

Future<UserSettingsProvider> newSettings() async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final settings = UserSettingsProvider();
  await settings.init();
  return settings;
}

void main() {
  // Opening the feedback dialog builds an UploadSession, which lives in Rust.
  RustLib.initMock(api: FakeRustLibApi());

  testWidgets('the hero button opens the dialog in feedback mode', (
    tester,
  ) async {
    final settings = await newSettings();
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: settings)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(floatingActionButton: const FeedbackHeroButton()),
        ),
      ),
    );

    await tester.tap(find.byType(FeedbackHeroButton));
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackDialog), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(CheckboxListTile), findsOneWidget);
  });

  testWidgets('the shell exposes the hero button', (tester) async {
    final settings = await newSettings();
    router.go(Routes.languages);
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: settings)],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackHeroButton), findsOneWidget);
  });
}
