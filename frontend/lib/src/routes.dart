import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'routes/route_observer.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import 'providers/input_provider.dart';
import 'report_upload.dart';
import 'screens/clef_selection_screen.dart';
import 'screens/device_list_screen.dart';
import 'screens/languages_screen.dart';
import 'screens/midi_signal_screen.dart';
import 'screenshot_capture.dart';
import 'style.dart';
import 'widgets/settings_drawer.dart';

String _shellTitle(BuildContext context, GoRouterState state) {
  switch (state.uri.path) {
    case Routes.devices:
      return AppLocalizations.of(context)!.selectInput;
    case Routes.note:
      final device = context.read<InputProvider>().currentDevice();
      assert(device != null);
      return device!.localizedPortName(context);
    case Routes.clefs:
      return AppLocalizations.of(context)!.selectClef;
    case Routes.languages:
      return AppLocalizations.of(context)!.languages;
  }
  return 'Pianoscope';
}

Widget _noAppBarScaffold(Widget child) {
  final scaffold = Scaffold(
    drawer: const SettingsDrawer(hasSmallHeader: true),
    body: Builder(
      builder: (context) {
        return Stack(
          children: [
            child,
            // This layout drops the AppBar so the staff gets the full height,
            // which means the drawer toggle has to be positioned over the body.
            // Give it the AppBar's leading slot and button style so it is
            // pixel-for-pixel the menu the other orientations show.
            Positioned(
              top:
                  MediaQuery.of(context).padding.top +
                  MediaQuery.of(context).size.height / 3,
              left: AppSpacing.sm,
              child: SizedBox.square(
                dimension: AppHeights.button,
                child: IconButton(
                  style: AppTheme.overlayIconButtonStyle,
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
  return RepaintBoundary(key: FeedbackScreenCapture.rootKey, child: scaffold);
}

bool _uploadPromptShown = false;

/// Offers to send the reports left in the cache. Runs once per app start, on
/// the first frame, because `main` has no [BuildContext] of its own before
/// `runApp` and the shell builder must not open a dialog while it builds.
void _scheduleUploadPrompt(BuildContext context) {
  if (_uploadPromptShown) return;
  _uploadPromptShown = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    flushPendingReports(context);
  });
}

Widget _scaffold(BuildContext context, GoRouterState state, Widget child) {
  _scheduleUploadPrompt(context);
  final isLandscape =
      MediaQuery.of(context).orientation == Orientation.landscape;

  if (state.uri.path == Routes.note && isLandscape) {
    return _noAppBarScaffold(child);
  }
  final scaffold =
      state.uri.path == Routes.languages || state.uri.path == Routes.clefs
      ? Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => GoRouter.of(context).pop(),
            ),
            title: Text(_shellTitle(context, state)),
          ),
          body: child,
        )
      : Scaffold(
          appBar: AppBar(title: Text(_shellTitle(context, state))),
          drawer: SettingsDrawer(hasSmallHeader: isLandscape),
          body: child,
        );

  return RepaintBoundary(key: FeedbackScreenCapture.rootKey, child: scaffold);
}

class Routes {
  static const String devices = "/devices";
  static const String note = "/note";
  static const String clefs = "/clefs";
  static const String languages = "/languages";
}

final router = GoRouter(
  initialLocation: Routes.devices,
  observers: [routeObserver],
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return _scaffold(context, state, child);
      },
      routes: [
        GoRoute(
          path: Routes.devices,
          builder: (context, state) => const DeviceListScreen(),
        ),
        GoRoute(
          path: Routes.note,
          builder: (context, state) => const MidiSignalScreen(),
        ),
        GoRoute(
          path: Routes.clefs,
          builder: (context, state) => const ClefSelectionScreen(),
        ),
        GoRoute(
          path: Routes.languages,
          builder: (context, state) => const LanguageSelectionScreen(),
        ),
      ],
    ),
  ],
);
