import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../l10n/app_localizations.dart';
import '../../pianoscope.dart';
import '../providers/user_settings_provider.dart';
import '../routes.dart';
import '../rust/api/event.dart';
import 'package:provider/provider.dart';
import '../style.dart';
import '../utils.dart';
import '../widgets/keyboard_widget.dart';
import '../widgets/velocity_indicator.dart';

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
  final KeySignature? keySignature;
  final List<Note> notes;
  final String selectClef;
  final int splitPoint;
  final Orientation orientation;
  final BoxConstraints constraints;

  ScreenData({
    required this.signalVelocity,
    required this.keySignature,
    required this.notes,
    required this.selectClef,
    required this.splitPoint,
    required this.orientation,
    required this.constraints,
  });
}

class _MidiCard extends StatelessWidget {
  final Widget child;
  const _MidiCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(child: child);
  }
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
        SizedBox(height: 10),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: _MidiCard(
              child: GrandStaffPanel(data: data, callbacks: callbacks),
            ),
          ),
        ),

        SizedBox(height: 20),

        _MidiCard(child: _KeyboardPanel(data: data)),

        SizedBox(height: 20),
        _MidiCard(
          child: ButtonsRow(data: data, callbacks: callbacks),
        ),
        SizedBox(height: 10),
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
        Expanded(
          flex: 4,
          child: Column(
            children: [
              const Expanded(child: SizedBox(width: AppSpacing.md)),
              _MidiCard(child: _KeyboardPanel(data: data)),
              _MidiCard(
                child: ButtonsRow(data: data, callbacks: callbacks),
              ),
              const Expanded(child: SizedBox(width: AppSpacing.md)),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: _MidiCard(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: GrandStaffPanel(data: data, callbacks: callbacks),
            ),
          ),
        ),
      ],
    );
  }
}

class ButtonsRow extends StatelessWidget {
  final ScreenData data;
  final ScreenCallbacks callbacks;

  const ButtonsRow({super.key, required this.data, required this.callbacks});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsGeometry.directional(top: 10, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          ElevatedButton.icon(
            style: AppTheme.tonalButtonStyle,
            onPressed: callbacks.onNoteUpperStaffClicked,
            icon: Icon(Icons.arrow_upward),
            label: const Text('Clé de sol'),
          ),
          ElevatedButton.icon(
            style: AppTheme.tonalButtonStyle,
            onPressed: () => callbacks.openClefSelectionClicked(),
            icon: Icon(Icons.music_note_rounded),
            label: const Text('Key signature'),
          ),
        ],
      ),
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
        SizedBox(width: 10),
        Expanded(
          flex: 6,
          child: GrandStaffView(
            keySignature: data.keySignature ?? KeySignature.cMajor,
            notes: data.notes,
            splitPoint: data.splitPoint,
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: VelocityIndicator(velocity: data.signalVelocity),
        ),
      ],
    );
  }
}

enum Move { toUpper, toLower }

class _MidiSignalScreenState extends State<MidiSignalScreen> {
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
    // Cannot be awaited here. The observers are cleared synchronously by
    // disconnect(), so nothing reaches this disposed State.
    unawaited(_inputProvider?.disconnect());
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

  Move? moveCandidate(UserSettingsProvider userSettings) {
    final notes = currentNotes();
    if (notes.isEmpty) {
      return null;
    }
    final note = notes.last;
    if (userSettings.splitPoint <= note.pitch.midiNumber) {
      return Move.toLower;
    }
    return Move.toUpper;
  }

  void onNoteUpperStaffClicked(UserSettingsProvider userSettings) {
    final notes = currentNotes();
    if (notes.isEmpty) {
      return;
    }
    final note = notes.last;
    userSettings.setSplitPoint(note.pitch.midiNumber);
  }

  void onNoteLowerStaffClicked(UserSettingsProvider userSettings) {
    debugPrint("onNoteLowerStaffClicked");
    final notes = currentNotes();
    if (notes.isEmpty) {
      return;
    }
    final note = notes.last;
    userSettings.setSplitPoint(note.pitch.midiNumber + 1);
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
    final notes = currentNotes();
    final userSettings = context.watch<UserSettingsProvider>();
    KeySignature? keySignature = userSettings.keySignature;

    Move? candidate = moveCandidate(userSettings);

    final callbacks = ScreenCallbacks(
      openClefSelectionClicked: openClefSelectionScreen,

      onNoteUpperStaffClicked: candidate == null || candidate != Move.toUpper
          ? null
          : () {
              onNoteUpperStaffClicked(userSettings);
            },
      onNoteLowerStaffClicked: candidate == null || candidate != Move.toLower
          ? null
          : () {
              onNoteLowerStaffClicked(userSettings);
            },
    );

    return OrientationBuilder(
      builder: (context, orientation) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final data = ScreenData(
              signalVelocity: signalVelocity,
              keySignature: keySignature,
              notes: notes,
              selectClef: selectClef,
              splitPoint: userSettings.splitPoint,
              orientation: orientation,
              constraints: constraints,
            );
            final isLandscape = orientation == Orientation.landscape;
            debugPrint("constr:$constraints");
            if (isLandscape) {
              return MainContentLandscape(data: data, callbacks: callbacks);
            }
            return MainContentPortrait(data: data, callbacks: callbacks);
          },
        );
      },
    );
  }
}

class _KeyboardPanel extends StatelessWidget {
  const _KeyboardPanel({required this.data});
  final ScreenData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: KeyboardWidget(
              pressedNotes: data.notes,
              whiteHeight: AppKeyboardStyle.compactWhiteHeight,
              whiteWidth: AppKeyboardStyle.compactWhiteWidth,
            ),
          ),
        ),
        SizedBox(
          height: 50,
          child: Align(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: 250,
                  child: NoteNameText(noteNames: data.notes),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class NoteNameText extends StatelessWidget {
  final List<Note> noteNames;
  const NoteNameText({super.key, required this.noteNames});
  @override
  Widget build(BuildContext context) {
    final localized = noteNames
        .map((name) => localizeNote(name, AppLocalizations.of(context)!))
        .toList();
    final String title = localized.join(",");
    return Text(
      title,
      style: AppTextStyles.noteName,
      textAlign: TextAlign.center,
    );
  }
}
