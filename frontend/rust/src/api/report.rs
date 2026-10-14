pub use backend::report::{CrashReport, Feedback};

/// Field-for-field mirror of `backend::report::CrashReport`. It only exists
/// so that FRB generates a real Dart class; the re-exported type itself is
/// treated as opaque. Keep in sync with `backend/src/report.rs`.
#[flutter_rust_bridge::frb(mirror(CrashReport))]
pub struct _CrashReport {
    pub datetime: String,
    pub location: String,
    pub error_message: String,
    pub stacktrace: String,
}

/// Field-for-field mirror of `backend::report::Feedback`. See [_CrashReport].
#[flutter_rust_bridge::frb(mirror(Feedback))]
pub struct _Feedback {
    pub email: String,
    pub message: String,
    pub screenshot: Vec<u8>,
}

#[flutter_rust_bridge::frb(sync)]
pub fn set_report_dir(dir: String) -> String {
    match backend::report::set_report_dir(&dir) {
        Ok(()) => String::new(),
        Err(err) => err,
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn write_crashreport(report: CrashReport) -> Result<String, String> {
    match backend::report::write_crashreport(report) {
        Ok(path) => Ok(path.to_string_lossy().into_owned()),
        Err(err) => Err(err),
    }
}

/// Stores the feedback in the cache and returns the file name it was given,
/// so the caller can upload exactly that file.
#[flutter_rust_bridge::frb(sync)]
pub fn write_feedback(feedback: Feedback) -> Result<String, String> {
    backend::report::write_feedback(feedback).map(|path| {
        path.file_name()
            .map(|name| name.to_string_lossy().into_owned())
            .unwrap_or_default()
    })
}

/// Sorted names of the reports and feedback still waiting to be uploaded.
pub fn reports_list() -> Vec<String> {
    backend::report::reports_list()
}

/// Upload one pending file, returning an empty string on success or a
/// readable error. Deliberately *not* `#[frb(sync)]`: that would run the
/// blocking HTTP call on the platform thread and freeze the UI.
pub async fn upload(filename: String) -> Result<(), String> {
    backend::report::upload(filename).await
}
