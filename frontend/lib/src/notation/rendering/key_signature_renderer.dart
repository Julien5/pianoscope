// lib/src/notation/rendering/key_signature_renderer.dart

import 'package:flutter/material.dart';
import '../models/key_signature.dart';
import '../geometry/box.dart';
import '../geometry/staff_position.dart';
import 'glyph_provider.dart';

/// Renders key signature symbols (sharps or flats) after the clef.
class KeySignatureRenderer {
  final Box box;
  final KeySignature keySignature;
  final ClefType clefType;
  final double staffSpaceSize;
  final Color color;

  const KeySignatureRenderer({
    required this.box,
    required this.keySignature,
    required this.clefType,
    required this.staffSpaceSize,
    this.color = Colors.black,
  });

  /// Paint the key signature into its box (left-aligned).
  void paint(Canvas canvas) {
    if (keySignature.accidentals == 0) return;

    final positions = _getAccidentalPositions(keySignature, clefType);
    final glyphCode = keySignature.usesSharps
        ? GlyphProvider.sharp
        : GlyphProvider.flat;

    final size = staffSpaceSize * 2.5;
    final spacing = staffSpaceSize * 1.2;

    for (int i = 0; i < positions.length; i++) {
      final position = positions[i];
      final textPainter = GlyphProvider.getGlyph(glyphCode, size, color: color);

      final y = box.top +
          (position * staffSpaceSize / 2) -
          textPainter.height / 2;
      final accidentalX = box.left + (i * spacing);

      textPainter.paint(canvas, Offset(accidentalX, y));
    }
  }

  /// Get staff positions for accidentals based on clef and key signature.
  List<double> _getAccidentalPositions(
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
  List<double> _getSharpPositions(ClefType clefType, int count) {
    switch (clefType) {
      case ClefType.treble:
        const positions = [0.0, 3.0, -1.0, 2.0, 5.0, 1.0, 4.0];
        return positions.take(count).toList();
      case ClefType.bass:
        const positions = [2.0, 5.0, 1.0, 4.0, 7.0, 3.0, 6.0];
        return positions.take(count).toList();
      case ClefType.alto:
        const positions = [1.0, 5.0, 0.0, 4.0, 7.0, 2.0, 6.0];
        return positions.take(count).toList();
      case ClefType.tenor:
        const positions = [6.0, 2.0, 5.0, 1.0, 4.0, 0.0, 3.0];
        return positions.take(count).toList();
    }
  }

  /// Get positions for flats in order: B E A D G C F
  List<double> _getFlatPositions(ClefType clefType, int count) {
    switch (clefType) {
      case ClefType.treble:
        const positions = [4.0, 1.0, 5.0, 2.0, 6.0, 3.0, 7.0];
        return positions.take(count).toList();
      case ClefType.bass:
        const positions = [6.0, 3.0, 7.0, 4.0, 8.0, 5.0, 9.0];
        return positions.take(count).toList();
      case ClefType.alto:
        const positions = [5.0, 2.0, 6.0, 3.0, 7.0, 4.0, 8.0];
        return positions.take(count).toList();
      case ClefType.tenor:
        const positions = [3.0, 0.0, 4.0, 1.0, 5.0, 2.0, 6.0];
        return positions.take(count).toList();
    }
  }

  /// Width occupied by the key signature at the given staff spacing.
  /// Used by the layout engine; 0 when there is no key signature.
  static double keySignatureWidth(
    KeySignature keySignature,
    double staffSpaceSize,
  ) {
    if (keySignature.accidentals == 0) return 0;

    final count = keySignature.accidentals.abs();
    final spacing = staffSpaceSize * 1.2;

    return (count * spacing) + staffSpaceSize;
  }
}