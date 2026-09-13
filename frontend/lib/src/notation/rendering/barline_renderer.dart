// lib/src/notation/rendering/barline_renderer.dart

import 'package:flutter/material.dart';
import '../geometry/box.dart';
import '../geometry/staff_units.dart';

/// Types of barlines.
///
/// Only a plain single barline is needed for a single-measure grand staff
/// (start and final barline).
enum BarlineType {
  single, // Regular barline (|)
}

/// Renders a barline filling its box (typically spanning both staves).
class BarlineRenderer {
  final Box box;
  final Color color;

  const BarlineRenderer({required this.box, this.color = Colors.black});

  /// Paint the barline into its box.
  void paint(Canvas canvas, BarlineType type) {
    switch (type) {
      case BarlineType.single:
        _drawSingleBarline(canvas);
    }
  }

  void _drawSingleBarline(Canvas canvas) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = StaffUnits.barlineThickness.value
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(box.centerX.value, box.top.value),
      Offset(box.centerX.value, box.bottom.value),
      paint,
    );
  }
}
