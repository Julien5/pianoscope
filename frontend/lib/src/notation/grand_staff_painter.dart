// lib/src/notation/grand_staff_painter.dart

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

// ignore: unused_import
import 'geometry/box.dart';
import 'geometry/staff_units.dart';
import 'grand_staff_parameters.dart';
import 'grand_staff_layout.dart';
import 'models/key_signature.dart';
import 'models/note.dart';
import 'geometry/staff_position.dart';
import 'rendering/brace_renderer.dart';
import 'rendering/barline_renderer.dart';
import 'rendering/staff_renderer.dart';

/// CustomPainter that renders a single-measure grand staff (treble above,
/// bass below) from a flat list of notes.
///
/// Notes at or above [splitPoint] go on the treble staff, notes below on the
/// bass staff. All notes on a staff are painted as a single chord.
///
/// The painter fills the available width and lays the staff out from the
/// top-left of the given [Size]; any margin is handled by the parent widget.
class GrandStaffPainter extends CustomPainter {
  final GrandStaffParameters params;
  final List<Note> notes;
  final KeySignature keySignature;
  final int splitPoint;

  const GrandStaffPainter({
    this.params = GrandStaffParameters.defaults,
    this.notes = const [],
    this.keySignature = KeySignature.cMajor,
    this.splitPoint = 60,
    this.centerVertically = true,
  });

  /// If true, the painter will center the staff content vertically inside
  /// the available `size`. When the available height is smaller than the
  /// content height, the painter draws top-aligned (no negative translate).
  final bool centerVertically;

  @override
  void paint(Canvas canvas, Size size) {
    double scale = 10.0 / StaffUnits.kUnit;
    canvas.save();
    canvas.scale(scale);
    final layout = GrandStaffLayout.fromParameters(
      params: params,
      size: StaffSize(
        StaffUnits.fromUnits(size.width / scale),
        StaffUnits.fromUnits(size.height / scale),
      ),
      keySignature: keySignature,
    );

    // Optionally center the content vertically when there is extra space.
    if (centerVertically) {
      final availableUnits = StaffUnits.fromUnits(size.height / scale);
      final extra = availableUnits - layout.contentHeight;
      if (extra > StaffUnits(0)) {
        final shift = (extra / 2).value;
        // Translate in the current (scaled) canvas coordinate system.
        canvas.translate(0, shift);
      }
    }

    BraceRenderer(box: layout.braceBox).paint(canvas);

    BarlineRenderer(
      box: layout.startBarlineBox,
    ).paint(canvas, BarlineType.single);

    BarlineRenderer(
      box: layout.finalBarlineBox,
    ).paint(canvas, BarlineType.single);

    final upperNotes = notes
        .where((n) => n.pitch.midiNumber >= splitPoint)
        .toList();

    final lowerNotes = notes
        .where((n) => n.pitch.midiNumber < splitPoint)
        .toList();

    StaffRenderer(
      layout: layout.upperStaff,
      clef: ClefType.treble,
      notes: upperNotes,
      keySignature: keySignature,
    ).paintStaff(canvas);

    StaffRenderer(
      layout: layout.lowerStaff,
      clef: ClefType.bass,
      notes: lowerNotes,
      keySignature: keySignature,
    ).paintStaff(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(GrandStaffPainter oldDelegate) {
    return oldDelegate.params != params ||
        !listEquals(oldDelegate.notes, notes) ||
        oldDelegate.keySignature != keySignature ||
        oldDelegate.splitPoint != splitPoint;
  }
}

class KeyTilePainter extends CustomPainter {
  final KeySignature keySignature;

  KeyTilePainter({this.keySignature = KeySignature.cMajor});

  @override
  void paint(Canvas canvas, Size size) {
    double scale = 9.0 / StaffUnits.kUnit;
    canvas.save();
    canvas.scale(scale);

    final layout = GrandStaffLayout.fromParameters(
      params: GrandStaffParameters.keytile,
      size: StaffSize(
        StaffUnits.fromUnits(size.width / scale),
        StaffUnits.fromUnits(size.height / scale),
      ),
      keySignature: keySignature,
    );

    final width = layout.startBarlineBox.size.width;
    Box startBarlineBox = Box(
      topLeft: layout.startBarlineBox.topLeft,
      size: StaffSize(width, layout.upperStaff.box.size.height),
    );
    Box finalBarlineBox = Box(
      topLeft: layout.finalBarlineBox.topLeft,
      size: StaffSize(width, layout.upperStaff.box.size.height),
    );

    BarlineRenderer(box: startBarlineBox).paint(canvas, BarlineType.single);

    BarlineRenderer(box: finalBarlineBox).paint(canvas, BarlineType.single);

    StaffRenderer(
      layout: layout.upperStaff,
      clef: ClefType.treble,
      notes: [],
      keySignature: keySignature,
    ).paintStaff(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(KeyTilePainter oldDelegate) {
    return oldDelegate.keySignature != keySignature;
  }
}
