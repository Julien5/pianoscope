import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/user_settings_provider.dart';
import '../routes.dart';
import '../rust/api/bridge.dart';
import 'package:provider/provider.dart';
import '../providers/input_provider.dart';
import '../routes/route_observer.dart';
import '../style.dart';
import '../widgets/microphone_warning_dialog.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> with RouteAware {
  Timer? _simulationTimer;

  @override
  void initState() {
    super.initState();
    final provider = context.read<InputProvider>();
    assert(provider.hasBridge);
    if (_isMidiSimulation(simulationSetting())) {
      _simulationTimer = Timer(
        const Duration(seconds: 1),
        autoConnectSimulatioMidi,
      );
    } else if (_isMicrophoneSimulation(simulationSetting())) {
      _simulationTimer = Timer(
        const Duration(seconds: 1),
        autoConnectSimulatioMicrophone,
      );
    }
  }

  bool _isMidiSimulation(String? value) {
    if (value == null) return false;
    return value == 'infinity' || num.tryParse(value) != null;
  }

  bool _isMicrophoneSimulation(String? value) {
    if (value == null) return false;
    return value.contains("wav");
  }

  Future<void> autoConnectSimulatioMidi() async {
    debugPrint("autoConnectSimulatioMidi");
    if (!mounted) return;
    final provider = context.read<InputProvider>();
    provider.loadInputDevices();
    assert(provider.inputDevices.isNotEmpty);
    debugPrint("autoConnectSimulatioMidi _connect");
    for (InputDevice device in provider.inputDevices) {
      if (device is Midi) {
        return _connect(device);
      }
    }
  }

  Future<void> autoConnectSimulatioMicrophone() async {
    if (!mounted) return;
    _connect(Microphone());
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    if (_simulationTimer != null) {
      _simulationTimer?.cancel();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPush() {
    // Route was pushed onto navigator and is now visible.
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        onRefreshClicked(context);
      });
    }
  }

  @override
  void didPopNext() {
    // Returned to this route (another route was popped).
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        onRefreshClicked(context);
      });
    }
  }

  Future<void> _selectDevice(InputDevice device) async {
    if (device is Microphone) {
      final settings = context.read<UserSettingsProvider>();
      if (!settings.hideMicrophoneWarning) {
        final proceed = await showMicrophoneWarningDialog(context, settings);
        if (!mounted || !proceed) return;
      }
    }
    await _connect(device);
  }

  Future<void> _connect(InputDevice inputDevice) async {
    final provider = context.read<InputProvider>();
    try {
      await provider.connect(inputDevice);
      if (!mounted) return;
      GoRouter.of(context).push(Routes.note);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connection failed: $e')));
    }
  }

  void onRefreshClicked(BuildContext context) {
    final provider = context.read<InputProvider>();
    provider.loadInputDevices();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InputProvider>();
    if (!provider.hasBridge) {
      return const Center(child: CircularProgressIndicator());
    }

    final inputDevices = provider.inputDevices;
    final error = provider.error;

    return _buildBody(inputDevices, error);
  }

  Widget _buildBody(List<InputDevice> ports, String? error) {
    if (error != null) {
      return _MessageState(
        icon: Icons.error_outline,
        iconColor: AppColors.error,
        iconBackground: AppColors.errorContainer,
        title: 'Error: $error',
        action: ElevatedButton(
          style: AppTheme.filledButtonStyle,
          onPressed: () => onRefreshClicked(context),
          child: const Text('Retry'),
        ),
      );
    }

    context.watch<UserSettingsProvider>();

    // `Flexible(loose)` + `shrinkWrap` lets the list take only the height it
    // needs, so the refresh button sits directly under the last device, while
    // still scrolling once the devices outgrow the screen. `Expanded` here
    // would stretch the list and strand the button at the bottom.
    final deviceList = ListView.builder(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      itemCount: ports.length,
      itemBuilder: (context, index) {
        return _DeviceCard(
          device: ports[index],
          onTap: () => _selectDevice(ports[index]),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The empty state has nothing to hug, so let it centre in the space
        // above the button instead.
        if (ports.isEmpty)
          Expanded(
            child: _MessageState(
              icon: Icons.usb_off_outlined,
              title: 'No input device found',
            ),
          )
        else
          Flexible(fit: FlexFit.loose, child: deviceList),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Center(
            child: ElevatedButton.icon(
              style: AppTheme.tonalButtonStyle,
              onPressed: () => onRefreshClicked(context),
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Refresh'),
            ),
          ),
        ),
      ],
    );
  }
}

/// One selectable input device, rendered as a card with a tinted icon chip.
class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.onTap});

  final InputDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMicrophone = device is Microphone;

    return Card(
      child: ListTile(
        leading: _IconChip(
          icon: isMicrophone ? Icons.mic_none : Icons.usb,
          color: AppColors.secondary,
          background: isMicrophone
              ? AppColors.primaryContainer
              : AppColors.secondaryContainer,
        ),
        title: Text(device.localizedPortName(context)),
        subtitle: isMicrophone ? null : Text(device.portName()),
        trailing: Icon(
          Icons.chevron_right,
          color: AppColors.textTertiary,
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Rounded, tinted square behind an icon.
class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppHeights.chip,
      height: AppHeights.chip,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.small,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

/// Centred icon + message, used for both the empty and error states.
class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    this.iconColor = AppColors.primary,
    this.iconBackground = AppColors.primaryContainer,
    this.action,
  });

  final IconData icon;
  final String title;
  final Color iconColor;
  final Color iconBackground;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppTextStyles.normal.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
