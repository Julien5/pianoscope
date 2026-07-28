import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:frontend/src/rust/api/bridge.dart';
import 'package:frontend/src/rust/api/event.dart';

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

  Future<({Stream<Event> events, Stream<String> errors})> startEventStream() async {
    final sink = RustStreamSink<Event>();
    final errorSink = RustStreamSink<String>();
    await _bridge!.startMidiEventStream(sink: sink, errorSink: errorSink);
    return (events: sink.stream, errors: errorSink.stream);
  }

  Future<void> disconnect() async {
    await _bridge?.disconnectMidi();
  }
}
