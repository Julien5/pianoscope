use serde::{Deserialize, Serialize};
use std::io::Write;
use std::panic::PanicHookInfo;
use std::path::{Path, PathBuf};
use std::sync::{Once, OnceLock};

const REPORT_FILE_PREFIX: &str = "report-";
const FEEDBACK_FILE_PREFIX: &str = "feedback-";
const REPORT_FILE_SUFFIX: &str = ".json";
const REPORT_FILE_DIGITS: usize = 4;
const REPORT_FILE_ATTEMPTS: u32 = 1000;

static REPORT_DIR: OnceLock<PathBuf> = OnceLock::new();
static PANIC_HOOK: Once = Once::new();

/// A crash, as stored in `report-NNNN.json` and uploaded to the monitoring
/// server. The Dart side builds the same shape (see `lib/src/report.dart`);
/// keep `datetime` in RFC 3339 UTC with second precision.
#[derive(Serialize, Deserialize, Clone)]
pub struct CrashReport {
    pub datetime: String,
    pub location: String,
    pub error_message: String,
    pub stacktrace: String,
}

impl CrashReport {
    pub fn new(location: &str, error_message: &str, stacktrace: &str) -> Self {
        Self {
            datetime: now_rfc3339(),
            location: location.to_string(),
            error_message: error_message.to_string(),
            stacktrace: stacktrace.to_string(),
        }
    }
}

/// User feedback, as stored in `feedback-NNNN.json` while the monitoring
/// server is unreachable. `screenshot` is serialized as base64 so the file
/// stays a single self-contained JSON document.
#[derive(Serialize, Deserialize, Clone)]
pub struct Feedback {
    pub email: String,
    pub message: String,
    #[serde(with = "base64_bytes")]
    pub screenshot: Vec<u8>,
}

fn now_rfc3339() -> String {
    chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Secs, true)
}

mod base64_bytes {
    use base64::Engine;
    use base64::engine::general_purpose::STANDARD as BASE64;
    use serde::{Deserialize, Deserializer, Serializer};

    pub fn serialize<S: Serializer>(bytes: &[u8], serializer: S) -> Result<S::Ok, S::Error> {
        serializer.serialize_str(&BASE64.encode(bytes))
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(deserializer: D) -> Result<Vec<u8>, D::Error> {
        let text = String::deserialize(deserializer)?;
        BASE64.decode(text).map_err(serde::de::Error::custom)
    }
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
                let report = CrashReport::new(&location, &error_message, &stacktrace);
                if let Err(err) = write_report(report) {
                    log::error!("nano: crash report not written: {}", err);
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

pub fn write_report(report: CrashReport) -> Result<PathBuf, String> {
    let dir = report_dir().ok_or("report directory is not set")?;
    let json = serde_json::to_string_pretty(&report)
        .map_err(|err| format!("cannot serialize report: {}", err))?;
    let (path, mut file) =
        create_indexed_file(dir, REPORT_FILE_PREFIX).ok_or("cannot create report file")?;
    file.write_all(json.as_bytes())
        .map_err(|err| format!("cannot write report: {}", err))?;
    file.flush()
        .map_err(|err| format!("cannot flush report: {}", err))?;
    log::error!("nano: crash report written to {}", path.display());
    Ok(path)
}

pub fn save_feedback(feedback: Feedback) -> Result<PathBuf, String> {
    let dir = report_dir().ok_or("report directory is not set")?;
    let json = serde_json::to_string_pretty(&feedback)
        .map_err(|err| format!("cannot serialize feedback: {}", err))?;
    let (path, mut file) =
        create_indexed_file(dir, FEEDBACK_FILE_PREFIX).ok_or("cannot create feedback file")?;
    file.write_all(json.as_bytes())
        .map_err(|err| format!("cannot write feedback: {}", err))?;
    file.flush()
        .map_err(|err| format!("cannot flush feedback: {}", err))?;
    log::info!("nano: feedback saved to {}", path.display());
    Ok(path)
}

fn create_indexed_file(dir: &Path, prefix: &str) -> Option<(PathBuf, std::fs::File)> {
    let first = last_index(dir, prefix).unwrap_or(0) + 1;
    for index in first..first + REPORT_FILE_ATTEMPTS {
        let path = dir.join(format!(
            "{prefix}{index:0REPORT_FILE_DIGITS$}{REPORT_FILE_SUFFIX}"
        ));
        match std::fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&path)
        {
            Ok(file) => return Some((path, file)),
            Err(err) if err.kind() == std::io::ErrorKind::AlreadyExists => continue,
            Err(err) => {
                log::error!("nano: cannot create file {}: {}", path.display(), err);
                return None;
            }
        }
    }
    log::error!("nano: no free file name for {} after {}", prefix, first);
    None
}

fn last_index(dir: &Path, prefix: &str) -> Option<u32> {
    std::fs::read_dir(dir)
        .ok()?
        .filter_map(|entry| entry.ok())
        .filter_map(|entry| {
            let name = entry.file_name();
            let name = name.to_str()?;
            let digits = name
                .strip_prefix(prefix)?
                .strip_suffix(REPORT_FILE_SUFFIX)?;
            digits.parse::<u32>().ok()
        })
        .max()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_dir() -> PathBuf {
        std::env::temp_dir().join(format!("pianoscope-report-test-{}", std::process::id()))
    }

    #[test]
    fn writes_numbered_reports_and_feedback_with_independent_counters() {
        let dir = temp_dir();
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

        let png = vec![0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a];
        for message in ["first message", "second message"] {
            let feedback = Feedback {
                email: "me@example.com".to_string(),
                message: message.to_string(),
                screenshot: png.clone(),
            };
            assert!(save_feedback(feedback).unwrap().is_file());
        }

        let named = |prefix: &str, index: u32| {
            dir.join(format!(
                "{prefix}{index:0REPORT_FILE_DIGITS$}{REPORT_FILE_SUFFIX}"
            ))
        };
        let crash_first = named(REPORT_FILE_PREFIX, 1);
        let crash_second = named(REPORT_FILE_PREFIX, 2);
        let feedback_first = named(FEEDBACK_FILE_PREFIX, 1);
        let feedback_second = named(FEEDBACK_FILE_PREFIX, 2);
        for path in [
            &crash_first,
            &crash_second,
            &feedback_first,
            &feedback_second,
        ] {
            assert!(path.is_file(), "missing {}", path.display());
        }
        assert!(!named(REPORT_FILE_PREFIX, 3).exists());
        assert!(!named(FEEDBACK_FILE_PREFIX, 3).exists());

        let content = std::fs::read_to_string(&crash_second).unwrap();
        let report: serde_json::Value = serde_json::from_str(&content).unwrap();
        assert_eq!(report["error_message"], "deliberate panic 2");
        assert!(
            report["location"].as_str().unwrap().contains("report.rs:"),
            "unexpected location: {}",
            report["location"]
        );
        assert!(report["datetime"].as_str().unwrap().ends_with('Z'));
        assert!(report["stacktrace"].as_str().unwrap().contains("report::"));

        let content = std::fs::read_to_string(&feedback_second).unwrap();
        let raw: serde_json::Value = serde_json::from_str(&content).unwrap();
        assert_eq!(raw["email"], "me@example.com");
        assert_eq!(raw["message"], "second message");
        assert_eq!(raw["screenshot"], "iVBORw0K");
        assert_ne!(content, std::fs::read_to_string(&feedback_first).unwrap());

        let feedback: Feedback = serde_json::from_str(&content).unwrap();
        assert_eq!(feedback.screenshot, png);
        assert_eq!(feedback.email, "me@example.com");

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn empty_screenshot_round_trips() {
        let feedback = Feedback {
            email: String::new(),
            message: "no picture".to_string(),
            screenshot: Vec::new(),
        };
        let json = serde_json::to_string(&feedback).unwrap();
        assert!(json.contains("\"screenshot\":\"\""));
        let parsed: Feedback = serde_json::from_str(&json).unwrap();
        assert!(parsed.screenshot.is_empty());
    }

    #[test]
    fn crash_report_new_stamps_rfc3339_seconds() {
        let report = CrashReport::new("a.rs:1", "boom", "trace");
        assert_eq!(report.datetime.len(), 20);
        assert!(report.datetime.ends_with('Z'));
        assert_eq!(&report.datetime[4..5], "-");
        assert_eq!(&report.datetime[10..11], "T");
        assert_eq!(&report.datetime[13..14], ":");
    }
}
