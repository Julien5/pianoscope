import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import '../notation/models/key_signature.dart';
import '../rust/api/bridge.dart';
import '../rust/api/event.dart';
import '../utils.dart';
import 'package:permission_handler/permission_handler.dart';

class InputProvider extends ChangeNotifier {
  Bridge? _bridge;
  List<MidiPort> _ports = [];
  String? _error;
  KeySignature? _keySignature;
  String? _portName;
  ({Stream<MidiEvent> events, Stream<String> errors})? _streams;

  bool get hasBridge => _bridge != null;
  List<MidiPort> get ports => _ports;
  String? get error => _error;
  KeySignature? get keySignature => _keySignature;
  set keySignature(KeySignature value) {
    _keySignature = value;
    notifyListeners();
  }

  String? get portName => _portName;
  Stream<MidiEvent>? get eventStream => _streams?.events;
  Stream<String>? get errorStream => _streams?.errors;

  Future<void> init() async {
    _bridge = await Bridge.newInstance();
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

  Future<void> connectMidi(String id) async {
    debugPrint("selectMidi=$id");
    MidiPort port = _ports.firstWhere((port) => port.id == id);
    await _bridge!.selectMidi(port: port);
    await _startEventStream(formatMidiPortName(port.name));
  }

  Future<void> connectMicrophone() async {
    debugPrint("selectMicrophone");
    if (Platform.isAndroid) {
      var status = await Permission.microphone.request();
      if (!status.isGranted) {
        throw Exception('Microphone permission denied');
      }
    }
    await _bridge!.selectMicrophone();
    await _startEventStream("microphone");
  }

  Future<void> _startEventStream(String portName) async {
    final sink = RustStreamSink<MidiEvent>();
    final errorSink = RustStreamSink<String>();
    await _bridge!.startStream(sink: sink, errorSink: errorSink);
    _portName = portName;
    _streams = (events: sink.stream, errors: errorSink.stream);
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _bridge?.disconnect();
  }
}
