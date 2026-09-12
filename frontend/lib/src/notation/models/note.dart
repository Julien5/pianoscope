// lib/src/notation/models/note.dart

import 'package:flutter/material.dart';
import 'pitch.dart';

/// Represents a single musical note
class Note {
  /// The pitch of the note
  final Pitch pitch;

  /// Optional per-note color override (e.g. for ghost/dimmed notes).
  /// When null, the renderer's default color is used.
  final Color? color;

  const Note({required this.pitch, this.color});

  /// Create a copy with modified properties
  Note copyWith({Pitch? pitch, bool? forceShowAccidental, Color? color}) {
    return Note(pitch: pitch ?? this.pitch, color: color ?? this.color);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note && pitch == other.pitch && color == other.color;

  @override
  int get hashCode => Object.hash(pitch, color);

  @override
  String toString() => 'Note($pitch)';
}
