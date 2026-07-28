import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/src/providers/midi_provider.dart';
import 'package:frontend/src/rust/frb_generated.dart';
import 'package:frontend/src/screens/device_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => MidiProvider()..init(),
      child: const NanoApp(),
    ),
  );
}

class NanoApp extends StatelessWidget {
  const NanoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nano MIDI',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const DeviceListScreen(),
    );
  }
}
