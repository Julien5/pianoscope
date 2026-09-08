import 'package:flutter/material.dart';

class VelocityIndicator extends StatelessWidget {
  final int velocity;

  const VelocityIndicator({super.key, required this.velocity});

  @override
  Widget build(BuildContext context) {
    final safeVelocity = velocity.clamp(0, 127);
    final signalLevel = safeVelocity / 127.0;

    return SizedBox(
      width: 10,
      height: 100,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.grey.shade400),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              widthFactor: 1,
              heightFactor: signalLevel,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.blueGrey, Colors.blueGrey, Colors.blueGrey],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
