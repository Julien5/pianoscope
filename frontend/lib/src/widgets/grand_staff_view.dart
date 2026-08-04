import 'package:flutter/material.dart';
import 'package:flutter_music_notation/flutter_music_notation.dart';

/// Renders a grand staff (treble above, bass below) for the current MIDI note,
/// delegating to the fork's GrandStaff rendering.
///
/// Notes at MIDI >= 60 go on the treble staff, notes < 60 on the bass staff;
/// the other staff stays blank.
class GrandStaffView extends StatelessWidget {
  final int? midiNote;
  final int velocity;

  static const int _splitPoint = 60;

  const GrandStaffView({
    super.key,
    this.midiNote,
    this.velocity = 64,
  });

  @override
  Widget build(BuildContext context) {
    final note = midiNote;
    final upperNotes = <Note>[];
    final lowerNotes = <Note>[];

    if (note != null) {
      final noteModel = Note(
        pitch: Pitch.fromMidiNumber(note),
        duration: const NoteDuration.quarter(),
        velocity: velocity,
        startBeat: 0,
      );
      if (note >= _splitPoint) {
        upperNotes.add(noteModel);
      } else {
        lowerNotes.add(noteModel);
      }
    }

    final upperMeasure = Measure(
      number: 0,
      timeSignature: TimeSignature.fourFour,
      keySignature: KeySignature.cMajor,
      notes: upperNotes,
      endBarline: BarlineType.single,
    );

    final lowerMeasure = Measure(
      number: 0,
      timeSignature: TimeSignature.fourFour,
      keySignature: KeySignature.cMajor,
      notes: lowerNotes,
      endBarline: BarlineType.single,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: NotationView(
        grandStaff: GrandStaff(
          upperStaff: [upperMeasure],
          lowerStaff: [lowerMeasure],
        ),
        config: const NotationConfig(
          staffSpaceSize: 12,
          leftMargin: 60,
          topMargin: 30,
          grandStaffGap: 60,
          showBrace: true,
          showMeasureNumbers: false,
          showTimeSignature: false,
        ),
      ),
    );
  }
}
