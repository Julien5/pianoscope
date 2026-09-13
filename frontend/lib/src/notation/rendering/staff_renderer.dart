// lib/src/notation/rendering/staff_renderer.dart

import 'package:flutter/material.dart';
import '../models/key_signature.dart';
import '../models/note.dart';
import '../grand_staff_layout.dart';
import '../geometry/staff_position.dart';
import 'lines_renderer.dart';
import 'clef_renderer.dart';
import 'key_signature_renderer.dart';
import 'notes_renderer.dart';

/// Paints one staff of the grand staff: staff lines, clef, key signature and
/// notes (a single chord), each in its own box from [layout].
class StaffRenderer {
  final StaffLayout layout;
  final ClefType clef;
  final List<Note> notes;
  final KeySignature keySignature;
  final Color color;

  const StaffRenderer({
    required this.layout,
    required this.clef,
    required this.notes,
    required this.keySignature,
    this.color = Colors.black,
  });

  /// Paint the complete staff into its boxes.
  void paintStaff(Canvas canvas) {
    LinesRenderer(box: layout.box, color: color).paint(canvas);

    ClefRenderer(
      box: layout.clefBox,
      clefType: clef,
      color: color,
    ).paint(canvas);

    final keySignatureBox = layout.keySignatureBox;
    if (keySignatureBox != null) {
      KeySignatureRenderer(
        box: keySignatureBox,
        keySignature: keySignature,
        clefType: clef,
        color: color,
      ).paint(canvas);
    }

    if (notes.isNotEmpty) {
      // Spell each note enharmonically for this key signature so notehead
      // position and accidentals are correct (e.g. 70 -> Bb in Bb major).
      final spelled = notes
          .map((n) => n.copyWith(pitch: keySignature.spell(n.pitch)))
          .toList();
      NotesRenderer(
        box: layout.notesBox,
        notes: spelled,
        keySignature: keySignature,
        clef: clef,
        color: color,
      ).paint(canvas);
    }
  }
}
