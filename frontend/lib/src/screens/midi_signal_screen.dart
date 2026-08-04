import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/src/providers/midi_provider.dart';
import 'package:frontend/src/rust/api/event.dart';
import 'package:frontend/src/widgets/grand_staff_view.dart';

class MidiSignalScreen extends StatefulWidget {
  final String portName;
  final Stream<Event> eventStream;
  final Stream<String> errorStream;

  const MidiSignalScreen({
    super.key,
    required this.portName,
    required this.eventStream,
    required this.errorStream,
  });

  @override
  State<MidiSignalScreen> createState() => _MidiSignalScreenState();
}

class _MidiSignalScreenState extends State<MidiSignalScreen> {
  String _noteName = '---';
  String _rawHex = '';
  Event? _event;
  StreamSubscription<Event>? _eventSubscription;
  StreamSubscription<String>? _errorSubscription;

  @override
  void initState() {
    super.initState();
    _eventSubscription = widget.eventStream.listen(_onEvent);
    _errorSubscription = widget.errorStream.listen(_onError);
  }

  void _onEvent(Event event) {
    setState(() {
      _noteName = event.noteName;
      _rawHex = _formatRaw(event.raw);
      _event = event;
    });
  }

  void _onError(String error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  String _formatRaw(Uint8List raw) {
    return raw
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _errorSubscription?.cancel();
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
            GrandStaffView(
              midiNote: _event?.note,
              velocity: _event?.velocity ?? 64,
            ),
            const SizedBox(height: 16),
            Text(
              _noteName,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_rawHex, style: const TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }
}
