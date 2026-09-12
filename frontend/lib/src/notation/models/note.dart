// lib/src/notation/models/note.dart

import 'package:flutter/material.dart';
import 'pitch.dart';
import 'duration.dart';

/// Represents a single musical note
class Note {
  /// The pitch of the note
  final Pitch pitch;

  /// The duration of the note
  final NoteDuration duration;

  /// Whether to display an accidental for this note
  /// (null means it should be determined by context)
  final bool? forceShowAccidental;

  /// Velocity (loudness) from 0-127 (MIDI convention)
  final int velocity;

  /// Optional per-note color override (e.g. for ghost/dimmed notes).
  /// When null, the renderer's default color is used.
  final Color? color;

  const Note({
    required this.pitch,
    required this.duration,
    this.forceShowAccidental,
    this.velocity = 64,
    this.color,
  }) : assert(velocity >= 0 && velocity <= 127, 'Velocity must be 0-127');

  /// Create a copy with modified properties
  Note copyWith({
    Pitch? pitch,
    NoteDuration? duration,
    bool? forceShowAccidental,
    int? velocity,
    Color? color,
  }) {
    return Note(
      pitch: pitch ?? this.pitch,
      duration: duration ?? this.duration,
      forceShowAccidental: forceShowAccidental ?? this.forceShowAccidental,
      velocity: velocity ?? this.velocity,
      color: color ?? this.color,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note &&
          pitch == other.pitch &&
          duration == other.duration &&
          forceShowAccidental == other.forceShowAccidental &&
          velocity == other.velocity &&
          color == other.color;

  @override
  int get hashCode =>
      Object.hash(pitch, duration, forceShowAccidental, velocity, color);

  @override
  String toString() => 'Note($pitch, ${duration.type.name})';
}
