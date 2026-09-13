// lib/src/notation/grand_staff_layout.dart

import 'dart:ui' show Offset, Size;

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
  final double contentHeight;

  const GrandStaffLayout({
    required this.braceBox,
    required this.startBarlineBox,
    required this.finalBarlineBox,
    required this.upperStaff,
    required this.lowerStaff,
    required this.contentHeight,
  });

  /// Vertical padding above the upper staff and below the lower staff, as a
  /// multiple of [GrandStaffParameters.staffSpaceSize]: room for the treble
  /// clef glyph and for ledger lines.
  static const double kVerticalPadding = 3;

  /// Height of a single staff (5 lines = 4 spaces).
  static double staffHeight(double staffSpaceSize) => staffSpaceSize * 4;

  /// Overall content height for a given set of parameters, independent of the
  /// available width.
  static double contentHeightFor(GrandStaffParameters params) {
    final h = staffHeight(params.staffSpaceSize);
    final pad = kVerticalPadding * params.staffSpaceSize;
    return pad + h + params.staffGap + h + pad;
  }

  /// Compute the full layout for the available [size].
  factory GrandStaffLayout.fromParameters({
    required GrandStaffParameters params,
    required Size size,
    required KeySignature keySignature,
  }) {
    final s = params.staffSpaceSize;
    final h = staffHeight(s);
    final pad = kVerticalPadding * s;

    final upperTop = pad;
    final lowerTop = pad + h + params.staffGap;

    // Vertical extent shared by brace and barlines: both staves + the gap.
    final staffSpan = h + params.staffGap + h;
    final braceWidth = staffSpan * BraceRenderer.widthRatio;
    final barlineThickness = StaffUnits.barlineThickness.toPixels(s);

    final braceBox = Box(
      topLeft: Offset(0, pad),
      size: Size(braceWidth, staffSpan),
    );

    final startBarlineX = braceBox.right + params.braceToBarlineSpace;
    final startBarlineBox = Box(
      topLeft: Offset(startBarlineX, pad),
      size: Size(barlineThickness, staffSpan),
    );

    final clefX = startBarlineBox.right + params.barlineToClefSpace;
    final upperClefWidth = ClefRenderer.clefWidth(ClefType.treble, s);
    final lowerClefWidth = ClefRenderer.clefWidth(ClefType.bass, s);
    final keySigWidth = KeySignatureRenderer.keySignatureWidth(keySignature, s);
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
      topLeft: Offset(finalBarlineX, pad),
      size: Size(barlineThickness, staffSpan),
    );

    final linesLeft = startBarlineX;
    final linesWidth = finalBarlineX - startBarlineX >= 0
        ? finalBarlineX - startBarlineX
        : 0.0;

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
  static double _afterPrefix({
    required double clefWidth,
    required bool hasKeySig,
    required double keySigWidth,
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
    required double clefWidth,
    required double staffTop,
    required double clefX,
    required double notesRight,
    required double h,
    required bool hasKeySig,
    required double keySigWidth,
    required double notesLeft,
    required double linesLeft,
    required double linesWidth,
    required GrandStaffParameters params,
  }) {
    Box? keySignatureBox;
    if (hasKeySig) {
      keySignatureBox = Box(
        topLeft: Offset(
          clefX + clefWidth + params.clefToKeySignatureSpace,
          staffTop,
        ),
        size: Size(keySigWidth, h),
      );
    }

    final notesWidth = notesRight - notesLeft >= 0
        ? notesRight - notesLeft
        : 0.0;

    return StaffLayout(
      box: Box(topLeft: Offset(linesLeft, staffTop), size: Size(linesWidth, h)),
      clefBox: Box(topLeft: Offset(clefX, staffTop), size: Size(clefWidth, h)),
      keySignatureBox: keySignatureBox,
      notesBox: Box(
        topLeft: Offset(notesLeft, staffTop),
        size: Size(notesWidth, h),
      ),
    );
  }
}
