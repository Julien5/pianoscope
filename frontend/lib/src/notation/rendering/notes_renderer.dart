// lib/src/notation/rendering/notes_renderer.dart

import 'package:flutter/material.dart';
import '../geometry/staff_units.dart';
import '../models/key_signature.dart';
import '../models/note.dart';
import '../geometry/box.dart';
import '../geometry/staff_position.dart';
import '../geometry/staff_geometry.dart';
import 'note_renderer.dart';
import 'stem_renderer.dart';

/// Paints a group of simultaneous notes (a chord) into a notes box.
///
/// The chord is laid out at the left edge of [box]; noteheads, ledgers and
/// accidentals are painted per note, and a single stem is drawn for the whole
/// chord (direction chosen from the average position, as is conventional).
class NotesRenderer {
  final Box box;
  final List<Note> notes;
  final KeySignature keySignature;
  final ClefType clef;
  final Color color;

  NotesRenderer({
    required this.box,
    required this.notes,
    required this.keySignature,
    required this.clef,
    this.color = Colors.black,
  });

  /// Paint the chord into its box.
  void paint(Canvas canvas) {
    if (notes.isEmpty) return;

    final noteRenderer = NoteRenderer();
    final stemRenderer = StemRenderer();

    final sorted = List<Note>.from(notes)
      ..sort((a, b) => a.pitch.midiNumber.compareTo(b.pitch.midiNumber));
    final positions = sorted
        .map((n) => StaffPosition.forPitch(n.pitch, clef))
        .toList();

    final direction = sorted.length == 1
        ? StemRenderer.determineStemDirection(positions.first)
        : StemRenderer.determineStemDirectionForChord(positions);

    final seenPitchClasses = <int>{};
    for (int i = 0; i < sorted.length; i++) {
      final note = sorted[i];
      final position = positions[i];
      final pitchClass = note.pitch.midiNumber % 12;
      final needsAccidental = keySignature.needsAccidental(note.pitch);
      final showAccidental =
          needsAccidental && !seenPitchClasses.contains(pitchClass);
      if (showAccidental) {
        seenPitchClasses.add(pitchClass);
      }

      final noteCenter = StaffOffset(
        box.left,
        StaffGeometry.positionToY(position, box.top),
      );

      noteRenderer.paintSymbols(
        canvas,
        noteCenter: noteCenter,
        note: note,
        position: position,
        showAccidental: showAccidental,
        // Stagger accidentals vertically in tight chords to avoid overlap.
        accidentalX: StaffUnits(i.toDouble()) * (-0.5),
      );
    }

    // Single stem for the whole chord, from the extreme note.
    final extremeNote = direction == StemDirection.up
        ? sorted.last
        : sorted.first;
    final extremePosition = StaffPosition.forPitch(extremeNote.pitch, clef);
    final extremeCenter = StaffOffset(
      box.left,
      StaffGeometry.positionToY(extremePosition, box.top),
    );

    stemRenderer.paint(
      canvas,
      extremeCenter,
      direction: direction,
      color: extremeNote.color,
    );
  }
}
