use std::fs;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

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

#[test]
fn old_piano_samples() {
    let _ = env_logger::try_init();
    let mut bad = Vec::new();
    let mut good = Vec::new();
    for pos in 1..=2 {
        for n in 1..=5 {
            let directory = format!(
                "/home/julien/delme/old-piano-recordings/position-{}/C{}",
                pos, n
            );
            for gnote in [
                "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B",
            ] {
                let note = format!("{}{}", gnote, n);
                let files: Vec<PathBuf> =
                    find_wav_files(Path::new(&directory), &format!("{}.wav", gnote))
                        .expect("no files");
                if files.len() != 1 {
                    log::error!("no unique file found for {} {}", directory, gnote);
                }
                debug_assert_eq!(files.len(), 1);
                let file = files.first().unwrap().clone();
                let file_name = file.to_str().unwrap().to_string();
                let file_size = std::fs::metadata(&file).unwrap().len() / 1024;
                let now = Instant::now();
                let estimates = detect(&file);
                let elapsed = now.elapsed();
                let local_goods = estimates
                    .iter()
                    .cloned()
                    .filter(|estimate| **estimate == note)
                    .collect::<Vec<_>>();
                let local_bads = estimates
                    .iter()
                    .cloned()
                    .filter(|estimate| **estimate != note)
                    .collect::<Vec<_>>();
                let (ok, message) = (
                    local_goods.len() > local_bads.len(),
                    format!(
                        "expected={:4} | {} vs. {}",
                        note,
                        local_goods.len(),
                        local_bads.len()
                    ),
                );

                if !ok {
                    log::error!(
                        "{} ({}K, {:.3} ms)",
                        message,
                        file_size,
                        elapsed.as_millis()
                    );
                    bad.push(file_name.clone());
                    //debug_assert!(false);
                } else {
                    log::info!(
                        "{} ({}K, {:.3} ms)",
                        message,
                        file_size,
                        elapsed.as_millis()
                    );
                    good.push(file_name.clone());
                }
            }
        }
    }

    let badname = "/tmp/old-piano-bad.txt";
    println!("{} good, {} bad", good.len(), bad.len());
    std::fs::write(&badname, bad.join("\n").clone()).unwrap();
    println!("see {} for details", badname);
}
