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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Let the parent decide width; for height prefer the available
        // height if large, otherwise a sensible default. This avoids a
        // tiny fixed height that causes the painter content to stick to the
        // top in wide/landscape layouts.
        final preferredHeight =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : 200.0;
        return SizedBox(
          height: preferredHeight,
          width: double.infinity,
          child: CustomPaint(
            painter: GrandStaffPainter(
              params: params,
              notes: notes,
              keySignature: keySignature,
              splitPoint: splitPoint,
              // preserve default centering behavior
              centerVertically: true,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class KeySignatureTile extends StatelessWidget {
  final KeySignature keySignature;
  const KeySignatureTile({super.key, this.keySignature = KeySignature.cMajor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      width: 120,
      child: CustomPaint(
        painter: KeyTilePainter(keySignature: keySignature),
        size: Size.infinite,
      ),
    );
  }
}
