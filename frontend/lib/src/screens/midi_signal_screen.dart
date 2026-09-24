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
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: SizedBox(height: 20)),
                  // Keyboard on the left, in a fixed-width column, centered vertically
                  SizedBox(
                    width: 200,
                    child: Center(
                      child: KeyboardWidget(
                        pressedNotes: keyboardNotes,
                        whiteHeight: 200,
                        whiteWidth: 50,
                        pressedDotRadius: 5,
                        pressedDotColor: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Center(
                        child: SizedBox(
                          height: 300,
                          width: 300,
                          child: Column(
                            children: [
                              ElevatedButton(
                                onPressed: openClefSelectionScreen,
                                child: Text(selectClef),
                              ),
                              GrandStaffView(
                                keySignature:
                                    keySignature ?? KeySignature.cMajor,
                                notes: notes,
                              ),
                              NoteNameText(noteName: _noteName),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Right column: velocity indicator only (clef button moved below)
                  SizedBox(
                    width: 50,
                    child: Center(
                      child: VelocityIndicator(velocity: signalVelocity),
                    ),
                  ),
                  Expanded(child: SizedBox(height: 20)),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsetsGeometry.fromLTRB(20, 0, 20, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: GrandStaffView(
                              keySignature: keySignature ?? KeySignature.cMajor,
                              notes: notes,
                            ),
                          ),
                        ),
                        VelocityIndicator(velocity: signalVelocity),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Keyboard below the staff in portrait
                  KeyboardWidget(
                    pressedNotes: keyboardNotes,
                    whiteHeight: 140,
                    whiteWidth: 40,
                    pressedDotRadius: 5,
                    pressedDotColor: Colors.blue,
                  ),
                  const SizedBox(height: 8),
                ],
              );

        // Bottom full-width row: (1) note name under keyboard (left),
        // (2) select-clef button under grand staff (center). Layout differs
        // slightly by orientation to align with mainContent columns.
        final bottomRow = isLandscape
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(children: []),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(child: NoteNameText(noteName: _noteName)),
                    ),
                    Expanded(
                      child: Center(
                        child: ElevatedButton(
                          onPressed: openClefSelectionScreen,
                          child: Text(selectClef),
                        ),
                      ),
                    ),
                  ],
                ),
              );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: mainContent),
            bottomRow,
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
