import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../notation/models/key_signature.dart';
import '../rust/api/event.dart';
import 'package:provider/provider.dart';
import '../providers/input_provider.dart';
import '../widgets/grand_staff_view.dart';
import '../widgets/keyboard_widget.dart';
import '../widgets/velocity_indicator.dart';
import '../notation/models/note.dart';
import '../notation/models/pitch.dart';
import 'clef_selection_screen.dart';

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

  Future<void> openClefSelectionScreen() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClefSelectionScreen()),
    );
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
    InputProvider model = context.watch<InputProvider>();
    KeySignature? keySignature = model.keySignature;
    List<Note> notes = _activeEvents.isEmpty
        ? []
        : _activeEvents.values
              .map((e) => Note(pitch: Pitch.fromMidiNumber(e.note)))
              .toList();

    notes.clear();
    /*notes.add(
      Note(
        pitch: Pitch(
          noteName: NoteName.A,
          octave: 4,
          accidental: Accidental.sharp,
        ),
      ),
    );*/
    notes.add(
      Note(
        pitch: Pitch(
          noteName: NoteName.D,
          octave: 5,
          accidental: Accidental.flat,
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.portName)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton(
              onPressed: () {
                openClefSelectionScreen();
              },
              child: const Text('Select Clef'),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: GrandStaffView(
                    keySignature: keySignature ?? KeySignature.cMajor,
                    notes: notes,
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
