## MIDI monitor app

The project is a MIDI monitor app (Flutter + Rust) that connects to external MIDI devices and displays live note events. 

## Flutter UI (frontend)

- Flutter UI (frontend/lib)
- Provider for state management

## Rust Bridge Crate (frontend/rust/) 

- FFI bridge layer exposing a Bridge struct to Dart via `flutter_rust_bridge`
- synchronous calls for port listing, 
- async calls for connect/event stream/disconnect.

## Rust Backend Crate (backend)

- Core MIDI logic using midir. 
- Opens real MIDI input connections, formats events as strings ("NOTE_ON 90 40 3C C4"). Has a built-in simulation mode (env var or Android property) for testing without hardware.

- Targets: Android (arm64, x64), Linux desktop.

## Android 

- upload and start:
```
# usb connection 
flutter run -d 25131JEGR02219 --debug 
# wlan connection 
adb connect 192.168.1.100:40869
flutter run -d 192.168.1.100:40869 --debug 
flutter run -d 25131JEGR02219 --debug 
```

- setup the simulation 
```
# set 
adb shell setprop debug.frontend.simulation infinity
# unset 
adb shell "setprop debug.frontend.simulation ''"
```

- watch the log 
```
# usb 
adb -s 25131JEGR02219 logcat -b all -v threadtime,usec *:V
# wlan 
adb -s 192.168.1.100:40869 logcat -b all -v threadtime,usec *:V
```

```
08-13 16:20:22.191748 12851 12911 V rust_lib_frontend::api::init: test log trace
08-13 16:20:22.191805 12851 12911 I rust_lib_frontend::api::init: test log info
08-13 16:20:22.191823 12851 12911 E rust_lib_frontend::api::init: test log error
```
