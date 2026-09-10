import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pianoscope/pianoscope.dart';

void main() {
  testWidgets('grand staff paints for various notes', (WidgetTester tester) async {
    for (final note in <int?>[null, 40, 55, 60, 72]) {
      final notes = note == null
          ? const <Note>[]
          : [
              Note(
                pitch: Pitch.fromMidiNumber(note),
                duration: const NoteDuration.quarter(),
                velocity: 90,
                startBeat: 0,
              ),
            ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GrandStaffView(notes: notes),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}