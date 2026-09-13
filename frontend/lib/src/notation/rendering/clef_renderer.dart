// lib/src/notation/rendering/clef_renderer.dart

import 'package:flutter/material.dart';
import '../geometry/box.dart';
import '../geometry/staff_position.dart';
import '../geometry/staff_units.dart';
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
        _drawGlyph(
          canvas,
          GlyphProvider.trebleClef,
          StaffUnits(4.5),
          StaffUnits(-6.25),
        );
        break;
      case ClefType.bass:
        _drawGlyph(
          canvas,
          GlyphProvider.bassClef,
          StaffUnits(4.0),
          StaffUnits(-7.0),
        );
        break;
      case ClefType.alto:
        _drawGlyph(
          canvas,
          GlyphProvider.altoClef,
          StaffUnits(4.0),
          StaffUnits(-6.1),
        );
        break;
      case ClefType.tenor:
        _drawGlyph(
          canvas,
          GlyphProvider.tenorClef,
          StaffUnits(4.0),
          StaffUnits(-7.1),
        );
        break;
    }
  }

  void _drawGlyph(
    Canvas canvas,
    String glyphCode,
    StaffUnits size,
    StaffUnits yOffset,
  ) {
    final glyph = GlyphProvider.getGlyphPainter(glyphCode, size);
    glyph.paint(canvas, Offset(box.left.value, box.top.value + yOffset.value));
  }

  /// Width occupied by a clef of the given [type] at the given staff spacing,
  /// matching the glyph size actually drawn. Used by the layout engine.
  static StaffUnits clefWidth(ClefType type) {
    final StaffUnits size = type == ClefType.treble
        ? StaffUnits(4.5)
        : StaffUnits(4.0);
    final glyphCode = type == ClefType.treble
        ? GlyphProvider.trebleClef
        : (type == ClefType.bass
              ? GlyphProvider.bassClef
              : GlyphProvider.altoClef);
    return GlyphProvider.getGlyphWidth(glyphCode, size);
  }
}
