import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pianoscope/pianoscope.dart';

import 'helper.dart';

void main() {
  testWidgets('notation features render correctly', (tester) async {
    await tester.runAsync(loadFonts);

    await expectGoldenFromView(
      tester,
      'note_60_64_67',
      GrandStaffView(notes: [note(60), note(64), note(67)]),
    );

    await expectGoldenFromView(
      tester,
      'keysig_D_note_72',
      GrandStaffView(notes: [note(72)], keySignature: KeySignature.dMajor),
    );

    await expectGoldenFromView(
      tester,
      'keysig_D_note_73',
      GrandStaffView(notes: [note(73)], keySignature: KeySignature.dMajor),
    );

    await expectGoldenFromView(
      tester,
      'keysig_Bb_note_70',
      GrandStaffView(notes: [note(70)], keySignature: KeySignature.bFlatMajor),
    );

    // Gray/ghost note (per-note color override).
    await expectGoldenFromView(
      tester,
      'note_60_gray',
      GrandStaffView(notes: [note(60, color: Colors.black38)]),
    );
  });
}
