import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'routes/route_observer.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import 'providers/input_provider.dart';
import 'screens/clef_selection_screen.dart';
import 'screens/device_list_screen.dart';
import 'screens/languages_screen.dart';
import 'screens/midi_signal_screen.dart';
import 'widgets/settings_drawer.dart';

String _shellTitle(BuildContext context, GoRouterState state) {
  switch (state.uri.path) {
    case Routes.devices:
      return AppLocalizations.of(context)!.selectInput;
    case Routes.note:
      // Defensive: `/note` is only reachable after a successful connect(), so
      // there should always be a device. Render something rather than throw if
      // that ever stops holding. Not localized, unlike the other titles, because
      // the branch should be unreachable.
      final device = context.read<InputProvider>().currentDevice();
      final title = device != null
          ? device.localizedPortName(context)
          : "unknown";
      return title;
    case Routes.clefs:
      return AppLocalizations.of(context)!.selectClef;
    case Routes.languages:
      return AppLocalizations.of(context)!.languages;
  }
  return 'Pianoscope';
}

Widget _noAppBarScaffold(Widget child) {
  return Scaffold(
    drawer: const SettingsDrawer(smallHeader: true),
    body: Builder(
      builder: (context) {
        return Stack(
          children: [
            child,
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: FloatingActionButton.small(
                heroTag: 'settings',
                onPressed: () => Scaffold.of(context).openDrawer(),
                child: const Icon(Icons.menu),
              ),
            ),
          ],
        );
      },
    ),
  );
}

Widget _scaffold(BuildContext context, GoRouterState state, Widget child) {
  final isLandscape =
      MediaQuery.of(context).orientation == Orientation.landscape;
  if (state.uri.path == Routes.note && isLandscape) {
    return _noAppBarScaffold(child);
  }
  if (state.uri.path == Routes.languages || state.uri.path == Routes.clefs) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).pop(),
        ),
        title: Text(_shellTitle(context, state)),
      ),
      body: child,
    );
  }
  return Scaffold(
    appBar: AppBar(title: Text(_shellTitle(context, state))),
    drawer: SettingsDrawer(
      smallHeader: isLandscape,
    ), // Available across all routes in this shell
    body: child,
  );
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
