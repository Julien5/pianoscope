import 'package:flutter/material.dart';
import '../../pianoscope.dart';
import '../notation/grand_staff_parameters.dart';
import '../notation/grand_staff_painter.dart';

/// Renders a single-measure grand staff (treble above, bass below) from a
/// flat list of notes.
///
/// Notes at MIDI >= [splitPoint] go on the treble staff, notes below on the
/// bass staff; each staff shows its notes as a single chord.
///
/// Margins are intentionally not managed here: set them with a parent widget
/// (e.g. `Padding`) around this view.
class GrandStaffView extends StatelessWidget {
  final GrandStaffParameters params;
  final List<Note> notes;
  final KeySignature keySignature;
  final int splitPoint;

  const GrandStaffView({
    super.key,
    this.params = GrandStaffParameters.defaults,
    this.notes = const [],
    this.keySignature = KeySignature.cMajor,
    this.splitPoint = 60,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: CustomPaint(
        painter: GrandStaffPainter(
          params: params,
          notes: notes,
          keySignature: keySignature,
          splitPoint: splitPoint,
        ),
        size: Size.infinite,
      ),
    );
  }
}
