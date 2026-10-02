import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import '../../l10n/app_localizations.dart';
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

  void stop() {
    clearObservers();
    // Why not await? Because there are situations where the cancel() did not complete.
    // Agent says: "Cancelling the FRB stream subscription while the Rust
    // producer is idle never completes.""
    _cancel(_eventSub, 'eventSub');
    _cancel(_errorSub, 'errorSub');
    _eventSub = null;
    _errorSub = null;
  }

  void _cancel(StreamSubscription<dynamic>? sub, String name) {
    if (sub == null) return;
    unawaited(
      sub
          .cancel()
          .catchError((Object e) {
            debugPrint('StreamSink: $name.cancel() error: $e');
          })
          .whenComplete(() {
            debugPrint('StreamSink: $name.cancel() completed');
          }),
    );
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
  
  InputDevice? _inputDevice;
  StreamSink? _streamSink;

  bool get hasBridge => _bridge != null;
  List<InputDevice> get inputDevices => _inputDevices;
  String? get error => _error;

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

  /// Serializes [connect] calls: two rapid taps on the device list must not
  /// both reach `select_*`, which asserts the backend has no source yet. The
  /// last call wins -- it runs after the previous one, whose connection its own
  /// teardown removes.
  Future<void> _connectTail = Future.value();

  Future<void> connect(InputDevice device) {
    final result = _connectTail.then((_) => _connect(device));
    // The tail must not inherit a failure, or the next tap would be skipped
    // (a denied microphone permission would wedge the whole list).
    _connectTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _connect(InputDevice device) async {
    debugPrint("connect: $device");
    // Always awaited, even when `_streamSink` is already null:
    // `MidiSignalScreen.dispose()` starts the teardown without awaiting, and it
    // nulls `_streamSink` synchronously while `_bridge.disconnect()` is still
    // in flight. Skipping it would let `select_*`/`startStream` race that
    // teardown, and `Backend::disconnect` sets `source = None` last.
    await disconnect();
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
    if (sink != null) {
      assert(sink.hasNoObservers());
    }
    // "publicly disable the sink", synchronously
    _streamSink = null;
    await _bridge?.disconnect();
    // After the await on purpose: `disconnect` drops the event sender, so FRB
    // posts `close_stream` and `cancel()` is far likelier to complete.
    sink?.stop();
  }
}
