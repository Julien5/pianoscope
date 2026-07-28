import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/src/providers/midi_provider.dart';
import 'midi_signal_screen.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  @override
  void initState() {
    super.initState();
    final provider = context.read<MidiProvider>();
    if (provider.hasBridge) {
      provider.loadPorts();
    }
  }

  Future<void> _connect(int index) async {
    final provider = context.read<MidiProvider>();
    try {
      final portName = await provider.connect(index);
      if (!mounted) return;
      final stream = provider.startEventStream();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MidiSignalScreen(portName: portName, eventStream: stream),
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

  Widget _buildBody(List<String> ports, String? error) {
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
          title: Text(ports[index]),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _connect(index),
        );
      },
    );
  }
}
