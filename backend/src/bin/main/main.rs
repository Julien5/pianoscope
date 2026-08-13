fn setup_log() {
    // println!("init logger");
    //env_logger::init();

    use std::io::Write;
    let _ = env_logger::Builder::new()
        .format(|buf, record| {
            writeln!(
                buf,
                "{} [{}] - {}",
                chrono::Local::now().format("%H:%M:%S:%f"),
                record.level(),
                record.args()
            )
        })
        .filter_level(log::LevelFilter::Trace)
        .try_init();
}

use std::{sync::Arc, time::Duration};

use backend::{backend::Backend, event::Event};
use clap::{Parser, Subcommand};

#[derive(Subcommand)]
enum Source {
    WavFile { path: String },
    Microphone,
    Simulation { loops: String },
    Midi { port: usize },
}

#[derive(Parser)]
#[command(version, about)]
struct Cli {
    #[command(subcommand)]
    source: Source,
}

fn main() {
    setup_log();
    let cli = Cli::parse();
    let mut backend = backend::backend::Backend::new_debug();

    let event_sender = Arc::new(|event: Event| log::trace!("midi event: {}", event.note_name));
    let error_sender = Arc::new(|msg: String| log::error!("midi error: {msg}"));

    match cli.source {
        Source::WavFile { path } => {
            unsafe {
                log::trace!("export SIMULATION={}", path);
                std::env::set_var("SIMULATION", path);
            }
            backend.select_microphone();
            backend.start_stream(event_sender, error_sender);
        }
        Source::Microphone => {
            backend.select_microphone();
            backend.start_stream(event_sender, error_sender);
        }
        Source::Simulation { loops } => {
            unsafe {
                log::trace!("export SIMULATION={}", loops);
                std::env::set_var("SIMULATION", format!("{}", loops));
            }
            let list = Backend::list_midi_ports();
            backend.select_midi_port(list.first().unwrap());
            backend.start_stream(event_sender, error_sender);
        }
        Source::Midi { port } => {
            let list = Backend::list_midi_ports();
            backend.select_midi_port(&list[port]);
            backend.start_stream(event_sender, error_sender);
        }
    }
    log::trace!("stream is started");
    loop {
        std::thread::sleep(Duration::from_secs(1));
    }
}
