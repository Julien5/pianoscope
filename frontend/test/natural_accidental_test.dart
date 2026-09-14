import 'package:flutter_test/flutter_test.dart';
import 'package:pianoscope/pianoscope.dart';

void main() {
  testWidgets('C natural in D major needs an explicit natural', (tester) async {
    expect(
      KeySignature.dMajor.needsAccidental(
        const Pitch(noteName: NoteName.C, octave: 4),
      ),
      isTrue,
    );
  });

  testWidgets(
    'C#4 in D major needs no accidental (it is in the key signature)',
    (tester) async {
      expect(
        KeySignature.dMajor.needsAccidental(
          const Pitch(
            noteName: NoteName.C,
            accidental: Accidental.sharp,
            octave: 4,
          ),
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'F#4 in G major needs no accidental (it is in the key signature)',
    (tester) async {
      expect(
        KeySignature.gMajor.needsAccidental(
          const Pitch(
            noteName: NoteName.F,
            accidental: Accidental.sharp,
            octave: 4,
          ),
        ),
        isFalse,
      );
    },
  );

  testWidgets('F natural in G major needs an explicit sharp', (tester) async {
    expect(
      KeySignature.gMajor.needsAccidental(
        const Pitch(noteName: NoteName.F, octave: 4),
      ),
      isTrue,
    );
  });

  testWidgets('B flat in F major needs no accidental', (tester) async {
    expect(
      KeySignature.fMajor.needsAccidental(
        const Pitch(
          noteName: NoteName.B,
          accidental: Accidental.flat,
          octave: 3,
        ),
      ),
      isFalse,
    );
  });

  testWidgets('B natural in F major needs an explicit natural', (tester) async {
    expect(
      KeySignature.fMajor.needsAccidental(
        const Pitch(noteName: NoteName.B, octave: 3),
      ),
      isTrue,
    );
  });

  testWidgets('MIDI 70 in B-flat major is spelled B-flat on the middle line', (
    tester,
  ) async {
    final pitch = KeySignature.bFlatMajor.spell(Pitch.fromMidiNumber(70));
    expect(pitch.noteName, NoteName.B);
    expect(pitch.accidental, Accidental.flat);
    expect(
      KeySignature.bFlatMajor.needsAccidental(pitch),
      isFalse,
      reason: 'B-flat is in the key signature',
    );
    expect(
      StaffPosition.forPitch(pitch, ClefType.treble).value,
      4,
      reason: 'B-flat4 sits on the middle line',
    );
  });

  testWidgets('MIDI 70 in D major is spelled A-sharp with an accidental', (
    tester,
  ) async {
    final pitch = KeySignature.dMajor.spell(Pitch.fromMidiNumber(70));
    expect(pitch.noteName, NoteName.A);
    expect(pitch.accidental, Accidental.sharp);
    expect(
      KeySignature.dMajor.needsAccidental(pitch),
      isTrue,
      reason: 'A-sharp is not in the D major key signature',
    );
  });
}