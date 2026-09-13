// lib/src/notation/rendering/note_renderer.dart

import 'package:flutter/material.dart';
import '../models/note.dart';
import '../geometry/staff_position.dart';
import '../geometry/staff_geometry.dart';
import 'notehead_renderer.dart';
import 'stem_renderer.dart';
import 'accidental_renderer.dart';

/// Paints a single note (quarter-note assumption): notehead, ledger lines,
/// optional accidental and a stem. Durations are assumed to be quarter notes,
/// so flags, dots and beams are not drawn.
class NoteRenderer {
  final NoteheadRenderer _noteheadRenderer;
  final StemRenderer _stemRenderer;
  final AccidentalRenderer _accidentalRenderer;

  NoteRenderer()
    : _noteheadRenderer = NoteheadRenderer(),
      _stemRenderer = StemRenderer(),
      _accidentalRenderer = AccidentalRenderer();

  /// Draw the notehead, optional accidental and ledger lines for a note whose
  /// center is at [noteCenter]. No stem is drawn.
  void paintSymbols(
    Canvas canvas, {
    required Offset noteCenter,
    required Note note,
    required StaffPosition position,
    required bool showAccidental,
    double accidentalX = 0,
  }) {
    // Draw ledger lines if needed.
    StaffGeometry.paintLedgerLines(canvas, noteCenter, position);

    // Draw accidental if needed.
    if (showAccidental) {
      _accidentalRenderer.paint(
        canvas,
        Offset(noteCenter.dx + accidentalX, noteCenter.dy),
        note.pitch.accidental,
        color: note.color,
      );
    }

    // Quarter-note assumption: filled notehead.
    _noteheadRenderer.paint(canvas, noteCenter, color: note.color);
  }

  /// Paint a complete single note (notehead, accidental, ledger lines and
  /// stem), located at the horizontal position [xPosition] on a staff whose
  /// top line is at [staffTopLeft.dy].
  void paintNote(
    Canvas canvas, {
    required Note note,
    required Offset staffTopLeft,
    required double xPosition,
    required ClefType clef,
    required bool showAccidental,
  }) {
    final position = StaffPosition.forPitch(note.pitch, clef);
    final noteCenter = Offset(
      xPosition,
      StaffGeometry.positionToY(position, staffTopLeft.dy),
    );

    paintSymbols(
      canvas,
      noteCenter: noteCenter,
      note: note,
      position: position,
      showAccidental: showAccidental,
    );

    // Quarter-note assumption: stem always present.
    final direction = StemRenderer.determineStemDirection(position);
    _stemRenderer.paint(
      canvas,
      noteCenter,
      direction: direction,
      color: note.color,
    );
  }
}
