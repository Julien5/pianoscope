import 'package:flutter/material.dart';

import '../../pianoscope.dart';

Note makeNote(NoteName name, Accidental accidental) {
  return Note(
    pitch: Pitch(noteName: name, accidental: accidental, octave: 4),
  );
}

/// For each black note, which white note it sits immediately after.
/// E.g. C# sits after C (index 0), F# sits after F (index 3).
/// E and B have no following black key, so they're absent from this map.
int _whiteIndexBeforeBlackNote(Note note) {
  assert(note.pitch.accidental == Accidental.sharp);
  if (note.pitch.noteName == NoteName.C) {
    return 0;
  }
  if (note.pitch.noteName == NoteName.D) {
    return 1;
  }
  if (note.pitch.noteName == NoteName.F) {
    return 3;
  }
  if (note.pitch.noteName == NoteName.G) {
    return 4;
  }
  if (note.pitch.noteName == NoteName.A) {
    return 5;
  }
  return 0;
}

List<Note> blackNotes() {
  return [
    makeNote(NoteName.C, Accidental.sharp),
    makeNote(NoteName.D, Accidental.sharp),
    makeNote(NoteName.F, Accidental.sharp),
    makeNote(NoteName.G, Accidental.sharp),
    makeNote(NoteName.A, Accidental.sharp),
  ];
}

List<Note> whiteNotes() {
  return [
    makeNote(NoteName.C, Accidental.natural),
    makeNote(NoteName.D, Accidental.natural),
    makeNote(NoteName.E, Accidental.natural),
    makeNote(NoteName.F, Accidental.natural),
    makeNote(NoteName.G, Accidental.natural),
    makeNote(NoteName.A, Accidental.natural),
    makeNote(NoteName.B, Accidental.natural),
  ];
}

int index(NoteName name) {
  final table = {
    NoteName.C: 0,
    NoteName.D: 1,
    NoteName.E: 2,
    NoteName.F: 3,
    NoteName.G: 4,
    NoteName.A: 5,
    NoteName.B: 6,
  };
  return table[name]!;
}

bool _isBlack(Note note) => note.pitch.accidental.semitoneOffset != 0;

/// A one-octave (C to B) piano keyboard display widget.
///
/// Purely a read-only display: pass the currently-pressed notes in
/// [pressedNotes] and each corresponding key is marked with a small dot.
/// There is no tap handling.
///
/// The widget computes an intrinsic size from [whiteWidth], [whiteHeight]
/// and [whiteSpace] (7 * whiteWidth + 6 * whiteSpace wide, whiteHeight
/// tall). If the parent constrains it to less than that intrinsic size,
/// the whole keyboard scales down uniformly so all 7 white keys stay
/// visible. It never scales up past its natural size.
class KeyboardWidget extends StatelessWidget {
  const KeyboardWidget({
    super.key,
    required this.pressedNotes,
    this.whiteWidth = 55.0,
    this.whiteHeight = 200.0,
    this.blackWidthRatio = 0.6,
    this.blackHeightRatio = 0.65,
    this.whiteSpace = 2.0,
    this.pressedDotOffset = 20.0,
    this.pressedDotRadius = 3.0,
    this.pressedDotColor = const Color(0xFFF0C419),
  });

  /// Notes currently held down. Order and duplicates don't matter.
  final Set<Note> pressedNotes;

  /// Width of a single white key, in logical pixels, at natural (1:1) scale.
  final double whiteWidth;

  /// Height of a white key, in logical pixels, at natural (1:1) scale.
  final double whiteHeight;

  /// Black key width as a fraction of [whiteWidth].
  final double blackWidthRatio;

  /// Black key height as a fraction of [whiteHeight].
  final double blackHeightRatio;

  /// Horizontal gap between adjacent white keys, in logical pixels.
  final double whiteSpace;

  /// Distance from the bottom of a key to the center of its pressed dot.
  final double pressedDotOffset;

  /// Radius of the pressed-note dot.
  final double pressedDotRadius;

  /// Color of the pressed-note dot.
  final Color pressedDotColor;

  double get _intrinsicWidth => 7 * whiteWidth + 6 * whiteSpace;
  double get _intrinsicHeight => whiteHeight;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      // scaleDown = same as contain, but never scales above 1.0 — the
      // keyboard shrinks to fit a smaller parent but never grows past
      // its natural size.
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: _intrinsicWidth,
        height: _intrinsicHeight,
        child: CustomPaint(
          size: Size(_intrinsicWidth, _intrinsicHeight),
          painter: _KeyboardPainter(
            pressedNotes: pressedNotes,
            whiteWidth: whiteWidth,
            whiteHeight: whiteHeight,
            blackWidthRatio: blackWidthRatio,
            blackHeightRatio: blackHeightRatio,
            whiteSpace: whiteSpace,
            pressedDotOffset: pressedDotOffset,
            pressedDotRadius: pressedDotRadius,
            pressedDotColor: pressedDotColor,
          ),
        ),
      ),
    );
  }
}

class _KeyboardPainter extends CustomPainter {
  _KeyboardPainter({
    required this.pressedNotes,
    required this.whiteWidth,
    required this.whiteHeight,
    required this.blackWidthRatio,
    required this.blackHeightRatio,
    required this.whiteSpace,
    required this.pressedDotOffset,
    required this.pressedDotRadius,
    required this.pressedDotColor,
  });

  final Set<Note> pressedNotes;
  final double whiteWidth;
  final double whiteHeight;
  final double blackWidthRatio;
  final double blackHeightRatio;
  final double whiteSpace;
  final double pressedDotOffset;
  final double pressedDotRadius;
  final Color pressedDotColor;

  double get _blackWidth => whiteWidth * blackWidthRatio;
  double get _blackHeight => whiteHeight * blackHeightRatio;
  double get _whiteStride => whiteWidth + whiteSpace;

  /// Left edge x of the white key at [index] (0 = C ... 6 = B).
  double _whiteKeyLeft(int index) => index * _whiteStride;

  /// Center x of the seam between white key [index] and the next one.
  double _seamCenter(int index) =>
      _whiteKeyLeft(index) + whiteWidth + whiteSpace / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final whiteFill = Paint()..color = Colors.white;
    final whiteStroke = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final blackFill = Paint()..color = Colors.black;
    final dotPaint = Paint()..color = pressedDotColor;

    // White keys.
    for (var i = 0; i < whiteNotes().length; i++) {
      final rect = Rect.fromLTWH(_whiteKeyLeft(i), 0, whiteWidth, whiteHeight);
      canvas.drawRect(rect, whiteFill);
      canvas.drawRect(rect, whiteStroke);
    }

    // Black keys, drawn on top of the white keys' upper portion.
    for (final entry in blackNotes()) {
      final centerX = _seamCenter(index(entry.pitch.noteName));
      final rect = Rect.fromLTWH(
        centerX - _blackWidth / 2,
        0,
        _blackWidth,
        _blackHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        blackFill,
      );
    }

    // Pressed-note dots, one per pressed note that's actually in this
    // octave's key set.
    for (final note in pressedNotes) {
      final double centerX;
      final double keyBottom;
      if (_isBlack(note)) {
        centerX = _seamCenter(_whiteIndexBeforeBlackNote(note));
        keyBottom = _blackHeight;
      } else {
        final whiteIndex = whiteNotes().indexOf(note);
        if (whiteIndex == -1) continue;
        centerX = _whiteKeyLeft(whiteIndex) + whiteWidth / 2;
        keyBottom = whiteHeight;
      }
      canvas.drawCircle(
        Offset(centerX, keyBottom - pressedDotOffset),
        pressedDotRadius,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _KeyboardPainter oldDelegate) {
    return pressedNotes != oldDelegate.pressedNotes ||
        whiteWidth != oldDelegate.whiteWidth ||
        whiteHeight != oldDelegate.whiteHeight ||
        blackWidthRatio != oldDelegate.blackWidthRatio ||
        blackHeightRatio != oldDelegate.blackHeightRatio ||
        whiteSpace != oldDelegate.whiteSpace ||
        pressedDotOffset != oldDelegate.pressedDotOffset ||
        pressedDotRadius != oldDelegate.pressedDotRadius ||
        pressedDotColor != oldDelegate.pressedDotColor;
  }
}
