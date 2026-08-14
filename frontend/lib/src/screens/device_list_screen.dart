import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/src/rust/api/bridge.dart';
import 'package:provider/provider.dart';
import 'package:frontend/src/providers/midi_provider.dart';
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
    final provider = context.read<MidiProvider>();
    if (provider.hasBridge) {
      provider.loadPorts();
    }
    _simulationTimer = Timer(const Duration(seconds: 1), _maybeAutoConnect);
  }

  bool _isSimulation(String? value) {
    if (value == null) return false;
    return value == 'infinity' || num.tryParse(value) != null;
  }

  Future<void> _maybeAutoConnect() async {
    if (!mounted) return;
    final provider = context.read<MidiProvider>();
    if (!_isSimulation(simulationSetting())) return;
    if (provider.ports.isEmpty) {
      provider.loadPorts();
    }
    if (provider.ports.isEmpty) {
      provider.addListener(_retryAutoConnect);
    } else {
      _connect(0);
    }
  }

  void _retryAutoConnect() {
    final provider = context.read<MidiProvider>();
    if (provider.ports.isNotEmpty) {
      provider.removeListener(_retryAutoConnect);
      if (mounted) _connect(0);
    }
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    final provider = context.read<MidiProvider>();
    provider.removeListener(_retryAutoConnect);
    super.dispose();
  }

  Future<void> _connect(int index) async {
    final provider = context.read<MidiProvider>();
    try {
      final port = await provider.connect(index);
      if (!mounted) return;
      final streams = await provider.startEventStream();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MidiSignalScreen(
            portName: port.name,
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
    final provider = context.watch<MidiProvider>();

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
              onPressed: () => context.read<MidiProvider>().loadPorts(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (ports.isEmpty) {
      return const Center(child: Text('No MIDI devices found'));
    }

    return ListView.builder(
      itemCount: ports.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(ports[index].name),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _connect(index),
        );
      },
    );
  }
}
