// lib/src/notation/rendering/glyph_provider.dart

import 'package:flutter/material.dart';
import '../geometry/box.dart';
import '../geometry/staff_units.dart';
import '../models/pitch.dart';

/// Provides SMuFL-compliant music glyphs from multiple notation fonts.
class GlyphProvider {
  // Clefs
  static const trebleClef = '\uE050';
  static const bassClef = '\uE062';
  static const altoClef = '\uE05C';
  static const tenorClef = '\uE05C';

  // Accidentals
  static const sharp = '\uE262';
  static const flat = '\uE260';
  static const natural = '\uE261';
  static const doubleSharp = '\uE263';
  static const doubleFlat = '\uE264';

  // Rests
  static const wholeRest = '\uE4E3';
  static const halfRest = '\uE4E4';
  static const quarterRest = '\uE4E5';
  static const eighthRest = '\uE4E6';
  static const sixteenthRest = '\uE4E7';
  static const thirtySecondRest = '\uE4E8';
  static const sixtyFourthRest = '\uE4E9';

  // Noteheads
  static const noteheadBlack = '\uE0A4';
  static const noteheadHalf = '\uE0A3';
  static const noteheadWhole = '\uE0A2';

  // Flags
  static const flag8thUp = '\uE240';
  static const flag8thDown = '\uE241';
  static const flag16thUp = '\uE242';
  static const flag16thDown = '\uE243';
  static const flag32ndUp = '\uE244';
  static const flag32ndDown = '\uE245';
  static const flag64thUp = '\uE246';
  static const flag64thDown = '\uE247';

  /// Decide which font to use for a glyph
  static String _fontForGlyph(String codepoint) {
    return "Bravura";
    /*
    // Always use Petaluma for accidentals when mixing
    const petalumaAccidentals = {sharp, flat, natural, doubleSharp, doubleFlat};

    if (petalumaAccidentals.contains(codepoint)) {
      return petaluma;
    }

    // Otherwise, base on the active style
    switch (currentStyle) {
      case NotationStyle.bravura:
        return bravura;
      case NotationStyle.petaluma:
        return petaluma;
    }*/
  }

  /// Get a TextPainter for a music symbol
  static TextPainter getGlyphPainter(String codepoint, StaffUnits size) {
    final font = _fontForGlyph(codepoint);
    return TextPainter(
      text: TextSpan(
        text: codepoint,
        style: TextStyle(
          fontFamily: font,
          fontSize: size.value,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  static StaffUnits getGlyphWidth(String codepoint, StaffUnits size) {
    final ret = getGlyphPainter(codepoint, size);
    return StaffUnits.fromUnits(ret.width);
  }

  static StaffSize getGlyphSize(String codepoint, StaffUnits size) {
    final ret = getGlyphPainter(codepoint, size);
    final w = StaffUnits.fromUnits(ret.width);
    final h = StaffUnits.fromUnits(ret.height);
    return StaffSize(w, h);
  }

  /// Utility getters for accidentals, rests, flags
  static String getAccidentalGlyph(Accidental accidental) {
    switch (accidental) {
      case Accidental.doubleFlat:
        return doubleFlat;
      case Accidental.flat:
        return flat;
      case Accidental.natural:
        return natural;
      case Accidental.sharp:
        return sharp;
      case Accidental.doubleSharp:
        return doubleSharp;
    }
  }

  static StaffUnits glyphHeight(String codepoint, StaffUnits size) {
    return getGlyphSize(codepoint, size).height;
  }
}
