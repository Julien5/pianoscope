import 'dart:io';

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Cleans up raw OS MIDI port names into user-friendly display labels.
String formatMidiPortNameDefault(String rawName) {
  debugPrint("rawName: $rawName");
  if (rawName.trim().isEmpty) return 'Unknown MIDI Device';

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
    RegExp(r'\[.*?\]'), // Anything inside square brackets
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
  if (rawName.trim().isEmpty) return 'Unknown MIDI Device';

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
  cleaned = cleaned
      .replaceAll(RegExp(r'\bMIDI\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bPort[-_]?\d*\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // If cleaning reduced it to empty (e.g., "Midi Through:Midi Through Port-0"), restore client
  if (cleaned.isEmpty && rawName.contains(':')) {
    cleaned = rawName.split(':')[0].trim();
  }

  return cleaned;
}

/// Cleans raw Android/AMidi device and port strings into clean labels.
String formatMidiPortNameAndroid(String rawName) {
  if (rawName.trim().isEmpty) return 'Unknown MIDI Device';

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

  // 3. Strip Android system wrappers (e.g., "UsbMidiDevice [...]", "Bluetooth MIDI Device")
  cleaned = cleaned
      .replaceAll(
        RegExp(r'^UsbMidiDevice\s*(\[.*\])?', caseSensitive: false),
        '',
      )
      .replaceAll(
        RegExp(r'^Bluetooth\s*MIDI\s*Device\s*[-–]?\s*', caseSensitive: false),
        '',
      )
      .replaceAll(
        RegExp(r'\[.*?\]'),
        '',
      ); // Strip leftover bracketed metadata like [id=3]

  // 4. Clean generic system fallbacks
  if (RegExp(
    r'^Android\s*USB\s*Peripheral$',
    caseSensitive: false,
  ).hasMatch(cleaned.trim())) {
    return 'USB MIDI Device';
  }

  // 5. Remove redundant Android terms ("MIDI", "Port 0", "input 1", etc.)
  cleaned = cleaned
      .replaceAll(RegExp(r'\bMIDI\b', caseSensitive: false), '')
      .replaceAll(
        RegExp(r'\b(Port|Input|Output|Device)[-_]?\d*\b', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return cleaned.isEmpty ? 'USB MIDI Device' : cleaned;
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

String localizeNote(String note, AppLocalizations localizations) {
  Map<String, String> locales = {};
  locales["C"] = localizations.noteC;
  locales["D"] = localizations.noteD;
  locales["E"] = localizations.noteE;
  locales["F"] = localizations.noteF;
  locales["G"] = localizations.noteG;
  locales["A"] = localizations.noteA;
  locales["B"] = localizations.noteB;
  String naturalName = note;
  for (String n in ["C", "D", "E", "F", "G", "A", "B"]) {
    if (note.toUpperCase().contains(n)) {
      naturalName = locales[n]!;
    }
  }
  String ret = naturalName;
  if (note.toUpperCase().contains("#")) {
    ret = localizations.sharp(naturalName);
  }
  return ret;
}
