// lib/src/notation/rendering/stem_renderer.dart

import 'package:flutter/material.dart';
import '../geometry/box.dart';
import '../geometry/staff_position.dart';
import '../geometry/staff_units.dart';

/// Direction of a note stem
enum StemDirection {
  up, // Stem points upward
  down, // Stem points downward
  none, // No stem (whole notes)
}

/// Renders note stems
class StemRenderer {
  final Color color;

  const StemRenderer({this.color = Colors.black});

  /// Paint a stem from the notehead and return the stem end position
  StaffOffset paint(
    Canvas canvas,
    StaffOffset noteheadCenter, {
    required StemDirection direction,
    Color? color,
  }) {
    if (direction == StemDirection.none) return noteheadCenter;

    final thickness = StaffUnits.stemThickness;
    final length = StaffUnits.stemLength;
    final noteheadWidth = StaffUnits.noteheadWidth;

    final paint = Paint()
      ..color = color ?? this.color
      ..strokeWidth = thickness.value
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    StaffOffset stemStart;
    StaffOffset stemEnd;

    if (direction == StemDirection.up) {
      // Stem attaches to right side of notehead, goes up
      stemStart = StaffOffset(
        noteheadCenter.dx + noteheadWidth * (0.5),
        noteheadCenter.dy,
      );
      stemEnd = StaffOffset(stemStart.dx, stemStart.dy - length);
    } else {
      // Stem attaches to left side of notehead, goes down
      stemStart = StaffOffset(
        noteheadCenter.dx - noteheadWidth / 2,
        noteheadCenter.dy,
      );
      stemEnd = StaffOffset(stemStart.dx, stemStart.dy + length);
    }

    canvas.drawLine(stemStart.value(), stemEnd.value(), paint);

    return stemEnd; // Return stem end for flag attachment
  }

  /// Determine stem direction based on note position on staff
  /// Notes above the middle line have stems down, below have stems up
  static StemDirection determineStemDirection(StaffPosition position) {
    // Middle line is position 4
    if (position.value > 4) {
      return StemDirection.down; // High notes have stems down
    } else if (position.value < 4) {
      return StemDirection.up; // Low notes have stems up
    } else {
      // Notes on middle line: traditionally stem up, but we'll use up as default
      return StemDirection.up;
    }
  }

  /// Determine stem direction for a chord (multiple notes)
  /// Based on the average position of all notes
  static StemDirection determineStemDirectionForChord(
    List<StaffPosition> positions,
  ) {
    if (positions.isEmpty) return StemDirection.up;

    final averagePosition =
        positions.map((p) => p.value).reduce((a, b) => a + b) /
        positions.length;

    return averagePosition > 4 ? StemDirection.down : StemDirection.up;
  }
}
