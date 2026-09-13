// lib/src/notation/grand_staff_layout.dart

import 'dart:ui' show Size;

import 'grand_staff_parameters.dart';
import 'models/key_signature.dart';
import 'geometry/box.dart';
import 'geometry/staff_position.dart';
import 'geometry/staff_units.dart';
import 'rendering/brace_renderer.dart';
import 'rendering/clef_renderer.dart';
import 'rendering/key_signature_renderer.dart';

/// Boxes for one staff of the grand staff: the lines region, the clef, the
/// key signature (if any) and the notes.
class StaffLayout {
  final Box box;
  final Box clefBox;
  final Box? keySignatureBox;
  final Box notesBox;

  const StaffLayout({
    required this.box,
    required this.clefBox,
    this.keySignatureBox,
    required this.notesBox,
  });
}

/// Computes the box of every grand-staff element from the available [Size]
/// and the [GrandStaffParameters]. Pure geometry: no canvas involved.
///
/// Layout, left to right:
///   [braceBox][brace space][startBarlineBox][clef space][clefBox]
///   [key sig space][keySignatureBox?][key sig space][notesBox][finalBarlineBox]
///
/// The notes of both staves start at the same x (the wider clef/key-signature
/// prefix wins), so noteheads across staves stay vertically aligned.
class GrandStaffLayout {
  final Box braceBox;
  final Box startBarlineBox;
  final Box finalBarlineBox;
  final StaffLayout upperStaff;
  final StaffLayout lowerStaff;
  final StaffUnits contentHeight;

  const GrandStaffLayout({
    required this.braceBox,
    required this.startBarlineBox,
    required this.finalBarlineBox,
    required this.upperStaff,
    required this.lowerStaff,
    required this.contentHeight,
  });

  /// Vertical padding above the upper staff and below the lower staff.
  static const StaffUnits kVerticalPadding = StaffUnits(3.0);

  /// Height of a single staff (5 lines = 4 spaces).
  static StaffUnits staffHeight() => StaffUnits(4);

  /// Overall content height for a given set of parameters, independent of the
  /// available width.
  static StaffUnits contentHeightFor(GrandStaffParameters params) {
    final h = staffHeight();
    final pad = kVerticalPadding;
    return pad + h + params.staffGap + h + pad;
  }

  /// Compute the full layout for the available [size].
  factory GrandStaffLayout.fromParameters({
    required GrandStaffParameters params,
    required StaffSize size,
    required KeySignature keySignature,
  }) {
    final h = staffHeight();
    final pad = kVerticalPadding;

    final upperTop = pad;
    final lowerTop = pad + h + params.staffGap;

    // Vertical extent shared by brace and barlines: both staves + the gap.
    final staffSpan = h + params.staffGap + h;
    final braceWidth = staffSpan * BraceRenderer.widthRatio;
    final barlineThickness = StaffUnits.barlineThickness;
    final braceBox = Box(
      topLeft: StaffOffset(StaffUnits(0), pad),
      size: StaffSize(braceWidth, staffSpan),
    );

    final startBarlineX = braceBox.right + params.braceToBarlineSpace;
    final startBarlineBox = Box(
      topLeft: StaffOffset(startBarlineX, pad),
      size: StaffSize(barlineThickness, staffSpan),
    );

    final clefX = startBarlineBox.right + params.barlineToClefSpace;
    final upperClefWidth = ClefRenderer.clefWidth(ClefType.treble);
    final lowerClefWidth = ClefRenderer.clefWidth(ClefType.bass);
    final keySigWidth = KeySignatureRenderer.keySignatureWidth(keySignature);
    final hasKeySig = keySignature.accidentals != 0;

    // Notes must align across staves: right-align the clef/key-signature
    // prefix, so both note boxes start at the widest end of the two.
    final upperPrefix = _afterPrefix(
      clefWidth: upperClefWidth,
      hasKeySig: hasKeySig,
      keySigWidth: keySigWidth,
      params: params,
    );
    final lowerPrefix = _afterPrefix(
      clefWidth: lowerClefWidth,
      hasKeySig: hasKeySig,
      keySigWidth: keySigWidth,
      params: params,
    );
    final notesLeft =
        clefX + (upperPrefix > lowerPrefix ? upperPrefix : lowerPrefix);

    final finalBarlineX = size.width - barlineThickness;
    final finalBarlineBox = Box(
      topLeft: StaffOffset(finalBarlineX, pad),
      size: StaffSize(barlineThickness, staffSpan),
    );

    final linesLeft = startBarlineX;
    final linesWidth = finalBarlineX - startBarlineX;
    assert(linesWidth >= StaffUnits(0));

    return GrandStaffLayout(
      braceBox: braceBox,
      startBarlineBox: startBarlineBox,
      finalBarlineBox: finalBarlineBox,
      upperStaff: _staffLayout(
        clefWidth: upperClefWidth,
        staffTop: upperTop,
        clefX: clefX,
        notesRight: finalBarlineX,
        h: h,
        hasKeySig: hasKeySig,
        keySigWidth: keySigWidth,
        notesLeft: notesLeft,
        linesLeft: linesLeft,
        linesWidth: linesWidth,
        params: params,
      ),
      lowerStaff: _staffLayout(
        clefWidth: lowerClefWidth,
        staffTop: lowerTop,
        clefX: clefX,
        notesRight: finalBarlineX,
        h: h,
        hasKeySig: hasKeySig,
        keySigWidth: keySigWidth,
        notesLeft: notesLeft,
        linesLeft: linesLeft,
        linesWidth: linesWidth,
        params: params,
      ),
      contentHeight: contentHeightFor(params),
    );
  }

  /// Horizontal space consumed after the clef (clef-to-keysig gap, key
  /// signature and keysig-to-notes gap) before the notes start.
  static StaffUnits _afterPrefix({
    required StaffUnits clefWidth,
    required bool hasKeySig,
    required StaffUnits keySigWidth,
    required GrandStaffParameters params,
  }) {
    if (hasKeySig) {
      return clefWidth +
          params.clefToKeySignatureSpace +
          keySigWidth +
          params.keySignatureToNotesSpace;
    }
    return clefWidth + params.keySignatureToNotesSpace;
  }

  static StaffLayout _staffLayout({
    required StaffUnits clefWidth,
    required StaffUnits staffTop,
    required StaffUnits clefX,
    required StaffUnits notesRight,
    required StaffUnits h,
    required bool hasKeySig,
    required StaffUnits keySigWidth,
    required StaffUnits notesLeft,
    required StaffUnits linesLeft,
    required StaffUnits linesWidth,
    required GrandStaffParameters params,
  }) {
    Box? keySignatureBox;
    if (hasKeySig) {
      keySignatureBox = Box(
        topLeft: StaffOffset(
          clefX + clefWidth + params.clefToKeySignatureSpace,
          staffTop,
        ),
        size: StaffSize(keySigWidth, h),
      );
    }

    final notesWidth = notesRight - notesLeft >= StaffUnits(0)
        ? notesRight - notesLeft
        : StaffUnits(0);

    return StaffLayout(
      box: Box(
        topLeft: StaffOffset(linesLeft, staffTop),
        size: StaffSize(linesWidth, h),
      ),
      clefBox: Box(
        topLeft: StaffOffset(clefX, staffTop),
        size: StaffSize(clefWidth, h),
      ),
      keySignatureBox: keySignatureBox,
      notesBox: Box(
        topLeft: StaffOffset(notesLeft, staffTop),
        size: StaffSize(notesWidth, h),
      ),
    );
  }
}
