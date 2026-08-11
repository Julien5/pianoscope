mod main_audio;
mod main_midi;

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

use clap::{Parser, Subcommand};

#[derive(Subcommand)]
enum Source {
    WavFile { path: String },
    Microphone,
    Simulation { loops: String },
    Midi { port: u32 },
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
    match cli.source {
        Source::WavFile { path } => main_audio::main(Some(path)),
        Source::Microphone => main_audio::main(None),
        Source::Simulation { loops } => {
            unsafe {
                std::env::set_var("SIMULATION", loops);
            }
            main_midi::main(0);
        }
        Source::Midi { port } => main_midi::main(port),
    }

    //;
}
