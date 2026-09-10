import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pianoscope/pianoscope.dart';

const _fontDir = 'assets/fonts';

Future<void> _loadFonts() async {
  final bravura = ByteData.sublistView(
    await File('$_fontDir/Bravura.otf').readAsBytes(),
  );
  final petaluma = ByteData.sublistView(
    await File('$_fontDir/Petaluma.otf').readAsBytes(),
  );
  final bravuraLoader = FontLoader('Bravura')..addFont(Future.value(bravura));
  final petalumaLoader = FontLoader('Petaluma')
    ..addFont(Future.value(petaluma));
  await bravuraLoader.load();
  await petalumaLoader.load();
}

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
    await tester.runAsync(_loadFonts);

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
        notes: [_note(65)], // F#4 -> sharp is in the key, no accidental glyph
        keySignature: KeySignature.gMajor,
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