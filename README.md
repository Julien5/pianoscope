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

## Golden Tests

From the `frontend/` directory:

```sh
flutter test
```

To update the baseline images after intentional rendering changes:

```sh
flutter test --update-goldens
```

The tests load the Bravura/Petaluma fonts from the `flutter_music_notation` package, so they should run from a machine where that package is checked out at `../flutter_music_notation`.
