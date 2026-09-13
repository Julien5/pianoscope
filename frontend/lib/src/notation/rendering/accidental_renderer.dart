// lib/src/notation/rendering/accidental_renderer.dart

import 'package:flutter/material.dart';
import '../geometry/box.dart';
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
    StaffOffset noteheadCenter,
    Accidental accidental, {
    Color? color,
  }) {
    final size = StaffUnits.accidentalHeight;
    final glyphSize = GlyphProvider.getGlyphSize(
      GlyphProvider.getAccidentalGlyph(accidental),
      size,
    );
    final glyph = GlyphProvider.getGlyphPainter(
      GlyphProvider.getAccidentalGlyph(accidental),
      size,
    );

    // Position accidental to the left of notehead
    final noteheadWidth = StaffUnits.noteheadWidth;
    final padding = StaffUnits.accidentalPadding;

    final x = noteheadCenter.dx - noteheadWidth / 2 - padding - glyphSize.width;
    final y = noteheadCenter.dy - glyphSize.height / 2;

    glyph.paint(canvas, Offset(x.value, y.value));
  }
}
