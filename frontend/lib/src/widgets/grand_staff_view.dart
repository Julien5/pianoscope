import 'package:flutter/material.dart';
import '../notation/models/key_signature.dart';
import '../notation/models/note.dart';
import '../notation/grand_staff_painter.dart';

/// Renders a single-measure grand staff (treble above, bass below) from a
/// flat list of notes.
///
/// Notes at MIDI >= [splitPoint] go on the treble staff, notes below on the
/// bass staff; the other staff stays blank. Notes sharing a start beat are
/// painted as a chord, notes at different beats are laid out left to right.
class GrandStaffView extends StatelessWidget {
  final List<Note> notes;
  final KeySignature keySignature;
  final int splitPoint;
  final double staffSpaceSize;
  final double grandStaffGap;
  final double leftMargin;
  final double rightMargin;
  final double topMargin;
  final double leadingSpace;
  final double barlineToClefSpace;
  final double measureSpacing;
  final bool showBrace;
  final bool expandWidth;

  const GrandStaffView({
    super.key,
    this.notes = const [],
    this.keySignature = KeySignature.cMajor,
    this.splitPoint = 60,
    this.staffSpaceSize = 10,
    this.grandStaffGap = 60,
    this.leftMargin = 20,
    this.rightMargin = 20,
    this.topMargin = 30,
    this.leadingSpace = 60,
    this.barlineToClefSpace = 10,
    this.measureSpacing = 40,
    this.showBrace = true,
    this.expandWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final staffHeight = staffSpaceSize * 4;
    final systemHeight = staffHeight + grandStaffGap + staffHeight;
    final height = topMargin + systemHeight + 60 + topMargin;

    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      child: CustomPaint(
        painter: GrandStaffPainter(
          notes: notes,
          keySignature: keySignature,
          splitPoint: splitPoint,
          staffSpaceSize: staffSpaceSize,
          grandStaffGap: grandStaffGap,
          leftMargin: leftMargin,
          rightMargin: rightMargin,
          topMargin: topMargin,
          leadingSpace: leadingSpace,
          barlineToClefSpace: barlineToClefSpace,
          measureSpacing: measureSpacing,
          showBrace: showBrace,
          expandWidth: expandWidth,
        ),
        size: Size.infinite,
      ),
    );
  }
}
