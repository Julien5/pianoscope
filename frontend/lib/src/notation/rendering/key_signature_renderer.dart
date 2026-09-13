// lib/src/notation/rendering/key_signature_renderer.dart

import 'package:flutter/material.dart';
import '../geometry/staff_units.dart';
import '../models/key_signature.dart';
import '../geometry/box.dart';
import '../geometry/staff_position.dart';
import 'glyph_provider.dart';

/// Renders key signature symbols (sharps or flats) after the clef.
class KeySignatureRenderer {
  final Box box;
  final KeySignature keySignature;
  final ClefType clefType;
  final Color color;

  const KeySignatureRenderer({
    required this.box,
    required this.keySignature,
    required this.clefType,
    this.color = Colors.black,
  });

  /// Paint the key signature into its box (left-aligned).
  void paint(Canvas canvas) {
    if (keySignature.accidentals == 0) return;

    final positions = _getAccidentalPositions(keySignature, clefType);
    final glyphCode = keySignature.usesSharps
        ? GlyphProvider.sharp
        : GlyphProvider.flat;

    final size = StaffUnits(2.5);
    final spacing = StaffUnits(1.2);

    for (int i = 0; i < positions.length; i++) {
      final position = positions[i];
      final textPainter = GlyphProvider.getGlyphPainter(glyphCode, size);
      final glyphSize = GlyphProvider.getGlyphSize(glyphCode, size);

      final y = box.top + (position / 2) - (glyphSize.height / 2);
      final accidentalX = box.left + (spacing * (i as double));

      textPainter.paint(canvas, Offset(accidentalX.value, y.value));
    }
  }

  /// Get staff positions for accidentals based on clef and key signature.
  List<StaffUnits> _getAccidentalPositions(
    KeySignature keySignature,
    ClefType clefType,
  ) {
    final count = keySignature.accidentals.abs();

    if (keySignature.usesSharps) {
      return _getSharpPositions(clefType, count);
    } else {
      return _getFlatPositions(clefType, count);
    }
  }

  /// Get positions for sharps in order: F C G D A E B
  List<StaffUnits> _getSharpPositions(ClefType clefType, int count) {
    switch (clefType) {
      case ClefType.treble:
        const positions = [0.0, 3.0, -1.0, 2.0, 5.0, 1.0, 4.0];
        return positions.map((x) => StaffUnits(x)).take(count).toList();
      case ClefType.bass:
        const positions = [2.0, 5.0, 1.0, 4.0, 7.0, 3.0, 6.0];
        return positions.map((x) => StaffUnits(x)).take(count).toList();
      case ClefType.alto:
        const positions = [1.0, 5.0, 0.0, 4.0, 7.0, 2.0, 6.0];
        return positions.map((x) => StaffUnits(x)).take(count).toList();
      case ClefType.tenor:
        const positions = [6.0, 2.0, 5.0, 1.0, 4.0, 0.0, 3.0];
        return positions.map((x) => StaffUnits(x)).take(count).toList();
    }
  }

  /// Get positions for flats in order: B E A D G C F
  List<StaffUnits> _getFlatPositions(ClefType clefType, int count) {
    switch (clefType) {
      case ClefType.treble:
        const positions = [4.0, 1.0, 5.0, 2.0, 6.0, 3.0, 7.0];
        return positions.map((x) => StaffUnits(x)).take(count).toList();
      case ClefType.bass:
        const positions = [6.0, 3.0, 7.0, 4.0, 8.0, 5.0, 9.0];
        return positions.map((x) => StaffUnits(x)).take(count).toList();
      case ClefType.alto:
        const positions = [5.0, 2.0, 6.0, 3.0, 7.0, 4.0, 8.0];
        return positions.map((x) => StaffUnits(x)).take(count).toList();
      case ClefType.tenor:
        const positions = [3.0, 0.0, 4.0, 1.0, 5.0, 2.0, 6.0];
        return positions.map((x) => StaffUnits(x)).take(count).toList();
    }
  }

  /// Width occupied by the key signature at the given staff spacing.
  /// Used by the layout engine; 0 when there is no key signature.
  static StaffUnits keySignatureWidth(KeySignature keySignature) {
    if (keySignature.accidentals == 0) return StaffUnits(0);

    final count = keySignature.accidentals.abs();
    final spacing = 1.2;
    return StaffUnits((count * spacing) + 1);
  }
}
