import 'package:flutter/material.dart';

import '../style.dart';

/// Vertical velocity meter: a rounded track whose fill grows from the bottom
/// up. Always vertical, so it reads the same way beside the staff and beside
/// the keyboard.
class VelocityIndicator extends StatelessWidget {
  const VelocityIndicator({super.key, required this.velocity});

  /// MIDI velocity, 0-127.
  final int velocity;

  @override
  Widget build(BuildContext context) {
    final signalLevel = velocity.clamp(0, 127) / 127.0;

    return SizedBox(
      width: AppMeterStyle.thickness,
      height: AppMeterStyle.length + 35,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppMeterStyle.trackColor,
              borderRadius: AppMeterStyle.borderRadius,
              border: Border.all(color: AppMeterStyle.trackBorderColor),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              widthFactor: 1,
              heightFactor: signalLevel,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppMeterStyle.fillGradient,
                  borderRadius: AppMeterStyle.borderRadius,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
