use backend::event::MidiEvent;

#[test]
fn piano_samples() {
    let _ = env_logger::try_init();
    log::trace!("hi from the test");
    let mut backend = backend::backend::Backend::new();

    use std::sync::Arc;
    use std::sync::RwLock;

    let events: Arc<RwLock<Vec<MidiEvent>>> = Arc::new(RwLock::new(Vec::new()));
    let sink = events.clone();
    let event_sender = Arc::new(move |event: MidiEvent| {
        log::trace!("midi event: {}", event.note_name);
        sink.write().unwrap().push(event);
    });

    let error_sender = Arc::new(|msg: String| log::error!("midi error: {msg}"));

    let path = "hi";
    unsafe {
        log::trace!("export SIMULATION={}", path);
        std::env::set_var("SIMULATION", path);
    }

    backend.select_microphone();
    backend.start_stream(event_sender, error_sender);
    let captured = events.read().unwrap();
    for e in captured.iter() {
        log::trace!(
            "{} {} velocity={}",
            e.note_name,
            e.status == backend::event::Status::NoteOn,
            e.velocity
        );
    }
}
