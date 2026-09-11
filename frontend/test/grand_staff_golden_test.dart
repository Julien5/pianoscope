import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pianoscope/pianoscope.dart';

import 'helper.dart';

Future<void> _expectGolden(WidgetTester tester, String name, int? midi) async {
  final key = GlobalKey();

  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: RepaintBoundary(key: key, child: _grandStaffView(midi)),
        ),
      ),
    ),
  );
  await tester.pump();

  await expectLater(
    find.byKey(key),
    matchesGoldenFile('goldens/grand_staff_$name.png'),
  );
}

GrandStaffView _grandStaffView(int? midi) {
  return GrandStaffView(
    notes: midi == null
        ? const []
        : [
            Note(
              pitch: Pitch.fromMidiNumber(midi),
              duration: const NoteDuration.quarter(),
              velocity: 90,
              startBeat: 0,
            ),
          ],
  );
}

void main() {
  testWidgets('grand staff renders each note state correctly', (tester) async {
    await tester.runAsync(loadFonts);

    const cases = <String, int?>{
      'idle': null,
      'bass40': 40,
      'bass55': 55,
      'treble60': 60,
      'treble72': 72,
    };

    for (final entry in cases.entries) {
      await _expectGolden(tester, entry.key, entry.value);
    }
  });
}
