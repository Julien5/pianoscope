// lib/src/geometry/staff_units.dart

/// All measurements in music notation are based on "staff spaces"
/// (the distance between two adjacent staff lines)
///
/// This class provides type-safe measurements that scale consistently
class StaffUnits {
  final double value;

  const StaffUnits(this.value);

  /// Standard spacing constants based on music engraving practice

  // Notehead dimensions
  static const noteheadWidth = StaffUnits(13);
  static const noteheadHeight = StaffUnits(10);

  // Stem dimensions
  static const stemThickness = StaffUnits(1.2);
  static const stemLength = StaffUnits(35);

  // Accidental dimensions
  static const accidentalWidth = StaffUnits(10);
  static const accidentalHeight = StaffUnits(20);

  // Spacing
  static const minimumNoteSpacing = StaffUnits(20);
  static const accidentalPadding = StaffUnits(3);
  static const ledgerLineExtension = StaffUnits(
    4,
  ); // How far ledger lines extend beyond notehead

  // Line thicknesses
  static const staffLineThickness = StaffUnits(1);
  static const ledgerLineThickness = StaffUnits(1.2);
  static const barlineThickness = StaffUnits(1.5);
  static const thickBarlineThickness = StaffUnits(5);
  static const beamThickness = StaffUnits(5);

  // Clef sizes
  static const trebleClefHeight = StaffUnits(70.0);
  static const bassClefHeight = StaffUnits(40.0);

  // Dots (for dotted notes)
  static const dotRadius = StaffUnits(2);
  static const dotSpacing = StaffUnits(7); // Space between note and dot

  // Flag dimensions
  static const flagWidth = StaffUnits(12);
  static const flagHeight = StaffUnits(20);

  /// Arithmetic operators for convenient calculations
  StaffUnits operator +(StaffUnits other) => StaffUnits(value + other.value);
  StaffUnits operator -(StaffUnits other) => StaffUnits(value - other.value);
  StaffUnits operator *(double factor) => StaffUnits(value * factor);
  StaffUnits operator /(double divisor) => StaffUnits(value / divisor);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StaffUnits && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'StaffUnits($value)';
}
