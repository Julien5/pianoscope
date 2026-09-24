import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/locale_provider.dart';
import '../routes.dart';
import '../rust/api/bridge.dart';
import 'package:provider/provider.dart';
import '../providers/input_provider.dart';
import '../style.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
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
    if (_simulationTimer != null) {
      _simulationTimer?.cancel();
    }
    super.dispose();
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
              onPressed: () => context.read<InputProvider>().loadInputDevices(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    context.watch<LocaleProvider>();

    final child = Expanded(
      child: ListView.builder(
        itemCount: ports.length,
        itemBuilder: (context, index) {
          return Card(
            child: ListTile(
              title: Text(ports[index].localizedPortName(context)),
              subtitle: Text(ports[index].portName()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _connect(ports[index]),
            ),
          );
        },
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [child],
    );
  }
}
