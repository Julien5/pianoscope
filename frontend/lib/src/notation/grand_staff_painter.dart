// lib/src/notation/grand_staff_painter.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'models/key_signature.dart';
import 'models/note.dart';
import 'geometry/staff_position.dart';
import 'rendering/note_renderer.dart';
import 'rendering/clef_renderer.dart';
import 'rendering/key_signature_renderer.dart';
import 'rendering/barline_renderer.dart';
import 'rendering/brace_renderer.dart';

/// CustomPainter that renders a single-measure grand staff (treble above,
/// bass below) from a flat list of notes.
///
/// Notes at or above [splitPoint] go on the treble staff, notes below on the
/// bass staff. Notes sharing a [Note.startBeat] are painted as a chord;
/// notes at different beats are laid out left to right within the single
/// measure.
class GrandStaffPainter extends CustomPainter {
  final List<Note> notes;
  final KeySignature keySignature;
  final int splitPoint;
  final double staffSpaceSize;
  final double grandStaffGap;
  final double leftMargin;
  final double rightMargin;
  final double topMargin;
  final double leadingSpace;
  final double barlineToClefSpace;
  final double measureSpacing;
  final double baseSpacing;
  final double minSpacing;
  final double maxSpacing;
  final bool showBrace;
  final bool expandWidth;

  const GrandStaffPainter({
    this.notes = const [],
    this.keySignature = KeySignature.cMajor,
    this.splitPoint = 60,
    this.staffSpaceSize = 10,
    this.grandStaffGap = 60,
    this.leftMargin = 20,
    this.rightMargin = 20,
    this.topMargin = 30,
    this.leadingSpace = 60,
    this.barlineToClefSpace = 10,
    this.measureSpacing = 40,
    this.baseSpacing = 40,
    this.minSpacing = 20,
    this.maxSpacing = 120,
    this.showBrace = true,
    this.expandWidth = true,
  });

  /// Height of one staff (5 lines = 4 spaces).
  double get staffHeight => staffSpaceSize * 4;

  @override
  void paint(Canvas canvas, Size size) {
    final noteRenderer = NoteRenderer(
      staffSpaceSize: staffSpaceSize,
      color: Colors.black,
    );
    final clefRenderer = ClefRenderer(
      staffSpaceSize: staffSpaceSize,
      color: Colors.black,
    );
    final keySignatureRenderer = KeySignatureRenderer(
      staffSpaceSize: staffSpaceSize,
      color: Colors.black,
    );
    final barlineRenderer = BarlineRenderer(
      staffSpaceSize: staffSpaceSize,
      color: Colors.black,
    );
    final braceRenderer = BraceRenderer(
      staffSpaceSize: staffSpaceSize,
      color: Colors.black,
    );

    final upperStaffY = topMargin;
    final lowerStaffY = topMargin + staffHeight + grandStaffGap;
    final braceTotalHeight = (lowerStaffY + staffHeight) - upperStaffY;

    // Draw brace connecting both staves.
    if (showBrace) {
      final braceX = leftMargin -
          braceRenderer.getWidth(height: braceTotalHeight) -
          staffSpaceSize / 4;
      braceRenderer.paint(
        canvas,
        braceX,
        upperStaffY,
        lowerStaffY,
        staffHeight,
      );
    }

    // Shared start barline (left of the first system, after the brace).
    barlineRenderer.paint(
      canvas,
      leftMargin,
      upperStaffY,
      lowerStaffY + staffHeight,
      BarlineType.single,
    );

    // Split notes by register.
    final upperNotes = notes
        .where((n) => n.pitch.midiNumber >= splitPoint)
        .toList();
    final lowerNotes = notes
        .where((n) => n.pitch.midiNumber < splitPoint)
        .toList();

    // The spacing engine must see the union of upper and lower notes, keyed
    // by beat, so a note on an otherwise-empty staff gets a non-zero width.
    final unionReps = <double, Note>{};
    for (final note in [...upperNotes, ...lowerNotes]) {
      unionReps.putIfAbsent(note.startBeat, () => note);
    }
    final unionBeats = unionReps.keys.toList()..sort();
    final flatElements = unionBeats.map((beat) => unionReps[beat]!).toList();

    final lineWidth = size.width - rightMargin;
    final positions = _calculatePositions(flatElements, leftMargin, lineWidth);

    final contentX = _contentStartX(keySignatureRenderer);
    final xOffset = contentX - leftMargin;

    // Measure end, used for the staff width when not expanding.
    final measureEndX = positions.isNotEmpty
        ? positions.last + minSpacing + xOffset
        : contentX;
    final staffWidth = expandWidth
        ? lineWidth - leftMargin
        : measureEndX - leftMargin;

    _paintStaff(
      canvas,
      upperNotes,
      unionBeats,
      positions,
      xOffset,
      ClefType.treble,
      upperStaffY,
      staffWidth,
      clefRenderer,
      keySignatureRenderer,
      noteRenderer,
    );
    _paintStaff(
      canvas,
      lowerNotes,
      unionBeats,
      positions,
      xOffset,
      ClefType.bass,
      lowerStaffY,
      staffWidth,
      clefRenderer,
      keySignatureRenderer,
      noteRenderer,
    );

    // Final barline (flushed to the right edge when expanding the width).
    barlineRenderer.paint(
      canvas,
      lineWidth,
      upperStaffY,
      lowerStaffY + staffHeight,
      BarlineType.single,
    );
  }

  /// X position where the clef and key signature are painted (before notes).
  double _contentStartX(KeySignatureRenderer keySignatureRenderer) {
    double currentX = leftMargin + barlineToClefSpace;
    currentX += 35 + staffSpaceSize;
    if (keySignature.accidentals != 0) {
      currentX += keySignatureRenderer.getWidth(keySignature);
    }
    currentX += leadingSpace;
    return currentX;
  }

  void _paintStaff(
    Canvas canvas,
    List<Note> staffNotes,
    List<double> unionBeats,
    List<double> positions,
    double xOffset,
    ClefType clef,
    double staffY,
    double staffWidth,
    ClefRenderer clefRenderer,
    KeySignatureRenderer keySignatureRenderer,
    NoteRenderer noteRenderer,
  ) {
    final staffTopLeft = Offset(leftMargin, staffY);

    // Clef and key signature.
    double currentX = leftMargin + barlineToClefSpace;
    clefRenderer.paint(canvas, currentX, staffY, clef);
    currentX += 35 + staffSpaceSize;
    if (keySignature.accidentals != 0) {
      keySignatureRenderer.paint(canvas, currentX, staffY, keySignature, clef);
    }

    // Beat index within the union ordering.
    final beatIndex = <double, int>{};
    for (int i = 0; i < unionBeats.length; i++) {
      beatIndex[unionBeats[i]] = i;
    }

    final elementsByBeat = <double, List<Note>>{};
    for (final note in staffNotes) {
      elementsByBeat.putIfAbsent(note.startBeat, () => []).add(note);
    }
    final sortedBeats = elementsByBeat.keys.toList()..sort();

    final seenPitchClasses = <int>{};
    for (final beat in sortedBeats) {
      final notesAtBeat = elementsByBeat[beat]!;
      final xPosition = positions[beatIndex[beat]!] + xOffset;

      if (notesAtBeat.length == 1) {
        final note = notesAtBeat.first;
        final pitchClass = note.pitch.midiNumber % 12;
        final needsAccidental = keySignature.needsAccidental(note.pitch);
        final showAccidental =
            needsAccidental && !seenPitchClasses.contains(pitchClass);

        if (showAccidental) seenPitchClasses.add(pitchClass);

        noteRenderer.paintNote(
          canvas,
          note: note,
          staffTopLeft: staffTopLeft,
          xPosition: xPosition,
          clef: clef,
          showAccidental: showAccidental,
        );
      } else {
        final chord = Chord(notes: notesAtBeat);
        final chordAccidentals = <int>{};

        for (final note in notesAtBeat) {
          final pitchClass = note.pitch.midiNumber % 12;
          final needsAccidental = keySignature.needsAccidental(note.pitch);
          if (needsAccidental && !seenPitchClasses.contains(pitchClass)) {
            chordAccidentals.add(note.pitch.midiNumber);
            seenPitchClasses.add(pitchClass);
          }
        }

        noteRenderer.paintChord(
          canvas,
          chord: chord,
          staffTopLeft: staffTopLeft,
          xPosition: xPosition,
          clef: clef,
          notesShowingAccidentals: chordAccidentals,
        );
      }
    }

    // Staff lines.
    noteRenderer.staffRenderer.paint(canvas, staffTopLeft, staffWidth);
  }

  /// Proportional duration-based spacing for a single measure, mirroring the
  /// upstream spacing engine (two-stage scaling: fill the available width,
  /// then clamp per-element spacing).
  List<double> _calculatePositions(
    List<dynamic> elements,
    double startX,
    double lineWidth,
  ) {
    if (elements.isEmpty) return <double>[];

    final availableWidth = lineWidth - startX;
    final durations = elements.map<double>((e) => e.duration.beats).toList();
    final weights = _calculateSpacingWeights(durations);
    final idealTotalWidth = weights.reduce((a, b) => a + b);

    // Minimum measure width (positions from startX=0, plus min spacing).
    final minWidth = elements.length == 1
        ? minSpacing
        : weights.take(weights.length - 1).reduce((a, b) => a + b) + minSpacing;

    final scaleFactor = availableWidth > minWidth
        ? availableWidth / minWidth
        : 1.0;
    final targetWidth = minWidth * scaleFactor;

    if (elements.length == 1) return [startX];

    final usableWidth = targetWidth - startX - minSpacing;
    final spacingScale = idealTotalWidth > 0
        ? (usableWidth / idealTotalWidth).clamp(0.3, 3.0)
        : 0.0;

    final positions = <double>[startX];
    double currentX = startX;
    for (int i = 0; i < weights.length - 1; i++) {
      final spacing = (weights[i] * spacingScale).clamp(minSpacing, maxSpacing);
      currentX += spacing;
      positions.add(currentX);
    }
    return positions;
  }

  List<double> _calculateSpacingWeights(List<double> durations) {
    final weights = <double>[];
    for (int i = 0; i < durations.length; i++) {
      final currentDuration = durations[i];
      final nextDuration = i < durations.length - 1
          ? durations[i + 1]
          : currentDuration;
      final avgDuration = (currentDuration + nextDuration) / 2;
      final weight = _log2(avgDuration + 1) * baseSpacing;
      weights.add(weight);
    }
    return weights;
  }

  double _log2(double x) {
    return (x > 0) ? (log(x.clamp(0.1, 100)) / log(2.0)) : 0;
  }

  @override
  bool shouldRepaint(GrandStaffPainter oldDelegate) {
    return oldDelegate.notes != notes ||
        oldDelegate.keySignature != keySignature ||
        oldDelegate.splitPoint != splitPoint ||
        oldDelegate.staffSpaceSize != staffSpaceSize ||
        oldDelegate.grandStaffGap != grandStaffGap ||
        oldDelegate.leftMargin != leftMargin ||
        oldDelegate.rightMargin != rightMargin ||
        oldDelegate.topMargin != topMargin ||
        oldDelegate.leadingSpace != leadingSpace ||
        oldDelegate.barlineToClefSpace != barlineToClefSpace ||
        oldDelegate.measureSpacing != measureSpacing ||
        oldDelegate.baseSpacing != baseSpacing ||
        oldDelegate.minSpacing != minSpacing ||
        oldDelegate.maxSpacing != maxSpacing ||
        oldDelegate.showBrace != showBrace ||
        oldDelegate.expandWidth != expandWidth;
  }
}