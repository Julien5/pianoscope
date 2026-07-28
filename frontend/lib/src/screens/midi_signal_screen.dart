import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/src/providers/midi_provider.dart';

class MidiSignalScreen extends StatefulWidget {
  final String portName;
  final Stream<String> eventStream;

  const MidiSignalScreen({
    super.key,
    required this.portName,
    required this.eventStream,
  });

  @override
  State<MidiSignalScreen> createState() => _MidiSignalScreenState();
}

class _MidiSignalScreenState extends State<MidiSignalScreen> {
  String _noteName = '---';
  String _rawHex = '';
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.eventStream.listen(_onEvent);
  }

  void _onEvent(String event) {
    if (event.startsWith('ERROR')) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(event)));
      return;
    }

    if (event == 'CONNECTED') {
      return;
    }

    final parts = event.split(' ');
    if (parts.length < 3) return;

    final rawHex = parts.sublist(1, parts.length - 1).join(' ');
    final noteName = parts.last;

    setState(() {
      _noteName = noteName;
      _rawHex = rawHex;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    context.read<MidiProvider>().disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.portName)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _noteName,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(_rawHex, style: const TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }
}
