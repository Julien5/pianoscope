import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/widgets/grand_staff_view.dart';

const _fontDir = '../../flutter_music_notation/assets/fonts';

Future<void> _loadFonts() async {
  final bravura = ByteData.sublistView(
      await File('$_fontDir/Bravura.otf').readAsBytes());
  final petaluma = ByteData.sublistView(
      await File('$_fontDir/Petaluma.otf').readAsBytes());
  final bravuraLoader = FontLoader('Bravura')..addFont(Future.value(bravura));
  final petalumaLoader = FontLoader('Petaluma')..addFont(Future.value(petaluma));
  await bravuraLoader.load();
  await petalumaLoader.load();
}

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
          child: RepaintBoundary(
            key: key,
            child: GrandStaffView(midiNote: midi, velocity: 90),
          ),
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

void main() {
  testWidgets('grand staff renders each note state correctly', (tester) async {
    await tester.runAsync(_loadFonts);

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
