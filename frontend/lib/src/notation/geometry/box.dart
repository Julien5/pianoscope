// lib/src/notation/geometry/box.dart

import 'dart:ui' show Offset, Size;

import 'package:flutter/rendering.dart';

/// An axis-aligned rectangle in canvas coordinates, the building block of
/// the notation layout: every element (brace, barline, staff, ...) owns one.
class Box {
  final Offset topLeft;
  final Size size;

  const Box({required this.topLeft, required this.size});

  double get left => topLeft.dx;
  double get top => topLeft.dy;
  double get right => left + size.width;
  double get bottom => top + size.height;

  double get width => size.width;
  double get height => size.height;

  double get centerX => left + width / 2;
  double get centerY => top + height / 2;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Box && topLeft == other.topLeft && size == other.size;

  @override
  int get hashCode => Object.hash(topLeft, size);

  @override
  String toString() => 'Box($topLeft, $size)';
}
