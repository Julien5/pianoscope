## MIDI monitor app

The project is a MIDI monitor app (Flutter + Rust) that connects to external MIDI devices and displays live note events. 

## Flutter UI (nano/lib)

- Flutter UI (nano/lib)
- Provider for state management

## Rust Bridge Crate (nano/rust/) 

- FFI bridge layer exposing a Bridge struct to Dart via `flutter_rust_bridge`
- synchronous calls for port listing, 
- async calls for connect/event stream/disconnect.

## Rust Backend Crate (nano-backend/)

- Core MIDI logic using midir. 
- Opens real MIDI input connections, formats events as strings ("NOTE_ON 90 40 3C C4"). Has a built-in simulation mode (env var or Android property) for testing without hardware.

- Targets: Android (arm64, x64), Linux desktop.
