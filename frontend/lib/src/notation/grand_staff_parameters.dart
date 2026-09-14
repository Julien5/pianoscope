// lib/src/notation/grand_staff_parameters.dart

import 'package:flutter/foundation.dart' show immutable;

import '../../pianoscope.dart';

/// User-set parameters of the grand staff rendering.
///
/// Horizontal layout (left to right):
///   [brace][brace space][start barline][clef space][clef][key sig space]
///       [key signature][key sig space][notes][final barline]
///
/// Vertical layout:
/// `GrandStaffLayout`: the staves are separated by [staffGap], with
/// `3` padding above and below for clefs and ledger lines.
///
/// Margins around the staff are NOT part of these parameters: the painter
/// renders in fill-width mode from the top-left of the given [Size], so any
/// margin is the responsibility of the parent widget.
@immutable
class GrandStaffParameters {
  /// Vertical distance between the bottom line of the upper staff and the
  /// top line of the lower staff.
  final StaffUnits staffGap;

  /// Horizontal gap between the right edge of the brace and the start barline.
  final StaffUnits braceToBarlineSpace;

  /// Horizontal gap between the start barline and the clef.
  final StaffUnits barlineToClefSpace;

  /// Horizontal gap between the clef and the key signature.
  final StaffUnits clefToKeySignatureSpace;

  /// Horizontal gap between the key signature (or the clef, when there is no
  /// key signature) and the notes.
  final StaffUnits keySignatureToNotesSpace;

  const GrandStaffParameters({
    this.staffGap = const StaffUnits(6),
    this.braceToBarlineSpace = const StaffUnits(0.25),
    this.barlineToClefSpace = const StaffUnits(1.0),
    this.clefToKeySignatureSpace = const StaffUnits(1),
    this.keySignatureToNotesSpace = const StaffUnits(6),
  });

  static const GrandStaffParameters defaults = GrandStaffParameters();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GrandStaffParameters &&
          staffGap == other.staffGap &&
          braceToBarlineSpace == other.braceToBarlineSpace &&
          barlineToClefSpace == other.barlineToClefSpace &&
          clefToKeySignatureSpace == other.clefToKeySignatureSpace &&
          keySignatureToNotesSpace == other.keySignatureToNotesSpace;

  @override
  int get hashCode => Object.hash(
    staffGap,
    braceToBarlineSpace,
    barlineToClefSpace,
    clefToKeySignatureSpace,
    keySignatureToNotesSpace,
  );

  @override
  String toString() =>
      'GrandStaffParameters('
      'staffGap: $staffGap, braceToBarlineSpace: $braceToBarlineSpace, '
      'barlineToClefSpace: $barlineToClefSpace, '
      'clefToKeySignatureSpace: $clefToKeySignatureSpace, '
      'keySignatureToNotesSpace: $keySignatureToNotesSpace)';
}
