// lib/src/notation/geometry/staff_geometry.dart

import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle;

import 'box.dart';
import 'staff_position.dart';
import 'staff_units.dart';

/// Pure geometry helpers shared by the notation renderers: converts staff
/// positions to pixel coordinates and paints ledger lines.
class StaffGeometry {
  /// Pixels (relative to a staff top line) of the given [position];
  /// position 0 is the bottom line, position 8 the top line.
  static StaffUnits positionToY(StaffPosition position, StaffUnits staffTop) {
    final inverted = 8.0 - position.value;
    return staffTop + StaffUnits.staffLineSpace*(inverted / 2);
  }

  /// Paints the ledger lines required by [position], centered on
  /// [noteCenter], using the standard engraving line length.
  static void paintLedgerLines(
    Canvas canvas,
    StaffOffset noteCenter,
    StaffPosition position,
  ) {
    Color color = const Color(0xFF000000);
    final ledgerPositions = position.getLedgerLinePositions();
    if (ledgerPositions.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = StaffUnits.ledgerLineThickness.value
      ..style = PaintingStyle.stroke;

    final noteheadWidth = StaffUnits.noteheadWidth;
    final extension = StaffUnits.ledgerLineExtension;
    final lineWidth = noteheadWidth + (extension * 2);

    for (final ledgerPos in ledgerPositions) {
      final y = noteCenter.dy + StaffUnits(position.value - ledgerPos) / 2;
      canvas.drawLine(
        Offset(noteCenter.dx.value - lineWidth.value / 2, y.value),
        Offset(noteCenter.dx.value + lineWidth.value / 2, y.value),
        paint,
      );
    }
  }
}
