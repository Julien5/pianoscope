import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
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

class ScreenCallbacks {
  final VoidCallback openClefSelectionClicked;
  final VoidCallback? onNoteUpperStaffClicked;
  final VoidCallback? onNoteLowerStaffClicked;

  ScreenCallbacks({
    required this.openClefSelectionClicked,
    required this.onNoteUpperStaffClicked,
    required this.onNoteLowerStaffClicked,
  });
}

class ScreenData {
  final int signalVelocity;
  final Set<Note> keyboardNotes;
  final KeySignature? keySignature;
  final List<Note> notes;
  final String selectClef;
  final String noteName;
  final int splitPoint;

  ScreenData({
    required this.signalVelocity,
    required this.keyboardNotes,
    required this.keySignature,
    required this.notes,
    required this.selectClef,
    required this.noteName,
    required this.splitPoint,
  });
}

class MainContentPortrait extends StatelessWidget {
  final ScreenData data;
  final ScreenCallbacks callbacks;

  const MainContentPortrait({
    super.key,
    required this.callbacks,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 2,
          child: GrandStaffPanel(data: data, callbacks: callbacks),
        ),

        Expanded(
          child: Column(
            spacing: 10,
            children: [
              KeyboardWidget(
                pressedNotes: data.keyboardNotes,
                whiteHeight: 150,
                whiteWidth: 40,
                pressedDotRadius: 5,
                pressedDotColor: Colors.blue,
              ),

              NoteNameText(noteName: data.noteName),
            ],
          ),
        ),
      ],
    );
  }
}

class MainContentLandscape extends StatelessWidget {
  final ScreenData data;
  final ScreenCallbacks callbacks;

  const MainContentLandscape({
    super.key,
    required this.data,
    required this.callbacks,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(child: SizedBox(height: 20)),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(child: SizedBox(width: 10)),

              KeyboardWidget(
                pressedNotes: data.keyboardNotes,
                whiteHeight: 200,
                whiteWidth: 50,
                pressedDotRadius: 5,
                pressedDotColor: Colors.blue,
              ),
              SizedBox(
                height: 50,
                child: Align(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          callbacks.openClefSelectionClicked();
                        },
                        child: Icon(Icons.menu),
                      ),

                      SizedBox(
                        width: 50,
                        child: NoteNameText(noteName: data.noteName),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: SizedBox(width: 10)),
            ],
          ),
        ),

        const SizedBox(width: 20),
        Expanded(
          flex: 4,
          child: GrandStaffPanel(data: data, callbacks: callbacks),
        ),

        const Expanded(child: SizedBox(height: 20)),
      ],
    );
  }
}

class GrandStaffPanel extends StatelessWidget {
  final ScreenData data;
  final ScreenCallbacks callbacks;

  const GrandStaffPanel({
    super.key,
    required this.data,
    required this.callbacks,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: callbacks.onNoteUpperStaffClicked,
              child: Icon(Icons.arrow_upward),
            ),
            ElevatedButton(
              onPressed: () => callbacks.openClefSelectionClicked(),
              child: Icon(Icons.music_note_rounded),
            ),
            ElevatedButton(
              onPressed: callbacks.onNoteLowerStaffClicked,
              child: Icon(Icons.arrow_downward),
            ),
          ],
        ),

        Expanded(
          flex: 6,
          child: GrandStaffView(
            keySignature: data.keySignature ?? KeySignature.cMajor,
            notes: data.notes,
            splitPoint: data.splitPoint,
          ),
        ),

        Padding(
          padding: EdgeInsetsGeometry.fromLTRB(10, 0, 10, 0),
          child: VelocityIndicator(velocity: data.signalVelocity),
        ),
      ],
    );
  }
}

enum Move { toUpper, toLower }

class _MidiSignalScreenState extends State<MidiSignalScreen> {
  String _noteName = '---';
  int splitPoint = 60;

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
  void initState() {
    super.initState();
    WakelockPlus.enable();
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

  @override
  void dispose() {
    debugPrint("midi dispose: cancel subsription");
    _inputProvider?.disconnect();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> openClefSelectionScreen() async {
    GoRouter.of(context).push(Routes.clefs);
  }

  List<Note> currentNotes() {
    return _activeEvents.values
        .map((e) => Note(pitch: Pitch.fromMidiNumber(e.note)))
        .toList();
  }

  Move? moveCandidate() {
    final notes = currentNotes();
    if (notes.isEmpty) {
      return null;
    }
    final note = notes.last;
    if (splitPoint <= note.pitch.midiNumber) {
      return Move.toLower;
    }
    return Move.toUpper;
  }

  void onNoteUpperStaffClicked() {
    final notes = currentNotes();
    if (notes.isEmpty) {
      return;
    }
    final note = notes.last;
    setState(() {
      splitPoint = note.pitch.midiNumber;
    });
  }

  void onNoteLowerStaffClicked() {
    debugPrint("onNoteLowerStaffClicked");
    final notes = currentNotes();
    if (notes.isEmpty) {
      return;
    }
    final note = notes.last;
    setState(() {
      splitPoint = note.pitch.midiNumber + 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_inputProvider == null) {
      return const Text("loading..");
    }
    // because we need to rebuild on clef change
    context.watch<InputProvider>();
    final signalVelocity = (_lastEvent?.velocity ?? 0).clamp(0, 127);
    final String selectClef = AppLocalizations.of(context)!.selectClef;
    // note name without digits
    final String simpleNoteName = _noteName.replaceAll(RegExp(r'[0-9-]'), '');

    final notes = currentNotes();

    Set<Note> keyboardNotes = {};
    if (simpleNoteName.isNotEmpty) {
      keyboardNotes = notes.toSet();
    }
    InputProvider model = context.watch<InputProvider>();
    KeySignature? keySignature = model.keySignature;

    Move? candidate = moveCandidate();

    final callbacks = ScreenCallbacks(
      openClefSelectionClicked: openClefSelectionScreen,
      onNoteUpperStaffClicked: candidate == null || candidate != Move.toUpper
          ? null
          : onNoteUpperStaffClicked,
      onNoteLowerStaffClicked: candidate == null || candidate != Move.toLower
          ? null
          : onNoteLowerStaffClicked,
    );

    final data = ScreenData(
      signalVelocity: signalVelocity,
      keyboardNotes: keyboardNotes,
      keySignature: keySignature,
      notes: notes,
      selectClef: selectClef,
      noteName: _noteName,
      splitPoint: splitPoint,
    );

    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;

        final mainContent = isLandscape
            ? MainContentLandscape(data: data, callbacks: callbacks)
            : MainContentPortrait(data: data, callbacks: callbacks);

        return mainContent;
      },
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
