import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../routes.dart';
import '../rust/api/bridge.dart';
import 'package:provider/provider.dart';
import '../providers/input_provider.dart';
import '../style.dart';
import '../utils.dart';

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
    if (!mounted) return;
    final provider = context.read<InputProvider>();
    provider.loadPorts();
    assert(provider.ports.isNotEmpty);
    _connect(provider.ports[0].id);
  }

  Future<void> autoConnectSimulatioMicrophone() async {
    if (!mounted) return;
    _connect("");
  }

  @override
  void dispose() {
    if (_simulationTimer != null) {
      _simulationTimer?.cancel();
    }
    super.dispose();
  }

  Future<void> _connect(String id) async {
    final provider = context.read<InputProvider>();
    try {
      if (id.isEmpty) {
        await provider.connectMicrophone();
      } else {
        await provider.connectMidi(id);
      }
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

    final ports = provider.ports;
    final error = provider.error;

    return _buildBody(ports, error);
  }

  Widget _buildBody(List<MidiPort> ports, String? error) {
    // localeProvider.locale
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<InputProvider>().loadPorts(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final microphoneButton = Card(
      child: ListTile(
        title: const Text('Microphone'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _connect(''),
      ),
    );

    final headerAndList = <Widget>[];
    if (ports.isNotEmpty) {
      headerAndList.add(
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 0, 8),
                    child: Text('MIDI ports', style: AppTextStyles.header),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: ports.length,
                    itemBuilder: (context, index) {
                      return Card(
                        child: ListTile(
                          title: Text(formatMidiPortName(ports[index].name)),
                          subtitle: Text(ports[index].name),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _connect(ports[index].id),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        microphoneButton,
        ...headerAndList,
        const SizedBox(height: 20),
      ],
    );
  }
}
