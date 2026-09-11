// lib/src/models/key_signature.dart

import 'pitch.dart';

/// Represents a musical key signature
class KeySignature {
  /// Number of sharps (positive) or flats (negative)
  /// Range: -7 (7 flats) to +7 (7 sharps)
  final int accidentals;

  const KeySignature({required this.accidentals})
    : assert(
        accidentals >= -7 && accidentals <= 7,
        'Accidentals must be between -7 and +7',
      );

  /// Common major key signatures
  // represent with sharps
  static const cMajor = KeySignature(accidentals: 0);
  static const gMajor = KeySignature(accidentals: 1);
  static const dMajor = KeySignature(accidentals: 2);
  static const aMajor = KeySignature(accidentals: 3);
  static const eMajor = KeySignature(accidentals: 4);
  static const bMajor = KeySignature(accidentals: 5);
  static const fSharpMajor = KeySignature(accidentals: 6);
  static const cSharpMajor = KeySignature(accidentals: 7);
  // represent with flats
  static const fMajor = KeySignature(accidentals: -1);
  static const bFlatMajor = KeySignature(accidentals: -2);
  static const eFlatMajor = KeySignature(accidentals: -3);
  static const aFlatMajor = KeySignature(accidentals: -4);
  static const dFlatMajor = KeySignature(accidentals: -5);
  static const gFlatMajor = KeySignature(accidentals: -6);
  static const cFlatMajor = KeySignature(accidentals: -7);

  /// Whether this key uses sharps (true) or flats (false)
  bool get usesSharps => accidentals >= 0;

  /// Return a spelling of the given pitch appropriate for this key signature.
  ///
  /// A MIDI note number is enharmonically ambiguous (e.g. 70 is both A♯ and
  /// B♭). Flat keys spell black keys as flats (B♭ in F major), sharp keys as
  /// sharps (F♯ in G major).
  Pitch spell(Pitch pitch) {
    return Pitch.fromMidiNumber(
      pitch.midiNumber,
      preferredAccidental: usesSharps ? Accidental.sharp : Accidental.flat,
    );
  }

  /// Get the pitch classes that are altered in this key signature
  /// Returns MIDI pitch classes (0-11) that should be sharp/flat
  List<int> getAlteredPitchClasses() {
    if (accidentals == 0) return [];

    // Order of sharps: F C G D A E B
    const sharpOrder = [5, 0, 7, 2, 9, 4, 11];
    // Order of flats: B E A D G C F
    const flatOrder = [11, 4, 9, 2, 7, 0, 5];

    if (accidentals > 0) {
      return sharpOrder.take(accidentals).toList();
    } else {
      return flatOrder.take(-accidentals).toList();
    }
  }

  /// Check if a pitch needs an accidental in this key
  bool needsAccidental(Pitch pitch) {
    // The key signature alters note-name positions (e.g. D major: F# and
    // C#), so compare the natural note name, not the altered pitch class.

    final naturalPitchClass =
        (pitch.midiNumber - pitch.accidental.semitoneOffset) % 12;
    final altered = getAlteredPitchClasses();

    if (altered.contains(naturalPitchClass)) {
      // This pitch is in the key signature
      // Only needs accidental if it differs from key signature
      if (usesSharps) {
        return pitch.accidental != Accidental.sharp;
      } else {
        return pitch.accidental != Accidental.flat;
      }
    } else {
      // This pitch is not in key signature
      // Needs accidental if it's not natural
      return pitch.accidental != Accidental.natural;
    }
  }

  @override
  String toString() => 'KeySignature(accidentals: $accidentals)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeySignature && accidentals == other.accidentals;

  @override
  int get hashCode => Object.hash(accidentals, 0);
}
