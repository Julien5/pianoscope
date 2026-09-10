import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../rust/api/event.dart';
import 'package:provider/provider.dart';
import '../providers/input_provider.dart';
import '../widgets/grand_staff_view.dart';
import '../widgets/velocity_indicator.dart';
import '../notation/models/note.dart';
import '../notation/models/pitch.dart';
import '../notation/models/duration.dart';

class MidiSignalScreen extends StatefulWidget {
  final String portName;
  final Stream<MidiEvent> eventStream;
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
  MidiEvent? _event;
  StreamSubscription<MidiEvent>? _eventSubscription;
  StreamSubscription<String>? _errorSubscription;

  @override
  void initState() {
    super.initState();
    _eventSubscription = widget.eventStream.listen(_onEvent);
    _errorSubscription = widget.errorStream.listen(_onError);
  }

  void _onEvent(MidiEvent event) {
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
    context.read<InputProvider>().disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signalVelocity = (_event?.velocity ?? 0).clamp(0, 127);

    return Scaffold(
      appBar: AppBar(title: Text(widget.portName)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: GrandStaffView(
                    notes: _event == null
                        ? const []
                        : [
                            Note(
                              pitch: Pitch.fromMidiNumber(_event!.note),
                              duration: const NoteDuration.quarter(),
                              velocity: signalVelocity,
                              startBeat: 0,
                            ),
                          ],
                  ),
                ),
                VelocityIndicator(velocity: signalVelocity),
                const SizedBox(width: 10),
              ],
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
