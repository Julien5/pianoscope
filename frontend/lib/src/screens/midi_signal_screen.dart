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

class MainContentPortrait extends StatelessWidget {
  final int signalVelocity;
  final Set<Note> keyboardNotes;
  final KeySignature? keySignature;
  final List<Note> notes;
  final String selectClef;
  final VoidCallback openClefSelectionScreen;
  final String noteName;

  const MainContentPortrait({
    super.key,
    required this.signalVelocity,
    required this.keyboardNotes,
    required this.keySignature,
    required this.notes,
    required this.selectClef,
    required this.openClefSelectionScreen,
    required this.noteName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                children: [
                  ElevatedButton(
                    onPressed: () {
                      openClefSelectionScreen();
                    },
                    child: Icon(Icons.arrow_upward),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      openClefSelectionScreen();
                    },
                    child: Icon(Icons.music_note_rounded),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      openClefSelectionScreen();
                    },
                    child: Icon(Icons.arrow_downward),
                  ),
                ],
              ),
              Expanded(
                flex: 6,
                child: GrandStaffView(
                  keySignature: keySignature ?? KeySignature.cMajor,
                  notes: notes,
                ),
              ),
              Padding(
                padding: EdgeInsetsGeometry.fromLTRB(10, 0, 10, 0),
                child: VelocityIndicator(velocity: signalVelocity),
              ),
            ],
          ),
        ),

        Expanded(
          child: Column(
            spacing: 10,
            children: [
              KeyboardWidget(
                pressedNotes: keyboardNotes,
                whiteHeight: 150,
                whiteWidth: 40,
                pressedDotRadius: 5,
                pressedDotColor: Colors.blue,
              ),

              NoteNameText(noteName: noteName),
            ],
          ),
        ),
      ],
    );
  }
}

class MainContentLandscape extends StatelessWidget {
  final int signalVelocity;
  final Set<Note> keyboardNotes;
  final KeySignature? keySignature;
  final List<Note> notes;
  final String selectClef;
  final VoidCallback openClefSelectionScreen;
  final String noteName;

  const MainContentLandscape({
    super.key,
    required this.signalVelocity,
    required this.keyboardNotes,
    required this.keySignature,
    required this.notes,
    required this.selectClef,
    required this.openClefSelectionScreen,
    required this.noteName,
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
                pressedNotes: keyboardNotes,
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
                          openClefSelectionScreen();
                        },
                        child: Icon(Icons.menu),
                      ),

                      SizedBox(
                        width: 50,
                        child: NoteNameText(noteName: noteName),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: SizedBox(width: 10)),
            ],
          ),
        ),

        Expanded(
          child: Column(
            spacing: 10,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: SizedBox(width: 10)),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                  children: [
                    ElevatedButton(
                      onPressed: () {
                        openClefSelectionScreen();
                      },
                      child: Icon(Icons.arrow_upward),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        openClefSelectionScreen();
                      },
                      child: Icon(Icons.music_note_rounded),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        openClefSelectionScreen();
                      },
                      child: Icon(Icons.arrow_downward),
                    ),
                  ],
                ),
              ),
              Expanded(child: SizedBox(width: 10)),
            ],
          ),
        ),

        const SizedBox(width: 20),
        Expanded(
          flex: 4,
          child: Column(
            children: [
              Expanded(child: SizedBox(width: 10)),
              Expanded(
                flex: 6,
                child: GrandStaffView(
                  keySignature: keySignature ?? KeySignature.cMajor,
                  notes: notes,
                ),
              ),

              Expanded(child: SizedBox(width: 10)),
            ],
          ),
        ),

        SizedBox(
          width: 50,
          child: Column(
            children: [
              Expanded(child: SizedBox(width: 10)),
              VelocityIndicator(velocity: signalVelocity),
              Expanded(child: SizedBox(width: 10)),
            ],
          ),
        ),

        const Expanded(child: SizedBox(height: 20)),
      ],
    );
  }
}

class _MidiSignalScreenState extends State<MidiSignalScreen> {
  String _noteName = '---';

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
    final String simpleNote = _noteName.replaceAll(RegExp(r'[0-9-]'), '');

    final notes = _activeEvents.values
        .map((e) => Note(pitch: Pitch.fromMidiNumber(e.note)))
        .toList();

    Set<Note> keyboardNotes = {};
    if (simpleNote.isNotEmpty) {
      keyboardNotes = notes.toSet();
    }
    InputProvider model = context.watch<InputProvider>();
    KeySignature? keySignature = model.keySignature;

    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;

        final mainContent = isLandscape
            ? MainContentLandscape(
                signalVelocity: signalVelocity,
                keyboardNotes: keyboardNotes,
                keySignature: keySignature,
                notes: notes,
                selectClef: selectClef,
                openClefSelectionScreen: openClefSelectionScreen,
                noteName: _noteName,
              )
            : MainContentPortrait(
                signalVelocity: signalVelocity,
                keyboardNotes: keyboardNotes,
                keySignature: keySignature,
                notes: notes,
                selectClef: selectClef,
                openClefSelectionScreen: openClefSelectionScreen,
                noteName: _noteName,
              );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: mainContent),
            const SizedBox(height: 2),
          ],
        );
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
