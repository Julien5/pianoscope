import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import '../notation/models/key_signature.dart';
import '../rust/api/bridge.dart';
import '../rust/api/event.dart';
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

  Future<void> stop() async {
    debugPrint("stop start");
    await _eventSub?.cancel();
    await _errorSub?.cancel();
    _eventSub = null;
    _errorSub = null;
    debugPrint("stop end");
  }
}

sealed class InputDevice {
  String portName();
}

class Microphone extends InputDevice {
  @override
  String portName() => 'Microphone';
}

class Midi extends InputDevice {
  final MidiPort port;
  Midi(this.port);
  @override
  String portName() => port.name;
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
    debugPrint("connect: $device");
    if (_streamSink != null) {
      assert(_inputDevice != null);
      await _disconnectInputDevice();
    }
    _inputDevice = device;
    switch (_inputDevice!) {
      case Microphone():
        await _connectMicrophone(_inputDevice as Microphone);
      case Midi(port: final port):
        await _connectMidi(Midi(port));
    }
    assert(_streamSink != null);
  }

  bool connected() {
    return _streamSink != null;
  }

  InputDevice? currentDevice() {
    return _inputDevice;
  }

  Future<void> _connectMidi(Midi port) async {
    debugPrint("selectMidi=${port.portName()}");

    await _bridge!.selectMidi(port: port.port);
    await _startEventStream();
  }

  Future<void> _connectMicrophone(Microphone mic) async {
    debugPrint("selectMicrophone");
    if (Platform.isAndroid) {
      var status = await Permission.microphone.request();
      if (!status.isGranted) {
        throw Exception('Microphone permission denied');
      }
    }
    await _bridge!.selectMicrophone();
    await _startEventStream();
  }

  Future<void> _startEventStream() async {
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
    assert(_streamSink != null);
    _streamSink!.eventObservers.add(eventObserver);
    _streamSink!.errorObservers.add(errorObserver);
  }

  void disconnect() {
    if (_inputDevice == null) {
      return;
    }
    _streamSink?.eventObservers.clear();
    _streamSink?.errorObservers.clear();
    _disconnectInputDevice();
  }

  Future<void> _disconnectInputDevice() async {
    assert(_inputDevice != null);
    await _bridge?.disconnect();
    await _streamSink?.stop();
    _streamSink = null;
  }
}
