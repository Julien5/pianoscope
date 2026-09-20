import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import '../notation/models/key_signature.dart';
import '../rust/api/bridge.dart';
import '../rust/api/event.dart';
import '../utils.dart';
import 'package:permission_handler/permission_handler.dart';

typedef EventObserver = Function(MidiEvent);
typedef ErrorObserver = Function(String);

class StreamSink {
  final eventsSink = RustStreamSink<MidiEvent>();
  final errorsSink = RustStreamSink<String>();

  final List<EventObserver> eventObservers = [];
  final List<ErrorObserver> errorObservers = [];

  StreamSubscription<MidiEvent>? _eventSub;
  StreamSubscription<String>? _errorSub;

  void start() {
    _eventSub ??= eventsSink.stream.listen((event) {
      for (final observer in eventObservers) {
        observer(event);
      }
    });

    _errorSub ??= errorsSink.stream.listen((error) {
      for (final observer in errorObservers) {
        observer(error);
      }
    });
  }
}

sealed class InputDevice {
  static InputDevice fromId(String id) {
    if (id.isEmpty) {
      return Microphone();
    } else {
      return Midi(id);
    }
  }
}

class Microphone extends InputDevice {}

class Midi extends InputDevice {
  final String portName;
  Midi(this.portName);
}

class InputProvider extends ChangeNotifier {
  Bridge? _bridge;
  List<MidiPort> _ports = [];
  String? _error;
  KeySignature? _keySignature;
  InputDevice? _inputDevice;
  StreamSink? _streamSink;

  bool get hasBridge => _bridge != null;
  List<MidiPort> get ports => _ports;
  String? get error => _error;
  KeySignature? get keySignature => _keySignature;
  set keySignature(KeySignature value) {
    _keySignature = value;
    notifyListeners();
  }

  String? portName() {
    if (_inputDevice == null) {
      return null;
    }
    switch (_inputDevice!) {
      case Microphone():
        return "Microphone";
      case Midi(portName: final name):
        return name;
    }
  }

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

  Future<void> connect(InputDevice device) async {
    if (_inputDevice != null) {
      await disconnect();
    }
    debugPrint("connect: $device");
    assert(_inputDevice == null);
    _inputDevice = device;
    switch (_inputDevice!) {
      case Microphone():
        await _connectMicrophone();
      case Midi(portName: final name):
        await _connectMidi(name);
    }
    assert(_streamSink != null);
  }

  Future<void> _connectMidi(String portName) async {
    debugPrint("selectMidi=$portName");
    MidiPort port = _ports.firstWhere((port) => port.id == portName);
    await _bridge!.selectMidi(port: port);
    await _startEventStream(formatMidiPortName(port.name));
  }

  Future<void> _connectMicrophone() async {
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
    _streamSink = StreamSink();
    await _bridge!.startStream(
      sink: _streamSink!.eventsSink,
      errorSink: _streamSink!.errorsSink,
    );
    _streamSink!.start();
    notifyListeners();
  }

  void attachObservers(
    EventObserver eventObserver,
    ErrorObserver errorObserver,
  ) {
    _streamSink!.eventObservers.add(eventObserver);
    _streamSink!.errorObservers.add(errorObserver);
  }

  void clearObservers() {
    _streamSink!.eventObservers.clear();
    _streamSink!.errorObservers.clear();
  }

  Future<void> disconnect() async {
    _streamSink = null;
    _inputDevice = null;
    await _bridge?.disconnect();
  }
}
