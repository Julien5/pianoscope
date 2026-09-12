import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pianoscope/pianoscope.dart';

Future<void> loadFonts() async {
  const fontDir = 'assets/fonts';
  final bravura = ByteData.sublistView(
    await File('$fontDir/Bravura.otf').readAsBytes(),
  );
  final petaluma = ByteData.sublistView(
    await File('$fontDir/Petaluma.otf').readAsBytes(),
  );
  final bravuraLoader = FontLoader('Bravura')..addFont(Future.value(bravura));
  final petalumaLoader = FontLoader('Petaluma')
    ..addFont(Future.value(petaluma));
  await bravuraLoader.load();
  await petalumaLoader.load();
}

Note note(int midi, {double beat = 0, Color? color}) {
  return Note(pitch: Pitch.fromMidiNumber(midi), color: color);
}

Future<void> expectGoldenFromView(
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
