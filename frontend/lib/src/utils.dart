import 'dart:io';

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../pianoscope.dart';

/// Shown when the raw name carries nothing usable.
const String _unknownDevice = 'Unknown MIDI Device';

/// Shown when Android reports only a generic peripheral.
const String _androidGenericDevice = 'USB MIDI Device';

/// Interface nouns that stop being informative once the device is identified:
/// ALSA reports "Port", Android also reports "Device", "Input" and "Output".
final RegExp _alsaInterfaceTerm = RegExp(
  r'\bPort[-_]?\d*\b',
  caseSensitive: false,
);

final RegExp _androidInterfaceTerm = RegExp(
  r'\b(Port|Input|Output|Device)[-_]?\d*\b',
  caseSensitive: false,
);

/// Bracketed metadata, e.g. "[id=3]" or "[0-1]".
final RegExp _bracketed = RegExp(r'\[.*?\]');

/// Drops the OS words that carry no information once the device is identified
/// ("MIDI", "Port-0", "Device"), then tidies the spacing left behind. Shared by
/// [formatMidiPortNameAlsa] and [formatMidiPortNameAndroid], which differ only
/// in which interface nouns they report.
String _stripInterfaceTerms(String input, RegExp interfaceTerm) {
  return input
      .replaceAll(RegExp(r'\bMIDI\b', caseSensitive: false), 'MIDI')
      .replaceAll(interfaceTerm, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Cleans up raw OS MIDI port names into user-friendly display labels.
String formatMidiPortNameDefault(String rawName) {
  debugPrint("rawName: $rawName");
  if (rawName.trim().isEmpty) return _unknownDevice;

  String cleaned = rawName;

  // 1. Remove common OS/Driver clutter and redundant prefixes/suffixes
  final clutterPatterns = [
    RegExp(r'\b(IN|OUT)\b', caseSensitive: false), // Standalone IN/OUT
    RegExp(
      r'\bMIDI\s*(Port|Interface|Device)?\b',
      caseSensitive: false,
    ), // Redundant 'MIDI' terms
    RegExp(r'\bUSB\s*MIDI\b', caseSensitive: false), // 'USB MIDI'
    RegExp(r'\(?\bCoreMIDI\b\)?', caseSensitive: false), // macOS CoreMIDI tags
    _bracketed, // Anything inside square brackets
  ];

  for (final pattern in clutterPatterns) {
    cleaned = cleaned.replaceAll(pattern, '');
  }

  // 2. Strip hardware interface/index patterns (e.g., "1:", "Port 1", "0", "hw:0,0")
  cleaned = cleaned.replaceAll(
    RegExp(r'\b(hw|port|bus|dev)\s*:?\s*\d+([,-]\d+)?\b', caseSensitive: false),
    '',
  );
  cleaned = cleaned.replaceAll(
    RegExp(r'^\d+\s*:\s*'),
    '',
  ); // Leading "1: " style prefixes

  // 3. Normalize punctuation and separators
  cleaned = cleaned
      .replaceAll(RegExp(r'[-_]{2,}'), ' ') // Multiple dashes/underscores
      .replaceAll(RegExp(r'[():,]'), ' ') // Stripped parens/colons
      .replaceAll(RegExp(r'\s+'), ' ') // Collapsed spaces
      .trim();

  if (cleaned.isEmpty) return 'Generic MIDI Device';

  // 4. Standardize Title Case (preserving known acronyms like USB, DIN)
  return _toTitleCase(cleaned);
}

String _toTitleCase(String input) {
  final acronyms = {'usb', 'din', 'ble', 'rtp', 'asio'};

  return input
      .split(' ')
      .map((word) {
        if (word.isEmpty) return '';
        final lower = word.toLowerCase();
        if (acronyms.contains(lower)) {
          return lower.toUpperCase();
        }
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');
}

/// Cleans ALSA/OS MIDI port names into concise, readable device labels.
String formatMidiPortNameAlsa(String rawName) {
  if (rawName.trim().isEmpty) return _unknownDevice;

  String cleaned = rawName;

  // 1. Remove trailing ALSA IDs (e.g., " 14:0", " 24:1")
  cleaned = cleaned.replaceAll(RegExp(r'\s+\d+:\d+$'), '');

  // 2. Handle ALSA `<Client>:<Port>` duplicate prefix pattern (e.g. "Minilab3:Minilab3 MIDI")
  if (cleaned.contains(':')) {
    final parts = cleaned.split(':');
    final client = parts[0].trim();
    final port = parts.sublist(1).join(':').trim();

    // If port repeats the client name at the start, strip the duplicate
    if (port.toLowerCase().startsWith(client.toLowerCase())) {
      final remainder = port.substring(client.length).trim();
      cleaned = remainder.isEmpty ? client : '$client $remainder';
    } else {
      // If client and port are completely different, join cleanly
      cleaned = '$client $port';
    }
  }

  // 3. Remove redundant words ("MIDI", "Port-0", "Port", etc.)
  cleaned = _stripInterfaceTerms(cleaned, _alsaInterfaceTerm);

  // If cleaning reduced it to empty (e.g., "Midi Through:Midi Through Port-0"), restore client
  if (cleaned.isEmpty && rawName.contains(':')) {
    cleaned = rawName.split(':')[0].trim();
  }

  return cleaned;
}

/// Cleans raw Android/AMidi device and port strings into clean labels.
String formatMidiPortNameAndroid(String rawName) {
  if (rawName.trim().isEmpty) return _unknownDevice;

  String cleaned = rawName;

  // 1. Handle Java/Android toString() objects like "MidiDeviceInfo[...name=Minilab3...]"
  final nameAttrMatch = RegExp(
    r'name=([^,\s\]]+)',
    caseSensitive: false,
  ).firstMatch(cleaned);
  if (nameAttrMatch != null && nameAttrMatch.group(1) != null) {
    cleaned = nameAttrMatch.group(1)!;
  }

  // 2. Handle key-value property patterns like "product=Minilab3" or "manufacturer=Arturia"
  if (cleaned.contains('product=')) {
    final productMatch = RegExp(r'product=([^,\]]+)').firstMatch(cleaned);
    if (productMatch != null) {
      cleaned = productMatch.group(1)!;
    }
  }

  // 3. Strip Android system wrappers (e.g., "UsbMidiDevice [...]",
  //    "Bluetooth MIDI Device") and any leftover bracketed metadata like [id=3]
  cleaned = cleaned
      .replaceAll(
        RegExp(r'^UsbMidiDevice\s*(\[.*\])?', caseSensitive: false),
        '',
      )
      .replaceAll(
        RegExp(r'^Bluetooth\s*MIDI\s*Device\s*[-–]?\s*', caseSensitive: false),
        '',
      )
      .replaceAll(_bracketed, '');

  // 4. Clean generic system fallbacks
  if (RegExp(
    r'^Android\s*USB\s*Peripheral$',
    caseSensitive: false,
  ).hasMatch(cleaned.trim())) {
    return _androidGenericDevice;
  }

  // 5. Remove redundant Android terms ("MIDI", "Port 0", "input 1", etc.)
  cleaned = _stripInterfaceTerms(cleaned, _androidInterfaceTerm);

  return cleaned.isEmpty ? _androidGenericDevice : cleaned;
}

String formatMidiPortName(String rawName) {
  String ret = rawName;
  if (Platform.isLinux) {
    ret = formatMidiPortNameAlsa(rawName);
  } else if (Platform.isAndroid) {
    ret = formatMidiPortNameAndroid(rawName);
  }
  debugPrint("$rawName => $ret");
  return ret;
}

String localizeNote(Note note, AppLocalizations localizations) {
  Map<NoteName, String> locales = {};
  locales[NoteName.C] = localizations.noteC;
  locales[NoteName.D] = localizations.noteD;
  locales[NoteName.E] = localizations.noteE;
  locales[NoteName.F] = localizations.noteF;
  locales[NoteName.G] = localizations.noteG;
  locales[NoteName.A] = localizations.noteA;
  locales[NoteName.B] = localizations.noteB;
  String naturalName = locales[note.pitch.noteName]!;
  if (note.pitch.accidental == Accidental.sharp) {
    return localizations.sharp(naturalName);
  }
  if (note.pitch.accidental == Accidental.flat) {
    return localizations.flat(naturalName);
  }
  return naturalName;
}
