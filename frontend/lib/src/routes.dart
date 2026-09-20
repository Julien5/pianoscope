import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import 'providers/input_provider.dart';
import 'screens/clef_selection_screen.dart';
import 'screens/device_list_screen.dart';
import 'screens/midi_signal_screen.dart';
import 'widgets/settings_drawer.dart';

String _shellTitle(BuildContext context, GoRouterState state) {
  switch (state.uri.path) {
    case '/':
      return AppLocalizations.of(context)!.selectInput;
    case '/note':
      return context.read<InputProvider>().portName ?? 'MIDI Signal';
    case '/note/clef':
      return AppLocalizations.of(context)!.selectClef;
  }
  return 'Nano MIDI';
}

final router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return Scaffold(
          appBar: AppBar(title: Text(_shellTitle(context, state))),
          drawer:
              const SettingsDrawer(), // Available across all routes in this shell
          body: child,
        );
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DeviceListScreen(),
        ),
        GoRoute(
          path: '/note',
          builder: (context, state) => const MidiSignalScreen(),
          onExit: (context, state) async {
            await context.read<InputProvider>().disconnect();
            return true;
          },
          routes: [
            GoRoute(
              path: 'clef',
              builder: (context, state) => const ClefSelectionScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
