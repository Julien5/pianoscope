// lib/src/notation/rendering/notehead_renderer.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../geometry/staff_units.dart';

/// Renders noteheads (filled or hollow ovals)
class NoteheadRenderer {
  final double staffSpaceSize;
  final Color color;

  const NoteheadRenderer({
    required this.staffSpaceSize,
    this.color = Colors.black,
  });

  /// Paint a notehead at the given center position
  void paint(Canvas canvas, Offset center, {Color? color}) {
    final width = StaffUnits.noteheadWidth.toPixels(staffSpaceSize);
    final height = StaffUnits.noteheadHeight.toPixels(staffSpaceSize);

    // Save canvas state for rotation
    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Rotate notehead slightly for traditional appearance (-20 degrees)
    canvas.rotate(-20 * math.pi / 180);

    // Create oval path
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: height,
    );

    final paint = Paint()
      ..color = color ?? this.color
      ..style = PaintingStyle.fill
      ..strokeWidth = 0;

    canvas.drawOval(rect, paint);
    canvas.restore();
  }
}
