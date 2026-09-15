use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::Duration;

use backend::event::MidiEvent;

fn find_wav_files(dir: &Path, substring: &str) -> std::io::Result<Vec<PathBuf>> {
    let mut matching_files = Vec::new();

    for entry in fs::read_dir(dir)? {
        let entry = entry?;
        let path = entry.path();

        if path.is_file() {
            let is_wav = path
                .extension()
                .and_then(|ext| ext.to_str())
                .map_or(false, |ext| ext.eq_ignore_ascii_case("wav"));

            if is_wav {
                if let Some(file_name) = path.file_name().and_then(|n| n.to_str()) {
                    if file_name.contains(substring) {
                        matching_files.push(path);
                    }
                }
            }
        }
    }

    Ok(matching_files)
}

fn detect(path: &PathBuf) -> Vec<String> {
    let mut backend = backend::backend::Backend::new();

    use std::sync::Arc;
    use std::sync::RwLock;

    let events: Arc<RwLock<Vec<MidiEvent>>> = Arc::new(RwLock::new(Vec::new()));
    let sink = events.clone();
    let event_sender = Arc::new(move |event: MidiEvent| {
        sink.write().unwrap().push(event);
    });

    let error_sender = Arc::new(|msg: String| log::error!("error: {msg}"));

    backend.select_wavfile(&path.to_string_lossy());
    backend.start_stream(event_sender, error_sender);
    while !backend.stream_done() {
        std::thread::sleep(Duration::from_millis(100));
    }
    let captured = events.read().unwrap();
    captured
        .iter()
        .map(|e| format!("{}", e.note_name))
        .collect()
}

fn old_piano_note(pos: usize, note: &str, octave: usize) -> (bool, String, String) {
    let absnote = format!("{}{}", note, octave);
    let directory = format!(
        "/home/julien/delme/old-piano-recordings/position-{}/C{}",
        pos, octave
    );
    let files: Vec<PathBuf> =
        find_wav_files(Path::new(&directory), &format!("{}.wav", note)).expect("no files");
    if files.len() != 1 {
        log::error!("no unique file found for {} {}", directory, note);
    }
    debug_assert_eq!(files.len(), 1);
    let file = files.first().unwrap().clone();
    let file_name = file.to_str().unwrap().to_string();
    let estimates = detect(&file);
    let local_goods = estimates
        .iter()
        .cloned()
        .filter(|estimate| **estimate == absnote)
        .collect::<Vec<_>>();
    let local_bads = estimates
        .iter()
        .cloned()
        .filter(|estimate| **estimate != absnote)
        .collect::<Vec<_>>();
    let (ok, message) = (
        local_goods.len() > local_bads.len(),
        format!(
            "expected={:4} | {} vs. {}",
            absnote,
            local_goods.len(),
            local_bads.len()
        ),
    );

    (ok, message, file_name)
}

#[test]
fn old_piano_all() {
    let _ = env_logger::try_init();
    for pos in 1..=2 {
        let mut bad = Vec::new();
        let mut good = Vec::new();
        for gnote in [
            "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B",
        ] {
            for octave in 1..=7 {
                let (ok, message, file_name) = old_piano_note(pos, gnote, octave);
                if !ok {
                    log::error!("{}", message,);
                    bad.push(file_name.clone());
                } else {
                    log::info!("{}", message,);
                    good.push(file_name.clone());
                }
            }
        }
        let badname = format!("/tmp/old-piano-bad-{}.txt", pos);
        println!("position {}: {} good, {} bad", pos, good.len(), bad.len());
        if pos == 1 {
            debug_assert!(bad.len() <= 26);
        }
        if pos == 2 {
            debug_assert!(bad.len() <= 22);
        }
        std::fs::write(&badname, bad.join("\n").clone()).unwrap();
        println!("position {}: see {} for details", pos, badname);
    }
}

#[test]
fn old_piano_some() {
    let _ = env_logger::try_init();
    let position = 1;
    let octave = 1;
    let mut results = BTreeMap::new();
    for gnote in ["C", "C#", "D"] {
        log::trace!("** test: {:>3}{}", gnote, octave);
        let (ok, message, _file_name) = old_piano_note(position, gnote, octave);
        if !ok {
            log::error!("{}", message,);
        } else {
            log::info!("{}", message,);
        }
        let key = format!("{:>3}{} | {:>15}", gnote, octave, message);
        results.insert(key, ok);
        if gnote == "D" {
            debug_assert!(ok);
        }
    }
}

#[test]
fn old_piano_getting_baseline() {
    let _ = env_logger::try_init();
    let position = 1;
    let octave = 4;
    let mut results = BTreeMap::new();
    for gnote in ["A#"] {
        log::trace!("** test: {:>3}{}", gnote, octave);
        let (ok, message, _file_name) = old_piano_note(position, gnote, octave);
        if !ok {
            log::error!("{}", message,);
        } else {
            log::info!("{}", message,);
        }
        let key = format!("{:>3}{} | {:>15}", gnote, octave, message);
        results.insert(key, ok);
    }
    let mut good = true;
    for (key, ok) in results {
        log::trace!("{} => {}", key, ok);
        if !ok {
            good = false;
        }
    }
    debug_assert!(good);
}
