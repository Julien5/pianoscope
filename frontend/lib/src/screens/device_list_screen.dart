import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/user_settings_provider.dart';
import '../routes.dart';
import '../rust/api/bridge.dart';
import 'package:provider/provider.dart';
import '../providers/input_provider.dart';
import '../routes/route_observer.dart';

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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => onRefreshClicked(context),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    context.watch<UserSettingsProvider>();

    final deviceList = ListView.builder(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: ports.length,
      itemBuilder: (context, index) {
        if (ports[index] is Microphone) {
          return Card(
            child: ListTile(
              title: Text(ports[index].localizedPortName(context)),
              trailing: const Icon(Icons.mic),
              onTap: () => _connect(ports[index]),
            ),
          );
        }
        return Card(
          child: ListTile(
            title: Text(ports[index].localizedPortName(context)),
            subtitle: Text(ports[index].portName()),
            trailing: const Icon(Icons.usb),
            onTap: () => _connect(ports[index]),
          ),
        );
      },
    );

    final refreshButton = Align(
      alignment: Alignment.topCenter,
      child: ElevatedButton.icon(
        onPressed: () => onRefreshClicked(context),
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(fit: FlexFit.loose, child: deviceList),
        const SizedBox(height: 10),
        refreshButton,
      ],
    );
  }
}
