import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../rust/api/event.dart';
import 'package:provider/provider.dart';
import '../providers/input_provider.dart';
import '../widgets/grand_staff_view.dart';
import '../widgets/keyboard_widget.dart';
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
  final Map<int, MidiEvent> _activeEvents = {};
  MidiEvent? _lastEvent;
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
      _lastEvent = event;
      _noteName = event.noteName;
      _rawHex = _formatRaw(event.raw);
      if (event.status == Status.noteOn) {
        _activeEvents[event.note] = event;
      } else if (event.status == Status.noteOff) {
        _activeEvents.remove(event.note);
      }
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
    final signalVelocity = (_lastEvent?.velocity ?? 0).clamp(0, 127);

    // note name without digets
    final String simpleNote = _noteName.replaceAll(RegExp(r'[0-9-]'), '');
    Set<KeyboardNote> keyboardNotes = {};
    if (simpleNote.isNotEmpty) {
      keyboardNotes = {noteFromString(simpleNote)};
    }
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
                    notes: _activeEvents.isEmpty
                        ? const []
                        : _activeEvents.values
                              .map(
                                (e) => Note(
                                  pitch: Pitch.fromMidiNumber(e.note),
                                  duration: const NoteDuration.quarter(),
                                  velocity: e.velocity.clamp(0, 127),
                                  startBeat: 0,
                                ),
                              )
                              .toList(),
                  ),
                ),
                VelocityIndicator(velocity: signalVelocity),
                const SizedBox(width: 10),
              ],
            ),
            const SizedBox(height: 8),
            KeyboardWidget(
              pressedNotes: keyboardNotes,
              whiteHeight: 140,
              whiteWidth: 40,
              pressedDotRadius: 5,
              pressedDotColor: Colors.blue,
            ),
            const SizedBox(height: 32),
            Text(
              _noteName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(_rawHex, style: const TextStyle(fontSize: 10)),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}
