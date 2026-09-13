import 'dart:ui';

import '../../../pianoscope.dart';

class StaffOffset {
  StaffUnits dx;
  StaffUnits dy;
  StaffOffset(StaffUnits x, StaffUnits y) : dx = x, dy = y;

  Offset value() {
    return Offset(dx.value, dy.value);
  }
}

class StaffSize {
  StaffUnits width;
  StaffUnits height;
  StaffSize(StaffUnits x, StaffUnits y) : width = x, height = y;
  Size value() {
    return Size(width.value, width.value);
  }
}

/// An axis-aligned rectangle in canvas coordinates, the building block of
/// the notation layout: every element (brace, barline, staff, ...) owns one.
class Box {
  final StaffOffset topLeft;
  final StaffSize size;

  const Box({required this.topLeft, required this.size});

  StaffUnits get left => topLeft.dx;
  StaffUnits get top => topLeft.dy;
  StaffUnits get right => left + size.width;
  StaffUnits get bottom => top + size.height;

  StaffUnits get width => size.width;
  StaffUnits get height => size.height;

  StaffUnits get centerX => left + width / 2;
  StaffUnits get centerY => top + height / 2;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Box && topLeft == other.topLeft && size == other.size;

  @override
  int get hashCode => Object.hash(topLeft, size);

  @override
  String toString() => 'Box($topLeft, $size)';
}
