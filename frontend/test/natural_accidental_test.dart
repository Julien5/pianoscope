import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pianoscope/pianoscope.dart';
import 'package:pianoscope/src/notation/rendering/note_renderer.dart';

void main() {
  testWidgets('natural sign is painted when key signature requires it',
      (tester) async {
    const note = Note(
      pitch: Pitch(noteName: NoteName.C, octave: 4),
      duration: NoteDuration.quarter(),
      startBeat: 0,
    );

    late final bool withAccidentalPresent;
    late final bool withoutAccidentalPresent;
    late final Rect? withBounds;
    late final Rect? withoutBounds;
    await tester.runAsync(() async {
      final withAccidental = await _renderNoteCanvas(
        note: note,
        showAccidental: true,
      );
      final withoutAccidental = await _renderNoteCanvas(
        note: note,
        showAccidental: false,
      );
      withBounds = await _darkPixelBounds(withAccidental);
      withoutBounds = await _darkPixelBounds(withoutAccidental);
      withAccidentalPresent = withAccidental != null;
      withoutAccidentalPresent = withoutAccidental != null;
    });

    expect(withAccidentalPresent, isTrue);
    expect(withoutAccidentalPresent, isTrue);
    expect(withBounds, isNotNull, reason: 'notehead should be painted');
    expect(withoutBounds, isNotNull, reason: 'notehead should be painted');

    expect(
      withBounds!.left,
      lessThan(withoutBounds!.left),
      reason: 'accidental glyph must be painted to the left of the notehead',
    );
  });

  testWidgets('C natural in D major needs an explicit natural', (tester) async {
    expect(KeySignature.dMajor.needsAccidental(
      const Pitch(noteName: NoteName.C, octave: 4),
    ), isTrue);
  });

  testWidgets('C#4 in D major renders without an accidental glyph',
      (tester) async {
    const note = Note(
      pitch: Pitch(noteName: NoteName.C, accidental: Accidental.sharp, octave: 4),
      duration: NoteDuration.quarter(),
      startBeat: 0,
    );

    late final Rect? withLogicBounds;
    late final Rect? withoutAccidentalBounds;

    late bool showAccidental = true;

    await tester.runAsync(() async {
      // Simulate the painter's decision for C#4 in D major.
      showAccidental = KeySignature.dMajor.needsAccidental(note.pitch);
      final rendered = await _renderNoteCanvas(
        note: note,
        showAccidental: showAccidental,
      );
      final withoutAccidental = await _renderNoteCanvas(
        note: note,
        showAccidental: false,
      );
      withLogicBounds = await _darkPixelBounds(rendered);
      withoutAccidentalBounds = await _darkPixelBounds(withoutAccidental);
    });

    expect(showAccidental, isFalse, reason: 'C#4 is in the D major key signature');
    expect(withLogicBounds, isNotNull);
    expect(withoutAccidentalBounds, isNotNull);

    expect(
      withLogicBounds!.left,
      withoutAccidentalBounds!.left,
      reason: 'no accidental glyph may appear left of the notehead',
    );
  });

  testWidgets('C#4 in D major needs no accidental (it is in the key signature)', (tester) async {
    expect(KeySignature.dMajor.needsAccidental(
      const Pitch(noteName: NoteName.C, accidental: Accidental.sharp, octave: 4),
    ), isFalse);
  });

  testWidgets('F#4 in G major needs no accidental (it is in the key signature)', (tester) async {
    expect(KeySignature.gMajor.needsAccidental(
      const Pitch(noteName: NoteName.F, accidental: Accidental.sharp, octave: 4),
    ), isFalse);
  });

  testWidgets('F natural in G major needs an explicit sharp', (tester) async {
    expect(KeySignature.gMajor.needsAccidental(
      const Pitch(noteName: NoteName.F, octave: 4),
    ), isTrue);
  });

  testWidgets('B flat in F major needs no accidental', (tester) async {
    expect(KeySignature.fMajor.needsAccidental(
      const Pitch(noteName: NoteName.B, accidental: Accidental.flat, octave: 3),
    ), isFalse);
  });

  testWidgets('B natural in F major needs an explicit natural', (tester) async {
    expect(KeySignature.fMajor.needsAccidental(
      const Pitch(noteName: NoteName.B, octave: 3),
    ), isTrue);
  });
}

Future<ui.Image?> _renderNoteCanvas({
  required Note note,
  required bool showAccidental,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, 400, 200),
  );

  // White background.
  canvas.drawRect(
    Rect.fromLTWH(0, 0, 400, 200),
    Paint()..color = Colors.white,
  );

  final renderer = NoteRenderer(staffSpaceSize: 10);
  renderer.paintNote(
    canvas,
    note: note,
    staffTopLeft: const Offset(0, 100),
    xPosition: 200,
    clef: ClefType.treble,
    showAccidental: showAccidental,
  );

  final image = await recorder.endRecording().toImage(400, 200);
  return image;
}

Future<Rect?> _darkPixelBounds(ui.Image? image) async {
  if (image == null) return null;
final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
    .buffer
    .asUint8List();
  int? minX, maxX, minY, maxY;
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final i = (y * image.width + x) * 4;
      final r = bytes[i];
      final g = bytes[i + 1];
      final b = bytes[i + 2];
      final a = bytes[i + 3];
      if (a > 0 && r < 200 && g < 200 && b < 200) {
        if (minX == null || x < minX) minX = x;
        if (maxX == null || x > maxX) maxX = x;
        if (minY == null || y < minY) minY = y;
        if (maxY == null || y > maxY) maxY = y;
      }
    }
  }
  if (minX == null) return null;
  return Rect.fromLTRB(minX.toDouble(), minY!.toDouble(), maxX!.toDouble(),
      maxY!.toDouble());
}