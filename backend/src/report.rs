use serde::{Deserialize, Serialize};
use std::io::Write;
use std::panic::PanicHookInfo;
use std::path::{Path, PathBuf};
use std::sync::{Once, OnceLock};
use std::time::Duration;

const REPORT_FILE_PREFIX: &str = "report-";
const FEEDBACK_FILE_PREFIX: &str = "feedback-";
const REPORT_FILE_SUFFIX: &str = ".json";
const REPORT_FILE_DIGITS: usize = 4;
const REPORT_FILE_ATTEMPTS: u32 = 1000;

// https://www.localhost/api/v1/feedback-x92z/health
const SERVER_BASE_URL: &str = "https://www.localhost/api/v1/feedback-x92z/";
const SERVER_APP_ID: &str = "pianoscope";
const SERVER_TIMEOUT: Duration = Duration::from_secs(30);
/// The server caps the `report` part at 1 MB.
const MAX_REPORT_BYTES: usize = 1_000_000;

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
    use base64::engine::general_purpose::STANDARD as BASE64;
    use base64::Engine;
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
                if let Err(err) = write_crashreport(report) {
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

pub fn write_crashreport(report: CrashReport) -> Result<PathBuf, String> {
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

pub fn write_feedback(feedback: Feedback) -> Result<PathBuf, String> {
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
        .filter_map(|entry| entry.file_name().into_string().ok())
        .filter_map(|name| report_index(&name, prefix))
        .max()
}

/// True for `report-<digits>.json` and `feedback-<digits>.json` only. This is
/// also the guard that makes `dir.join(name)` safe in [upload]: anything with
/// a separator, a `..` or a different extension is rejected before it can
/// reach the filesystem.
pub fn is_report_name(name: &str) -> bool {
    [REPORT_FILE_PREFIX, FEEDBACK_FILE_PREFIX]
        .iter()
        .copied()
        .any(|prefix| report_index(name, prefix).is_some())
}

fn report_index(name: &str, prefix: &str) -> Option<u32> {
    name.strip_prefix(prefix)?
        .strip_suffix(REPORT_FILE_SUFFIX)?
        .parse::<u32>()
        .ok()
}

/// Upload one report or feedback file and delete it once the server has
/// accepted it. Safe to call concurrently with the rest of the report
/// machinery; the file is only removed after a 2xx response, so a failure
/// leaves it on disk to be retried on the next run.
///
/// Blocking work is pushed onto the blocking pool so that the async runtime
/// thread is not held for the whole request.
pub async fn upload(filename: String) -> Result<(), String> {
    tokio::task::spawn_blocking(move || upload_blocking(&filename))
        .await
        .map_err(|err| format!("upload task failed: {}", err))?
}

fn upload_blocking(filename: &str) -> Result<(), String> {
    if !is_report_name(filename) {
        return Err(format!("invalid report name: {}", filename));
    }
    let dir = report_dir().ok_or("report directory is not set")?;
    let path = dir.join(filename);
    let content = std::fs::read_to_string(&path)
        .map_err(|err| format!("cannot read {}: {}", path.display(), err))?;

    let body = build_submit_body(filename, &content)?;
    let mut screenshot: &[u8] = body.screenshot.as_deref().unwrap_or(&[]);
    let mut form = ureq::unversioned::multipart::Form::new()
        .text("message", &body.message)
        .text("application_id", SERVER_APP_ID)
        .text("application_version", env!("CARGO_PKG_VERSION"))
        .text("platform", std::env::consts::OS)
        .text("report", &body.report);
    if !screenshot.is_empty() {
        let part = ureq::unversioned::multipart::Part::reader(&mut screenshot)
            .file_name("screenshot.png")
            .mime_str("image/png")
            .map_err(|err| format!("invalid screenshot mime type: {}", err))?;
        form = form.part("screenshot", part);
    }

    let agent = build_agent();
    let url = format!("{}{}", SERVER_BASE_URL, "submit");
    log::trace!("url={}", url);
    agent
        .post(&url)
        .header("X-App-ID", SERVER_APP_ID)
        .send(form)
        .map_err(|err| describe_ureq_error(&err))?;

    std::fs::remove_file(&path)
        .map_err(|err| format!("cannot delete {}: {}", path.display(), err))?;
    log::info!("nano: {} uploaded and deleted", filename);
    Ok(())
}

/// The pieces of one submit request, kept apart from the multipart encoding
/// so they can be checked without a server.
struct SubmitBody {
    message: String,
    report: String,
    screenshot: Option<Vec<u8>>,
}

/// The `message` part is mandatory server side and must not be blank, so
/// crash reports get a synthesised one (they carry no user message) while
/// feedback uses the text the user typed.
fn build_submit_body(filename: &str, content: &str) -> Result<SubmitBody, String> {
    let feedback = parse_feedback(filename, content);
    let message = match feedback.as_ref() {
        None => format!("Pianoscope crash report ({})", filename),
        Some(feedback) => {
            let typed = feedback.message.trim();
            if typed.is_empty() {
                format!("Pianoscope feedback ({})", filename)
            } else {
                typed.to_string()
            }
        }
    };
    let screenshot = feedback
        .filter(|feedback| !feedback.screenshot.is_empty())
        .map(|feedback| feedback.screenshot);
    Ok(SubmitBody {
        message,
        report: truncate_utf8(content, MAX_REPORT_BYTES),
        screenshot,
    })
}

/// Decodes a `feedback-NNNN.json` payload; crash reports never carry one.
fn parse_feedback(filename: &str, content: &str) -> Option<Feedback> {
    if !filename.starts_with(FEEDBACK_FILE_PREFIX) {
        return None;
    }
    serde_json::from_str(content).ok()
}

fn build_agent() -> ureq::Agent {
    ureq::Agent::config_builder()
        .timeout_global(Some(SERVER_TIMEOUT))
        .user_agent(SERVER_APP_ID)
        .tls_config(
            ureq::tls::TlsConfig::builder()
                .disable_verification(true)
                .build(),
        )
        .build()
        .into()
}

/// Cuts `text` to at most `max_bytes` without splitting a UTF-8 character.
fn truncate_utf8(text: &str, max_bytes: usize) -> String {
    if text.len() <= max_bytes {
        return text.to_string();
    }
    let mut end = max_bytes;
    while end > 0 && !text.is_char_boundary(end) {
        end -= 1;
    }
    text[..end].to_string()
}

/// ureq's `Debug` output is a multi-line dump of the whole error chain, so
/// flatten it to one readable line instead.
fn describe_ureq_error(err: &ureq::Error) -> String {
    let mut message = err.to_string();
    let mut source = std::error::Error::source(err);
    while let Some(cause) = source {
        let text = cause.to_string();
        if !text.is_empty() {
            message.push_str(": ");
            message.push_str(&text);
        }
        source = cause.source();
    }
    message
}

/// Sorted names of the reports and feedback still waiting to be sent. Sorted
/// lexically, which equals numeric order because the index is zero padded.
pub fn reports_list() -> Vec<String> {
    let Some(dir) = report_dir() else {
        return Vec::new();
    };
    let mut names: Vec<String> = std::fs::read_dir(dir)
        .into_iter()
        .flatten()
        .filter_map(|entry| entry.ok())
        .filter(|entry| entry.file_type().is_ok_and(|kind| kind.is_file()))
        .filter_map(|entry| entry.file_name().into_string().ok())
        .filter(|name| is_report_name(name))
        .collect();
    names.sort();
    names
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_dir() -> PathBuf {
        std::env::temp_dir().join(format!("pianoscope-report-test-{}", std::process::id()))
    }

    /// Walks the whole lifecycle: panic -> numbered file -> listed -> uploaded
    /// and deleted. Everything that touches the report directory has to live in
    /// a single test, because `REPORT_DIR` is a process-wide `OnceLock`: a
    /// second test running in parallel would share the same directory and
    /// clobber this one's files.
    #[test]
    fn reports_are_written_listed_and_deleted_after_upload() {
        let _ = env_logger::try_init();
        let dir = temp_dir();
        let _ = std::fs::remove_dir_all(&dir);
        set_report_dir(dir.to_str().unwrap()).unwrap();
        assert!(dir.is_dir());

        let named = |prefix: &str, index: u32| {
            dir.join(format!(
                "{prefix}{index:0REPORT_FILE_DIGITS$}{REPORT_FILE_SUFFIX}"
            ))
        };

        // Panics become numbered crash reports.
        setup_panic_hook();
        for expected in 1..=2 {
            let result = std::panic::catch_unwind(|| {
                panic!("deliberate panic {expected}");
            });
            assert!(result.is_err());
        }

        // Feedback shares the directory but keeps its own counter.
        let png = vec![0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a];
        for message in ["first message", "second message"] {
            let feedback = Feedback {
                email: "me@example.com".to_string(),
                message: message.to_string(),
                screenshot: png.clone(),
            };
            assert!(write_feedback(feedback).unwrap().is_file());
        }

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

        // The screenshot is base64 on disk and decodes back to the original.
        let content = std::fs::read_to_string(&feedback_second).unwrap();
        let raw: serde_json::Value = serde_json::from_str(&content).unwrap();
        assert_eq!(raw["email"], "me@example.com");
        assert_eq!(raw["message"], "second message");
        assert_eq!(raw["screenshot"], "iVBORw0K");
        assert_ne!(content, std::fs::read_to_string(&feedback_first).unwrap());

        let feedback: Feedback = serde_json::from_str(&content).unwrap();
        assert_eq!(feedback.screenshot, png);
        assert_eq!(feedback.email, "me@example.com");

        assert_eq!(
            reports_list(),
            vec![
                "feedback-0001.json".to_string(),
                "feedback-0002.json".to_string(),
                "report-0001.json".to_string(),
                "report-0002.json".to_string(),
            ]
        );

        // Anything that is not exactly `<kind>-<digits>.json` is ignored,
        // including a directory that happens to be named like a report.
        let junk = [
            "notes.txt",
            "report-.json",
            "report-0003.txt",
            "report-abc.json",
            "report-0004.json.tmp",
            "crash-0001.json",
            "myreport-0005.json",
        ];
        for name in junk {
            std::fs::write(dir.join(name), "{}").unwrap();
        }
        std::fs::create_dir(dir.join("report-0006.json")).unwrap();
        assert_eq!(
            reports_list(),
            vec![
                "feedback-0001.json".to_string(),
                "feedback-0002.json".to_string(),
                "report-0001.json".to_string(),
                "report-0002.json".to_string(),
            ]
        );
        for name in junk {
            std::fs::remove_file(dir.join(name)).unwrap();
        }
        std::fs::remove_dir(dir.join("report-0006.json")).unwrap();

        // The live upload needs the real server: both files must come back
        // deleted, which is what lets the next launch skip them.
        let upload_png = vec![0x89u8, 0x50, 0x4e, 0x47];
        let feedback_path = write_feedback(Feedback {
            email: "me@example.com".to_string(),
            message: "the staff is shifted".to_string(),
            screenshot: upload_png.clone(),
        })
        .unwrap();
        let crash_path = write_crashreport(CrashReport::new("a.rs:1", "boom", "trace")).unwrap();
        assert_eq!(
            reports_list(),
            vec![
                "feedback-0001.json".to_string(),
                "feedback-0002.json".to_string(),
                "feedback-0003.json".to_string(),
                "report-0001.json".to_string(),
                "report-0002.json".to_string(),
                "report-0003.json".to_string(),
            ]
        );

        for path in [&feedback_path, &crash_path] {
            let name = path.file_name().unwrap().to_str().unwrap();
            upload_blocking(name).unwrap_or_else(|err| panic!("upload of {name} failed: {err}"));
        }

        for path in [&feedback_path, &crash_path] {
            assert!(
                !path.exists(),
                "{} should be deleted after 2xx",
                path.display()
            );
        }
        assert_eq!(
            reports_list(),
            vec![
                "feedback-0001.json".to_string(),
                "feedback-0002.json".to_string(),
                "report-0001.json".to_string(),
                "report-0002.json".to_string(),
            ],
            "only the uploaded files should be gone"
        );

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn report_name_validation_rejects_traversal() {
        for good in ["report-0001.json", "feedback-42.json", "report-9999.json"] {
            assert!(is_report_name(good), "should accept {good}");
        }
        for bad in [
            "",
            "report-.json",
            "report-abc.json",
            "report-0001.txt",
            "report-0001.json.tmp",
            "../report-0001.json",
            "report-../../etc/passwd",
            "/etc/passwd",
            "report-0001.json/",
            "nested/report-0001.json",
            "myreport-0001.json",
        ] {
            assert!(!is_report_name(bad), "should reject {bad}");
        }
    }

    #[test]
    fn upload_rejects_invalid_names_before_touching_disk_or_network() {
        let error = upload_blocking("../../etc/passwd").unwrap_err();
        assert!(error.contains("invalid report name"), "got {error}");
    }

    #[test]
    fn truncate_utf8_never_splits_a_character() {
        assert_eq!(truncate_utf8("hello", 100), "hello");
        assert_eq!(truncate_utf8("hello", 5), "hello");
        assert_eq!(truncate_utf8("hello", 3), "hel");

        // "é" is two bytes: "aé" fits in 3, and a 2 byte limit cuts back to "a".
        assert_eq!(truncate_utf8("aé", 3), "aé");
        assert_eq!(truncate_utf8("aé", 2), "a");
        assert_eq!(truncate_utf8("aé", 1), "a");
        assert_eq!(truncate_utf8("aé", 0), "");

        let long = "x".repeat(MAX_REPORT_BYTES + 500);
        let cut = truncate_utf8(&long, MAX_REPORT_BYTES);
        assert_eq!(cut.len(), MAX_REPORT_BYTES);
    }

    #[test]
    fn crash_submit_body_synthesises_a_non_empty_message() {
        let content = "{\"datetime\":\"2026-10-12T05:00:00Z\"}";
        let body = build_submit_body("report-0007.json", content).unwrap();

        assert!(!body.message.trim().is_empty());
        assert!(body.message.contains("report-0007.json"));
        assert_eq!(body.report, content);
        assert!(body.screenshot.is_none());
    }

    #[test]
    fn feedback_submit_body_uses_the_typed_message_and_screenshot() {
        let png = vec![0x89, 0x50, 0x4e, 0x47];
        let feedback = Feedback {
            email: "me@example.com".to_string(),
            message: "  the staff is shifted  ".to_string(),
            screenshot: png.clone(),
        };
        let content = serde_json::to_string(&feedback).unwrap();
        let body = build_submit_body("feedback-0002.json", &content).unwrap();

        assert_eq!(body.message, "the staff is shifted");
        assert_eq!(body.report, content);
        assert_eq!(body.screenshot.unwrap(), png);
    }

    #[test]
    fn feedback_submit_body_falls_back_when_the_message_is_blank() {
        let content = serde_json::to_string(&Feedback {
            email: String::new(),
            message: "   ".to_string(),
            screenshot: Vec::new(),
        })
        .unwrap();
        let body = build_submit_body("feedback-0003.json", &content).unwrap();

        assert!(!body.message.trim().is_empty());
        assert!(body.message.contains("feedback-0003.json"));
        assert!(body.screenshot.is_none());
    }

    #[test]
    fn feedback_submit_body_survives_a_corrupt_payload() {
        let body = build_submit_body("feedback-0004.json", "not json at all").unwrap();
        assert!(!body.message.trim().is_empty());
        assert!(body.screenshot.is_none());
        assert_eq!(body.report, "not json at all");
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
