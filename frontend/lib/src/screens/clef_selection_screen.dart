import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../pianoscope.dart';
import '../routes.dart';
import '../style.dart';

class KeyTile extends StatelessWidget {
  final KeySignature current;
  final KeySignature keySignature;
  const KeyTile({super.key, required this.keySignature, required this.current});

  ButtonStyle _getBorderStyle(bool isSelected) {
    return ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      side: isSelected
          ? const BorderSide(color: AppColors.text, width: 2.0) // Selected
          : const BorderSide(color: AppColors.border, width: 1.0), // Unselected
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isSelected = current == keySignature;
    return ElevatedButton(
      style: _getBorderStyle(isSelected),

      onPressed: () {
        InputProvider model = context.read<InputProvider>();
        model.keySignature = keySignature;
        GoRouter.of(context).go(Routes.note);
      },
      child: KeySignatureTile(keySignature: keySignature),
    );
  }
}

class KeyTiles extends StatefulWidget {
  final List<KeySignature> keySignatures;
  const KeyTiles({super.key, required this.keySignatures});

  @override
  State<KeyTiles> createState() => _KeyTilesState();
}

class _KeyTilesState extends State<KeyTiles> {
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
    KeySignature current =
        context.read<InputProvider>().keySignature ?? KeySignature.cMajor;

    List<Widget> children = [];
    for (int k = 0; k < widget.keySignatures.length; k++) {
      KeySignature key = widget.keySignatures[k];
      children.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [KeyTile(keySignature: key, current: current)], //
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 2, // 2 columns (left to right)
      mainAxisSpacing: 1,
      childAspectRatio: 1.7,
      crossAxisSpacing: 1,
      children: children,
    );
  }
}

class ClefSelectionScreen extends StatefulWidget {
  const ClefSelectionScreen({super.key});

  @override
  State<ClefSelectionScreen> createState() => _ClefSelectionScreenState();
}

(List<KeySignature>, List<KeySignature>) keyLists() {
  List<KeySignature> ret1 = [];
  List<KeySignature> ret2 = [];
  for (int accidentals = 1; accidentals <= 7; accidentals++) {
    ret1.add(KeySignature(accidentals: accidentals));
    ret2.add(KeySignature(accidentals: -accidentals));
  }
  return (ret1, ret2);
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
    final (sharps, flats) = keyLists();
    final zeroChild = KeyTiles(keySignatures: [KeySignature(accidentals: 0)]);
    final sharpChild = KeyTiles(keySignatures: sharps);
    final flatChild = KeyTiles(keySignatures: flats);

    return DefaultTabController(
      length: 3, // Number of tabs
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'C Major'),
              Tab(text: 'Sharps'),
              Tab(text: 'Flats'),
            ],
          ),
          Expanded(
            child: TabBarView(children: [zeroChild, sharpChild, flatChild]),
          ),
        ],
      ),
    );
  }
}
