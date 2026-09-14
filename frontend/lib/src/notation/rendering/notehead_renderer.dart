// lib/src/notation/rendering/notehead_renderer.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../geometry/box.dart';
import '../geometry/staff_units.dart';

/// Renders noteheads (filled or hollow ovals)
class NoteheadRenderer {
  /// Paint a notehead at the given center position
  void paint(Canvas canvas, StaffOffset center, {Color? color}) {
    final width = StaffUnits.noteheadWidth.value;
    final height = StaffUnits.noteheadHeight.value;

    // Save canvas state for rotation
    canvas.save();
    canvas.translate(center.dx.value, center.dy.value);

    // Rotate notehead slightly for traditional appearance (-20 degrees)
    canvas.rotate(-20 * math.pi / 180);

    // Create oval path
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: height,
    );

    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill
      ..strokeWidth = 0;

    canvas.drawOval(rect, paint);
    // canvas.drawCircle(rect.center,rect.width/2,paint);
    
    canvas.restore();
  }
}
