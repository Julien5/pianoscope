// lib/src/notation/rendering/lines_renderer.dart

import 'package:flutter/material.dart';
import '../geometry/box.dart';
import '../geometry/staff_units.dart';

/// Renders the five staff lines filling a box (from the start barline to the
/// final barline).
class LinesRenderer {
  final Box box;
  final double staffSpaceSize;
  final Color color;

  const LinesRenderer({
    required this.box,
    required this.staffSpaceSize,
    this.color = Colors.black,
  });

  /// Paint the staff lines into the box.
  void paint(Canvas canvas) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = StaffUnits.staffLineThickness.toPixels(staffSpaceSize)
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 5; i++) {
      final y = box.top + (i * staffSpaceSize);
      canvas.drawLine(
        Offset(box.left, y),
        Offset(box.right, y),
        paint,
      );
    }
  }
}