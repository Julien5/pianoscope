import 'package:flutter/material.dart';
import 'package:flutter_music_notation/flutter_music_notation.dart';

class NoteNotationView extends StatelessWidget {
  final int midiNote;
  final int velocity;

  const NoteNotationView({
    super.key,
    required this.midiNote,
    required this.velocity,
  });

  @override
  Widget build(BuildContext context) {
    final note = Note(
      pitch: Pitch.fromMidiNumber(midiNote),
      duration: const NoteDuration.quarter(),
      velocity: velocity,
      startBeat: 0,
    );

    final measure = Measure(
      number: 0,
      timeSignature: TimeSignature.fourFour,
      keySignature: KeySignature.cMajor,
      notes: [note],
    );

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: NotationView(
        measures: [measure],
        config: const NotationConfig(
          staffSpaceSize: 12,
          noteWidth: 60,
          leftMargin: 100,
          clef: ClefType.treble,
          width: 400,
        ),
      ),
    );
  }
}
