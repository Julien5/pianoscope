import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../pianoscope.dart';

class KeyTile extends StatelessWidget {
  final KeySignature current;
  final KeySignature keySignature;
  const KeyTile({
    super.key,
    required this.keySignature,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    BorderSide side = BorderSide(color: Colors.grey, width: 2);
    if (current==keySignature) {
      side = BorderSide(color: Colors.black, width: 3);
    }
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        side: side,
      ),

      onPressed: () {
        InputProvider model = context.read<InputProvider>();
        model.keySignature = keySignature;
        Navigator.pop(context);
      },
      child: KeySignatureTile(keySignature: keySignature),
    );
  }
}

class ClefSelectionScreen extends StatefulWidget {
  const ClefSelectionScreen({super.key});

  @override
  State<ClefSelectionScreen> createState() => _ClefSelectionScreenState();
}

class _ClefSelectionScreenState extends State<ClefSelectionScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    KeySignature current=context.read<InputProvider>().keySignature ?? KeySignature.cMajor;

    return Scaffold(
      appBar: AppBar(title: Text("Select Clef")),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  KeyTile(keySignature: KeySignature.cMajor, current: current),
                ],
              ),
              SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  KeyTile(keySignature: KeySignature.gMajor, current: current),
                  KeyTile(keySignature: KeySignature.fMajor, current: current),
                ],
              ),

              SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  KeyTile(keySignature: KeySignature.dMajor, current: current),
                  KeyTile(
                    keySignature: KeySignature.bFlatMajor,
                    current: current,
                  ),
                ],
              ),

              SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  KeyTile(keySignature: KeySignature.aMajor, current: current),
                  KeyTile(
                    keySignature: KeySignature.eFlatMajor,
                    current: current,
                  ),
                ],
              ),

              SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  KeyTile(keySignature: KeySignature.eMajor, current: current),
                  KeyTile(
                    keySignature: KeySignature.aFlatMajor,
                    current: current,
                  ),
                ],
              ),

              SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  KeyTile(keySignature: KeySignature.bMajor, current: current),
                  KeyTile(
                    keySignature: KeySignature.dFlatMajor,
                    current: current,
                  ),
                ],
              ),

              SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  KeyTile(keySignature: KeySignature.fSharpMajor, current: current),
                  KeyTile(
                    keySignature: KeySignature.gFlatMajor,
                    current: current,
                  ),
                ],
              ),

              SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  KeyTile(keySignature: KeySignature.cSharpMajor, current: current),
                  KeyTile(
                    keySignature: KeySignature.cFlatMajor,
                    current: current
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
