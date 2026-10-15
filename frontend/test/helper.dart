import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pianoscope/pianoscope.dart';
import 'package:pianoscope/src/rust/api/report.dart';

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

/// Stands in for the Rust side, so a widget test can drive code that reaches
/// [RustLib] without loading the native library. Nothing here talks to a real
/// upload: the point is only that the boundary exists.
class FakeUploadSession implements UploadSession {
  @override
  void dispose() {}

  @override
  bool get isDisposed => false;

  @override
  void cancel() {}

  @override
  Future<UploadOutcome> upload({required String filename}) async =>
      const UploadOutcome(cancelled: false, error: '');
}

/// Install this once per test file, before any test touches [RustLib]:
/// `RustLib.initMock(api: FakeRustLibApi())`.
class FakeRustLibApi implements RustLibApi {
  @override
  UploadSession crateApiReportUploadSessionNew() => FakeUploadSession();

  @override
  Future<List<String>> crateApiReportReportsList() async => [];

  // `BaseApi` is empty and nothing else is reached from a widget test. A
  // missing method should fail loudly rather than silently return null.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}
