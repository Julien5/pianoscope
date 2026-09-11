import 'package:flutter_test/flutter_test.dart';
import 'package:pianoscope/pianoscope.dart';

import 'helper.dart';

void main() {
  testWidgets('grand staff renders each note state correctly', (tester) async {
    await tester.runAsync(loadFonts);

    const cases = <String, int?>{
      'idle': null,
      'bass_note_40': 40,
      'bass_note_55': 55,
      'treble_note_60': 60,
      'treble_note_72': 72,
    };

    for (final entry in cases.entries) {
      await expectGoldenFromView(
        tester,
        entry.key,
        GrandStaffView(
          notes: entry.value == null ? const [] : [note(entry.value!)],
        ),
      );
    }
  });
}
