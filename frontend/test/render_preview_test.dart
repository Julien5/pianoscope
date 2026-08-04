import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/widgets/grand_staff_view.dart';

const _fontDir = '/home/julien/projects/flutter_music_notation/assets/fonts';

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

Future<void> _capture(WidgetTester tester, String name, int? midi) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Center(
        child: RepaintBoundary(
          key: key,
          child: GrandStaffView(midiNote: midi, velocity: 90),
        ),
      ),
    ),
  );
  await tester.pump();

  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    File('/tmp/opencode/preview_$name.png')
        .writeAsBytesSync(byteData!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('render previews', (tester) async {
    await tester.runAsync(_loadFonts);

    const cases = <String, int?>{
      'null': null,
      'bass40': 40,
      'bass55': 55,
      'treble60': 60,
      'treble72': 72,
    };

    for (final entry in cases.entries) {
      await _capture(tester, entry.key, entry.value);
    }
  });
}
