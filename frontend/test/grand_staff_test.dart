import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/widgets/grand_staff_view.dart';

void main() {
  testWidgets('grand staff paints for various notes', (WidgetTester tester) async {
    for (final note in <int?>[null, 40, 55, 60, 72]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GrandStaffView(midiNote: note, velocity: 90),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
