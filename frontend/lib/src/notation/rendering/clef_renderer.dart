// lib/src/notation/rendering/clef_renderer.dart

import 'package:flutter/material.dart';
import '../geometry/box.dart';
import '../geometry/staff_position.dart';
import 'glyph_provider.dart';

/// Renders clef symbols at the beginning of a staff.
class ClefRenderer {
  final Box box;
  final ClefType clefType;
  final Color color;

  const ClefRenderer({
    required this.box,
    required this.clefType,
    this.color = Colors.black,
  });

  /// Paint the clef into its box. The box top is the top line of the staff;
  /// the glyph may overflow above the box (into the reserved padding).
  void paint(Canvas canvas) {
    switch (clefType) {
      case ClefType.treble:
        _drawGlyph(canvas, GlyphProvider.trebleClef, 4.5, -6.25);
        break;
      case ClefType.bass:
        _drawGlyph(canvas, GlyphProvider.bassClef, 4.0, -7);
        break;
      case ClefType.alto:
        _drawGlyph(canvas, GlyphProvider.altoClef, 4.0, -6.1);
        break;
      case ClefType.tenor:
        _drawGlyph(canvas, GlyphProvider.tenorClef, 4.0, -7.1);
        break;
    }
  }

  void _drawGlyph(
    Canvas canvas,
    String glyphCode,
    double size,
    double yOffset,
  ) {
    final glyph = GlyphProvider.getGlyph(glyphCode, size, color: color);
    glyph.paint(canvas, Offset(box.left, box.top + yOffset));
  }

  /// Width occupied by a clef of the given [type] at the given staff spacing,
  /// matching the glyph size actually drawn. Used by the layout engine.
  static double clefWidth(ClefType type) {
    final size = type == ClefType.treble ? 4.5 : 4.0;
    final glyphCode = type == ClefType.treble
        ? GlyphProvider.trebleClef
        : (type == ClefType.bass
              ? GlyphProvider.bassClef
              : GlyphProvider.altoClef);
    final glyph = GlyphProvider.getGlyph(glyphCode, size);
    return glyph.width;
  }
}
