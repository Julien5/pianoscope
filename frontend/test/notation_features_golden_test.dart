import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pianoscope/pianoscope.dart';

import 'helper.dart';

Future<void> _expectGolden(
  WidgetTester tester,
  String name,
  GrandStaffView view,
) async {
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
          child: RepaintBoundary(key: key, child: view),
        ),
      ),
    ),
  );
  await tester.pump();

  await expectLater(
    find.byKey(key),
    matchesGoldenFile('goldens/notation_$name.png'),
  );
}

Note _note(int midi, {double beat = 0, Color? color}) {
  return Note(
    pitch: Pitch.fromMidiNumber(midi),
    duration: const NoteDuration.quarter(),
    velocity: 90,
    startBeat: beat,
    color: color,
  );
}

void main() {
  testWidgets('notation features render correctly', (tester) async {
    await tester.runAsync(loadFonts);

    // Chord: C4 + E4 + G4 on the treble staff at the same beat.
    await _expectGolden(
      tester,
      'chord',
      GrandStaffView(notes: [_note(60), _note(64), _note(67)]),
    );

    // Key signature: G major (one sharp) with an F# note in the key.
    await _expectGolden(
      tester,
      'keysig_sharp',
      GrandStaffView(
        notes: [_note(66)], // F#4 -> sharp is in the key, no accidental glyph
        keySignature: KeySignature.gMajor,
      ),
    );

    // Key signature: D major with a C# note in the key (no extra sharp).
    await _expectGolden(
      tester,
      'keysig_in_key_csharp',
      GrandStaffView(
        notes: [_note(61)], // C#4 -> is in the key, no accidental glyph
        keySignature: KeySignature.dMajor,
      ),
    );

    // Key signature with a note outside the key (needs accidental glyph).
    await _expectGolden(
      tester,
      'keysig_out_of_key',
      GrandStaffView(
        notes: [_note(62)], // D4 natural, not in G major -> no accidental
        keySignature: KeySignature.gMajor,
      ),
    );

    // Natural sign: C4 in D major (C# is in the key, so natural needs a sign).
    await _expectGolden(
      tester,
      'keysig_natural',
      GrandStaffView(
        notes: [_note(60)], // C4 natural -> explicit natural glyph
        keySignature: KeySignature.dMajor,
      ),
    );

    // Flat key repurpose: F4 natural in B-flat major needs a natural sign.
    await _expectGolden(
      tester,
      'keysig_natural_flat',
      GrandStaffView(
        notes: [_note(53)], // F4 natural
        keySignature: KeySignature.bFlatMajor,
      ),
    );

    // Sequential notes in one measure.
    await _expectGolden(
      tester,
      'sequential',
      GrandStaffView(notes: [_note(60, beat: 0), _note(64, beat: 1)]),
    );

    // Gray/ghost note (per-note color override).
    await _expectGolden(
      tester,
      'ghost',
      GrandStaffView(notes: [_note(60, color: Colors.black38)]),
    );
  });
}
