use serde::Serialize;
use std::io::Write;
use std::panic::PanicHookInfo;
use std::path::{Path, PathBuf};
use std::sync::{Once, OnceLock};

const REPORT_FILE_PREFIX: &str = "report-";
const REPORT_FILE_SUFFIX: &str = ".json";
const REPORT_FILE_DIGITS: usize = 4;
const REPORT_FILE_ATTEMPTS: u32 = 1000;

static REPORT_DIR: OnceLock<PathBuf> = OnceLock::new();
static PANIC_HOOK: Once = Once::new();

#[derive(Serialize)]
struct CrashReport {
    datetime: String,
    location: String,
    error_message: String,
    stacktrace: String,
}

pub fn set_report_dir(dir: &str) -> Result<(), String> {
    let path = PathBuf::from(dir);
    std::fs::create_dir_all(&path)
        .map_err(|err| format!("cannot create report directory {}: {}", path.display(), err))?;
    log::info!("nano: report directory set to {}", path.display());
    REPORT_DIR.get_or_init(|| path);
    Ok(())
}

pub fn report_dir() -> Option<&'static Path> {
    REPORT_DIR.get().map(PathBuf::as_path)
}

pub fn setup_panic_hook() {
    PANIC_HOOK.call_once(|| {
        let previous = std::panic::take_hook();
        std::panic::set_hook(Box::new(move |info| {
            let _ = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                let (location, error_message) = describe_panic(info);
                let stacktrace = std::backtrace::Backtrace::force_capture().to_string();
                if let Some(path) = write_report(&location, &error_message, &stacktrace) {
                    log::error!("nano: crash report written to {}", path.display());
                } else {
                    log::error!("nano: crash report not written (no report directory)");
                }
            }));
            previous(info);
        }));
        log::info!("nano: panic hook installed");
    });
}

fn describe_panic(info: &PanicHookInfo<'_>) -> (String, String) {
    let location = match info.location() {
        Some(location) => format!("{}:{}", location.file(), location.line()),
        None => "unknown".to_string(),
    };
    let payload = info.payload();
    let error_message = if let Some(message) = payload.downcast_ref::<&'static str>() {
        (*message).to_string()
    } else if let Some(message) = payload.downcast_ref::<String>() {
        message.clone()
    } else {
        "non-string panic payload".to_string()
    };
    (location, error_message)
}

fn write_report(location: &str, error_message: &str, stacktrace: &str) -> Option<PathBuf> {
    let dir = report_dir()?;
    let report = CrashReport {
        datetime: chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Secs, true),
        location: location.to_string(),
        error_message: error_message.to_string(),
        stacktrace: stacktrace.to_string(),
    };
    let json = serde_json::to_string_pretty(&report).ok()?;
    let (path, mut file) = create_report_file(dir)?;
    file.write_all(json.as_bytes()).ok()?;
    file.flush().ok()?;
    Some(path)
}

fn create_report_file(dir: &Path) -> Option<(PathBuf, std::fs::File)> {
    let first = last_report_index(dir).unwrap_or(0) + 1;
    for index in first..first + REPORT_FILE_ATTEMPTS {
        let path = dir.join(format!(
            "{REPORT_FILE_PREFIX}{index:0REPORT_FILE_DIGITS$}{REPORT_FILE_SUFFIX}"
        ));
        match std::fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&path)
        {
            Ok(file) => return Some((path, file)),
            Err(err) if err.kind() == std::io::ErrorKind::AlreadyExists => continue,
            Err(err) => {
                log::error!("nano: cannot create report file: {}", err);
                return None;
            }
        }
    }
    log::error!("nano: no free report file name after {}", first);
    None
}

fn last_report_index(dir: &Path) -> Option<u32> {
    std::fs::read_dir(dir)
        .ok()?
        .filter_map(|entry| entry.ok())
        .filter_map(|entry| {
            let name = entry.file_name();
            let name = name.to_str()?;
            let digits = name
                .strip_prefix(REPORT_FILE_PREFIX)?
                .strip_suffix(REPORT_FILE_SUFFIX)?;
            digits.parse::<u32>().ok()
        })
        .max()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn panic_hook_writes_numbered_reports() {
        let dir =
            std::env::temp_dir().join(format!("pianoscope-report-test-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        set_report_dir(dir.to_str().unwrap()).unwrap();
        assert!(dir.is_dir());

        setup_panic_hook();
        for expected in 1..=2 {
            let result = std::panic::catch_unwind(|| {
                panic!("deliberate panic {expected}");
            });
            assert!(result.is_err());
        }

        let first = dir.join(format!("{REPORT_FILE_PREFIX}0001{REPORT_FILE_SUFFIX}"));
        let second = dir.join(format!("{REPORT_FILE_PREFIX}0002{REPORT_FILE_SUFFIX}"));
        assert!(first.is_file());
        assert!(second.is_file());

        let content = std::fs::read_to_string(&second).unwrap();
        let report: serde_json::Value = serde_json::from_str(&content).unwrap();
        assert_eq!(report["error_message"], "deliberate panic 2");
        assert!(
            report["location"].as_str().unwrap().contains("report.rs:"),
            "unexpected location: {}",
            report["location"]
        );
        assert!(report["datetime"].as_str().unwrap().ends_with('Z'));
        assert!(report["stacktrace"].as_str().unwrap().contains("report::"));

        let _ = std::fs::remove_dir_all(&dir);
    }
}
