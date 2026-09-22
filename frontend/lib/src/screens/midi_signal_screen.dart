import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../notation/models/key_signature.dart';
import '../routes.dart';
import '../rust/api/event.dart';
import 'package:provider/provider.dart';
import '../providers/input_provider.dart';
import '../style.dart';
import '../utils.dart';
import '../widgets/grand_staff_view.dart';
import '../widgets/keyboard_widget.dart';
import '../widgets/velocity_indicator.dart';
import '../notation/models/note.dart';
import '../notation/models/pitch.dart';

class MidiSignalScreen extends StatefulWidget {
  const MidiSignalScreen({super.key});

  @override
  State<MidiSignalScreen> createState() => _MidiSignalScreenState();
}

class _MidiSignalScreenState extends State<MidiSignalScreen> {
  String _noteName = '---';
  String _rawHex = '';
  final Map<int, MidiEvent> _activeEvents = {};
  MidiEvent? _lastEvent;

  InputProvider? _inputProvider;

  Future<void> _setupProvider() async {
    final provider = context.read<InputProvider>();
    assert(provider.connected());
    if (!mounted) return;
    provider.attachObservers(_onEvent, _onError);
    _inputProvider = provider;
    // rebuild, otherwise the "loading..." Text stays forever.
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    debugPrint("didChangeDependencies");
    if (_inputProvider == null) {
      _setupProvider();
    }
    super.didChangeDependencies();
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
    debugPrint("midi dispose: cancel subsription");
    _inputProvider?.disconnect();
    super.dispose();
  }

  Future<void> openClefSelectionScreen() async {
    GoRouter.of(context).push(Routes.clefs);
  }

  @override
  Widget build(BuildContext context) {
    if (_inputProvider == null) {
      return Text("loading..");
    }
    // because we need to rebuild on clef change
    context.watch<InputProvider>();
    final signalVelocity = (_lastEvent?.velocity ?? 0).clamp(0, 127);
    final String selectClef = AppLocalizations.of(context)!.selectClef;
    // note name without digets
    final String simpleNote = _noteName.replaceAll(RegExp(r'[0-9-]'), '');

    final notes = _activeEvents.values
        .map((e) => Note(pitch: Pitch.fromMidiNumber(e.note)))
        .toList();

    /* DEBUG */
    /*
    notes.clear();
    notes.add(
      Note(
        pitch: Pitch(
          noteName: NoteName.C,
          octave: 4,
          accidental: Accidental.sharp,
        ),
      ),
    );
    notes.add(
      Note(
        pitch: Pitch(
          noteName: NoteName.E,
          octave: 5,
          accidental: Accidental.natural,
        ),
      ),
    );
    */
    /* DEBUG */

    Set<Note> keyboardNotes = {};
    if (simpleNote.isNotEmpty) {
      keyboardNotes = notes.toSet();
    }
    InputProvider model = context.watch<InputProvider>();
    KeySignature? keySignature = model.keySignature;
    Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 20,
      children: [
        Expanded(
          child: GrandStaffView(
            keySignature: keySignature ?? KeySignature.cMajor,
            notes: notes,
          ),
        ),
        VelocityIndicator(velocity: signalVelocity),
      ],
    );
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () {
              openClefSelectionScreen();
            },
            child: Text(selectClef),
          ),
          Padding(
            padding: EdgeInsetsGeometry.fromLTRB(20, 0, 20, 0),
            child: row,
          ),
          const SizedBox(height: 10),
          KeyboardWidget(
            pressedNotes: keyboardNotes,
            whiteHeight: 140,
            whiteWidth: 40,
            pressedDotRadius: 5,
            pressedDotColor: Colors.blue,
          ),
          const SizedBox(height: 32),
          NoteNameText(noteName: _noteName),
          Text(_rawHex, style: AppTextStyles.small),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}

class NoteNameText extends StatelessWidget {
  final String noteName;
  const NoteNameText({super.key, required this.noteName});
  @override
  Widget build(BuildContext context) {
    final String title = localizeNote(noteName, AppLocalizations.of(context)!);
    return Text(title, style: AppTextStyles.normal);
  }
}
