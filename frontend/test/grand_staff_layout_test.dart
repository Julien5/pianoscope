import 'package:flutter_test/flutter_test.dart';
import 'package:pianoscope/pianoscope.dart';
import 'package:pianoscope/src/notation/geometry/box.dart';
import 'package:pianoscope/src/notation/grand_staff_parameters.dart';
import 'package:pianoscope/src/notation/grand_staff_layout.dart';
import 'package:pianoscope/src/notation/rendering/key_signature_renderer.dart';
import 'package:pianoscope/src/notation/rendering/clef_renderer.dart';

void main() {
  group('GrandStaffLayout', () {
    const params = GrandStaffParameters();
    final size = StaffSize(StaffUnits(80.0), StaffUnits(60));

    test('content height derives from staffSpaceSize and staffGap', () {
      expect(
        GrandStaffLayout.contentHeightFor(const GrandStaffParameters()).value,
        200,
      );
      expect(
        GrandStaffLayout.contentHeightFor(
          const GrandStaffParameters(staffGap: StaffUnits(8)),
        ).value,
        // 2 * padding(30) + 2 * staffHeight(40) + gap
        2 * 30 + 2 * 40 + 80, // 220
      );
    });

    test(
      'brace and barlines span both staves (excluding vertical padding)',
      () {
        final layout = GrandStaffLayout.fromParameters(
          params: params,
          size: size,
          keySignature: KeySignature.cMajor,
        );

        const pad = 30.0;
        const staffSpan = 40 + 60 + 40;

        expect(layout.braceBox.top.value, pad);
        expect(layout.braceBox.height.value, staffSpan);
        expect(layout.braceBox.left.value, 0);
        expect(layout.braceBox.width.value, closeTo(staffSpan * 0.0776, 0.001));

        expect(layout.startBarlineBox.top.value, pad);
        expect(layout.startBarlineBox.height.value, staffSpan);
        expect(
          layout.startBarlineBox.left,
          layout.braceBox.right + params.braceToBarlineSpace,
        );
        expect(layout.startBarlineBox.width.value, 1.5);

        expect(layout.finalBarlineBox.top.value, pad);
        expect(layout.finalBarlineBox.height.value, staffSpan);
        expect(layout.finalBarlineBox.right, size.width);
      },
    );

    test('staffs are stacked with the explicit gap', () {
      final layout = GrandStaffLayout.fromParameters(
        params: params,
        size: size,
        keySignature: KeySignature.cMajor,
      );

      expect(layout.upperStaff.box.top.value, 30);
      expect(layout.lowerStaff.box.top.value, 30 + 40 + 60);
      expect(layout.upperStaff.box.height.value, 40);
      expect(layout.lowerStaff.box.height.value, 40);

      // Both staffs span from the start barline to the final barline.
      expect(layout.upperStaff.box.left, layout.startBarlineBox.left);
      expect(layout.upperStaff.box.right, layout.finalBarlineBox.left);
      expect(layout.lowerStaff.box.left, layout.startBarlineBox.left);
      expect(layout.lowerStaff.box.right, layout.finalBarlineBox.left);
    });

    test('boxes are ordered left to right and notes align across staffs', () {
      final layout = GrandStaffLayout.fromParameters(
        params: params,
        size: size,
        keySignature: KeySignature.cMajor,
      );

      expect(
        layout.braceBox.right,
        lessThanOrEqualTo(layout.startBarlineBox.left),
      );
      expect(
        layout.startBarlineBox.right,
        lessThanOrEqualTo(layout.upperStaff.clefBox.left),
      );
      expect(
        layout.upperStaff.clefBox.right,
        lessThanOrEqualTo(layout.upperStaff.notesBox.left),
      );
      expect(layout.upperStaff.notesBox.right, layout.finalBarlineBox.left);

      // Noteheads across the two staffs must share the same x origin.
      expect(layout.upperStaff.notesBox.left, layout.lowerStaff.notesBox.left);
      // Note origins sit at the widest clef prefix.
      expect(
        layout.upperStaff.notesBox.left,
        layout.upperStaff.clefBox.left +
            ClefRenderer.clefWidth(ClefType.treble) +
            params.keySignatureToNotesSpace,
      );
    });

    test('key signature adds a box and delays the notes', () {
      final withKeySig = GrandStaffLayout.fromParameters(
        params: params,
        size: size,
        keySignature: KeySignature.dMajor,
      );
      final without = GrandStaffLayout.fromParameters(
        params: params,
        size: size,
        keySignature: KeySignature.cMajor,
      );

      expect(without.upperStaff.keySignatureBox, isNull);
      expect(withKeySig.upperStaff.keySignatureBox, isNotNull);
      expect(
        withKeySig.upperStaff.keySignatureBox!.width,
        KeySignatureRenderer.keySignatureWidth(KeySignature.dMajor),
      );
      expect(
        withKeySig.upperStaff.keySignatureBox!.left,
        withKeySig.upperStaff.clefBox.right + params.clefToKeySignatureSpace,
      );

      expect(
        withKeySig.upperStaff.notesBox.left,
        greaterThan(without.upperStaff.notesBox.left),
      );
    });

    test('the notes box fills the remaining width', () {
      final layout = GrandStaffLayout.fromParameters(
        params: params,
        size: StaffSize(StaffUnits(40), StaffUnits(20)),
        keySignature: KeySignature.cMajor,
      );

      expect(layout.upperStaff.notesBox.right.value, 400 - 1.5);
      expect(
        layout.upperStaff.notesBox.width,
        greaterThan(layout.upperStaff.notesBox.height),
      );
    });
  });
}
