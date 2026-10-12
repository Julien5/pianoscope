import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pianoscope/l10n/app_localizations.dart';
import 'package:pianoscope/src/providers/user_settings_provider.dart';
import 'package:pianoscope/src/widgets/feedback_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The provider under test plus the future resolved when the dialog closes.
typedef OpenDialog = ({
  UserSettingsProvider settings,
  Future<FeedbackRequest?> result,
});

Future<OpenDialog> openDialog(
  WidgetTester tester,
  FeedbackMode mode, {
  int crashReportCount = 0,
}) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final settings = UserSettingsProvider();
  await settings.init();
  late final Future<FeedbackRequest?> result;
  await tester.pumpWidget(
    MultiProvider(
      providers: [ChangeNotifierProvider.value(value: settings)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => result = FeedbackDialog.show(
                context,
                mode: mode,
                crashReportCount: crashReportCount,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (settings: settings, result: result);
}

void main() {
  testWidgets('feedback mode shows the three inputs and both actions', (
    tester,
  ) async {
    await openDialog(tester, FeedbackMode.feedback);

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Send'), findsOneWidget);
    expect(find.text('Feedback'), findsOneWidget);
  });

  testWidgets('feedback mode rejects an empty message', (tester) async {
    await openDialog(tester, FeedbackMode.feedback);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Send'));
    await tester.pumpAndSettle();

    expect(find.text('Please describe the problem'), findsOneWidget);
    expect(find.byType(FeedbackDialog), findsOneWidget);
  });

  testWidgets('feedback mode rejects a malformed email', (tester) async {
    await openDialog(tester, FeedbackMode.feedback);

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.enterText(
      find.byType(TextFormField).last,
      'the staff is shifted',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send'));
    await tester.pumpAndSettle();

    expect(
      find.text('This does not look like an email address'),
      findsOneWidget,
    );
  });

  testWidgets('submitting returns the request and remembers the email', (
    tester,
  ) async {
    final dialog = await openDialog(tester, FeedbackMode.feedback);

    await tester.enterText(find.byType(TextFormField).first, 'me@example.com');
    await tester.enterText(
      find.byType(TextFormField).last,
      '  shifted staff  ',
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send'));
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackDialog), findsNothing);
    final request = await dialog.result;
    expect(request, isNotNull);
    expect(request!.email, 'me@example.com');
    expect(request.message, 'shifted staff');
    expect(request.withScreenshot, isTrue);
    expect(dialog.settings.email, 'me@example.com');
  });

  testWidgets('an empty email is accepted', (tester) async {
    final dialog = await openDialog(tester, FeedbackMode.feedback);

    await tester.enterText(find.byType(TextFormField).last, 'hello');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send'));
    await tester.pumpAndSettle();

    final request = await dialog.result;
    expect(request?.email, isEmpty);
    expect(request?.message, 'hello');
    expect(request?.withScreenshot, isFalse);
  });

  testWidgets('cancel returns nothing and keeps the stored email', (
    tester,
  ) async {
    final dialog = await openDialog(tester, FeedbackMode.feedback);

    await tester.enterText(find.byType(TextFormField).first, 'me@example.com');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackDialog), findsNothing);
    expect(await dialog.result, isNull);
    expect(dialog.settings.email, isEmpty);
  });

  testWidgets('crash report mode hides the inputs', (tester) async {
    await openDialog(tester, FeedbackMode.crashReport, crashReportCount: 3);

    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('Crash reports'), findsOneWidget);
    expect(
      find.textContaining('3 crash reports could be sent'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ElevatedButton, 'Send'), findsOneWidget);
  });

  testWidgets('crash report mode uses the singular notice for one report', (
    tester,
  ) async {
    await openDialog(tester, FeedbackMode.crashReport, crashReportCount: 1);

    expect(
      find.textContaining('One crash report could be sent'),
      findsOneWidget,
    );
  });

  testWidgets('crash report mode returns an empty request on submit', (
    tester,
  ) async {
    final dialog = await openDialog(tester, FeedbackMode.crashReport);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Send'));
    await tester.pumpAndSettle();

    final request = await dialog.result;
    expect(request, isNotNull);
    expect(request!.email, isEmpty);
    expect(request.message, isEmpty);
    expect(request.withScreenshot, isFalse);
  });
}
