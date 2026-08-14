import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/src/rust/api/bridge.dart';
import 'package:provider/provider.dart';
import 'package:frontend/src/providers/input_provider.dart';
import 'midi_signal_screen.dart';

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
      String name;
      if (id.isEmpty) {
        name = await provider.selectMicrophone();
      } else {
        name = await provider.selectMidi(id);
      }
      if (!mounted) return;
      final streams = await provider.startEventStream();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MidiSignalScreen(
            portName: name,
            eventStream: streams.events,
            errorStream: streams.errors,
          ),
        ),
      );
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
      return Scaffold(
        appBar: AppBar(title: const Text('MIDI Devices')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final ports = provider.ports;
    final error = provider.error;

    return Scaffold(
      appBar: AppBar(title: const Text('MIDI Devices')),
      body: _buildBody(ports, error),
    );
  }

  Widget _buildBody(List<MidiPort> ports, String? error) {
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

    return ListView.builder(
      itemCount: ports.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return ListTile(
            title: Text("Microphone"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _connect(""),
          );
        }

        return ListTile(
          title: Text(ports[index - 1].name),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _connect(ports[index - 1].id),
        );
      },
    );
  }
}
