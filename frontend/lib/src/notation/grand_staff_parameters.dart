// lib/src/notation/grand_staff_parameters.dart

import 'package:flutter/foundation.dart' show immutable;

/// User-set parameters of the grand staff rendering.
///
/// Horizontal layout (left to right):
///   [brace][brace space][start barline][clef space][clef][key sig space]
///       [key signature][key sig space][notes][final barline]
///
/// Vertical layout is derived from [staffSpaceSize] (see
/// `GrandStaffLayout`): the staves are separated by [staffGap], with
/// `3 * staffSpaceSize` padding above and below for clefs and ledger lines.
///
/// Margins around the staff are NOT part of these parameters: the painter
/// renders in fill-width mode from the top-left of the given [Size], so any
/// margin is the responsibility of the parent widget.
@immutable
class GrandStaffParameters {
  /// Distance between two adjacent staff lines; the unit of every derived
  /// measurement (noteheads, stems, clefs, ...).
  final double staffSpaceSize;

  /// Vertical distance between the bottom line of the upper staff and the
  /// top line of the lower staff.
  final double staffGap;

  /// Horizontal gap between the right edge of the brace and the start barline.
  final double braceToBarlineSpace;

  /// Horizontal gap between the start barline and the clef.
  final double barlineToClefSpace;

  /// Horizontal gap between the clef and the key signature.
  final double clefToKeySignatureSpace;

  /// Horizontal gap between the key signature (or the clef, when there is no
  /// key signature) and the notes.
  final double keySignatureToNotesSpace;

  const GrandStaffParameters({
    this.staffSpaceSize = 10,
    this.staffGap = 60,
    this.braceToBarlineSpace = 2.5,
    this.barlineToClefSpace = 10,
    this.clefToKeySignatureSpace = 10,
    this.keySignatureToNotesSpace = 60,
  });

  static const GrandStaffParameters defaults = GrandStaffParameters();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GrandStaffParameters &&
          staffSpaceSize == other.staffSpaceSize &&
          staffGap == other.staffGap &&
          braceToBarlineSpace == other.braceToBarlineSpace &&
          barlineToClefSpace == other.barlineToClefSpace &&
          clefToKeySignatureSpace == other.clefToKeySignatureSpace &&
          keySignatureToNotesSpace == other.keySignatureToNotesSpace;

  @override
  int get hashCode => Object.hash(
    staffSpaceSize,
    staffGap,
    braceToBarlineSpace,
    barlineToClefSpace,
    clefToKeySignatureSpace,
    keySignatureToNotesSpace,
  );

  @override
  String toString() =>
      'GrandStaffParameters(staffSpaceSize: $staffSpaceSize, '
      'staffGap: $staffGap, braceToBarlineSpace: $braceToBarlineSpace, '
      'barlineToClefSpace: $barlineToClefSpace, '
      'clefToKeySignatureSpace: $clefToKeySignatureSpace, '
      'keySignatureToNotesSpace: $keySignatureToNotesSpace)';
}