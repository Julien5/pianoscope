import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../pianoscope.dart';
import '../providers/user_settings_provider.dart';
import '../style.dart';

class KeyTile extends StatelessWidget {
  final KeySignature current;
  final KeySignature keySignature;
  const KeyTile({super.key, required this.keySignature, required this.current});

  ButtonStyle _getBorderStyle(bool isSelected) {
    return isSelected
        ? AppTheme.selectedButtonStyle
        : AppTheme.tonalButtonStyle;
  }

  void setKeySignature(
    UserSettingsProvider userSettings,
    KeySignature keySignature,
  ) async {
    await userSettings.setKeySignature(keySignature);
  }

  @override
  Widget build(BuildContext context) {
    bool isSelected = current == keySignature;
    return ElevatedButton(
      style: _getBorderStyle(isSelected),

      onPressed: () {
        final userSettings = context.read<UserSettingsProvider>();
        setKeySignature(userSettings, keySignature);
        GoRouter.of(context).pop();
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
    KeySignature current = context.read<UserSettingsProvider>().keySignature;

    List<Widget> children = [];
    for (int k = 0; k < widget.keySignatures.length; k++) {
      KeySignature key = widget.keySignatures[k];
      children.add(KeyTile(keySignature: key, current: current));
    }
    return Padding(
      padding: EdgeInsetsGeometry.all(AppClefStyle.gridSpacing),
      child: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;
          if (isLandscape) {
            return GridView.count(
              crossAxisCount: AppClefStyle.landscapeColumns,
              mainAxisSpacing: AppClefStyle.gridSpacing,
              childAspectRatio: AppClefStyle.childAspectRatio,
              crossAxisSpacing: AppClefStyle.gridSpacing,
              children: children,
            );
          }
          return GridView.count(
            mainAxisSpacing: AppClefStyle.gridSpacing,
            crossAxisSpacing: AppClefStyle.gridSpacing,
            crossAxisCount: AppClefStyle.portraitColumns,
            childAspectRatio: AppClefStyle.childAspectRatio,
            children: children,
          );
        },
      ),
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

class _ClefSelectionScreenState extends State<ClefSelectionScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    KeySignature current = context.read<UserSettingsProvider>().keySignature;

    if (current.accidentals > 0) _selectedIndex = 1;
    if (current.accidentals < 0) _selectedIndex = 2;

    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _selectedIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (sharps, flats) = keyLists();
    final zeroChild = KeyTiles(keySignatures: [KeySignature(accidentals: 0)]);
    final sharpChild = KeyTiles(keySignatures: sharps);
    final flatChild = KeyTiles(keySignatures: flats);
    final pages = [zeroChild, sharpChild, flatChild];
    final l10n = AppLocalizations.of(context)!;

    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;
        if (!isLandscape) {
          return Column(
            children: [
              ColoredBox(
                color: AppColors.primaryContainer,
                child: TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: l10n.cMajor),
                    Tab(text: l10n.sharps),
                    Tab(text: l10n.flats),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: TabBarView(controller: _tabController, children: pages),
              ),
            ],
          );
        }

        // Landscape: vertical tabs on the left (rotated TabBar)
        return Row(
          children: [
            ColoredBox(
              color: AppColors.primaryContainer,
              child: Container(
                width: AppClefStyle.tabRailWidth,
                alignment: Alignment.bottomRight,
                child: RotatedBox(
                  quarterTurns: -1,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.center,
                    tabs: [
                      Tab(text: l10n.cMajor),
                      Tab(text: l10n.sharps),
                      Tab(text: l10n.flats),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(controller: _tabController, children: pages),
            ),
          ],
        );
      },
    );
  }
}
