import 'package:flutter/foundation.dart';
import 'package:frontend/src/rust/api/bridge.dart';

class MidiProvider extends ChangeNotifier {
  Bridge? _bridge;
  List<String> _ports = [];
  String? _error;

  bool get hasBridge => _bridge != null;
  List<String> get ports => _ports;
  String? get error => _error;

  Future<void> init() async {
    _bridge = await Bridge.newInstance();
    notifyListeners();
    loadPorts();
  }

  void loadPorts() {
    try {
      _ports = listMidiPorts();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<String> connect(int portIndex) async {
    return await _bridge!.connectMidi(portIndex: portIndex);
  }

  Stream<String> startEventStream() {
    return _bridge!.startMidiEventStream();
  }

  Future<void> disconnect() async {
    await _bridge?.disconnectMidi();
  }
}
