import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import '../../l10n/app_localizations.dart';
import '../notation/models/key_signature.dart';
import '../rust/api/bridge.dart';
import '../rust/api/event.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils.dart';

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

  void clearObservers() {
    eventObservers.clear();
    errorObservers.clear();
  }

  bool hasNoObservers() {
    return eventObservers.isEmpty && errorObservers.isEmpty;
  }

  Future<void> stop() async {
    debugPrint('stop: start');
    clearObservers();
    debugPrint('stop: eventSub.cancel() ...');
    // Why not await? Because there are situations where the cancel() did not complete.
    // Agent says: "Cancelling the FRB stream subscription while the Rust
    // producer is idle never completes.""
    //
    // => do not await.
    (_eventSub?.cancel() ?? Future.value())
        .catchError((Object e) {
          debugPrint('stop: eventSub.cancel() error: $e');
        })
        .whenComplete(() {
          debugPrint('stop: eventSub.cancel() completed');
        });
    debugPrint('stop: errorSub.cancel() ...');
    (_errorSub?.cancel() ?? Future.value())
        .catchError((Object e) {
          debugPrint('stop: errorSub.cancel() error: $e');
        })
        .whenComplete(() {
          debugPrint('stop: errorSub.cancel() completed');
        });
    _eventSub = null;
    _errorSub = null;
    debugPrint('stop: end');
  }
}

sealed class InputDevice {
  String portName();
  String localizedPortName(BuildContext context);
}

class Microphone extends InputDevice {
  @override
  String portName() => 'Microphone';

  @override
  String localizedPortName(BuildContext context) {
    return AppLocalizations.of(context)!.microphone;
  }
}

class Midi extends InputDevice {
  final MidiPort port;
  Midi(this.port);
  @override
  String portName() => port.name;

  @override
  String localizedPortName(BuildContext context) {
    return formatMidiPortName(portName());
  }
}

class InputProvider extends ChangeNotifier {
  Bridge? _bridge;
  List<InputDevice> _inputDevices = [];
  String? _error;
  KeySignature? _keySignature;
  InputDevice? _inputDevice;
  StreamSink? _streamSink;

  bool get hasBridge => _bridge != null;
  List<InputDevice> get inputDevices => _inputDevices;
  String? get error => _error;
  KeySignature? get keySignature => _keySignature;
  set keySignature(KeySignature value) {
    _keySignature = value;
    notifyListeners();
  }

  Future<void> init() async {
    _bridge = await Bridge.newInstance();
    loadInputDevices();
  }

  void loadInputDevices() {
    _inputDevices = [Microphone()];
    try {
      for (MidiPort port in listMidiPorts()) {
        _inputDevices.add(Midi(port));
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> connect(InputDevice device) async {
    debugPrint("connect: $device");
    if (_streamSink != null) {
      debugPrint(
        'connect: disconnecting previous (inputDevice=${_inputDevice != null})',
      );
      assert(_inputDevice != null);
      await disconnect();
      debugPrint('connect: previous disconnected');
    }
    _inputDevice = device;
    debugPrint('connect: starting stream for $device');
    switch (_inputDevice!) {
      case Microphone():
        await _connectMicrophone(_inputDevice as Microphone);
      case Midi(port: final port):
        await _connectMidi(Midi(port));
    }
    assert(_streamSink != null);
    debugPrint('connect: done');
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

  /// Because disconnect() is called (1) synchronously from midi screen dispose (not await)
  /// and (2) from InputProvider::connect() (with await), we must guard _disconnectInputDevice.
  Future<void>? _disconnecting;
  Future<void> disconnect() async {
    if (_inputDevice == null) {
      assert(_streamSink == null);
      return;
    }
    _streamSink?.clearObservers();
    // Assigns a *Future* to _disconnecting if the operation is not in-flight.
    // After `disconnect()` is called without await, _disconnecting is non-null.
    // After `await disconnect()` is called, _disconnecting is null because of whenComplete.
    return _disconnecting ??= _disconnectInputDevice().whenComplete(() {
      _disconnecting = null;
    });
  }

  Future<void> _disconnectInputDevice() async {
    // _inputDevice is the last connected device.
    // after init, it never gets null.
    assert(_inputDevice != null);
    final sink = _streamSink;
    if (sink == null) {
      return;
    }
    assert(sink.hasNoObservers());
    // "publicly disable the sink".
    _streamSink = null;
    await _bridge?.disconnect();
    await sink.stop();
  }
}
