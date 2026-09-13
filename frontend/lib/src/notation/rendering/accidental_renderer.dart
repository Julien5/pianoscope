// lib/src/notation/rendering/accidental_renderer.dart

import 'package:flutter/material.dart';
import '../models/pitch.dart';
import '../geometry/staff_units.dart';
import 'glyph_provider.dart';

/// Renders accidental symbols (sharp, flat, natural, etc.)
class AccidentalRenderer {
  final Color color;

  const AccidentalRenderer({this.color = Colors.black});

  /// Paint an accidental to the left of a note
  void paint(
    Canvas canvas,
    Offset noteheadCenter,
    Accidental accidental, {
    Color? color,
  }) {
    final size = StaffUnits.accidentalHeight.value;
    final glyph = GlyphProvider.getGlyph(
      GlyphProvider.getAccidentalGlyph(accidental),
      size,
      color: color ?? this.color,
    );

    // Position accidental to the left of notehead
    final noteheadWidth = StaffUnits.noteheadWidth.value;
    final padding = StaffUnits.accidentalPadding.value;

    final x = noteheadCenter.dx - noteheadWidth / 2 - padding - glyph.width;
    final y = noteheadCenter.dy - glyph.height / 2;

    glyph.paint(canvas, Offset(x, y));
  }
}
