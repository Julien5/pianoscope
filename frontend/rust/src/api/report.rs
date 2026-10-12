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
pub fn write_report(report: CrashReport) -> String {
    match backend::report::write_report(report) {
        Ok(_) => String::new(),
        Err(err) => err,
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn save_feedback(feedback: Feedback) -> String {
    match backend::report::save_feedback(feedback) {
        Ok(_) => String::new(),
        Err(err) => err,
    }
}

/// Sorted names of the reports and feedback still waiting to be uploaded.
pub fn reports_list() -> Vec<String> {
    backend::report::reports_list()
}

/// Upload one pending file, returning an empty string on success or a
/// readable error. Deliberately *not* `#[frb(sync)]`: that would run the
/// blocking HTTP call on the platform thread and freeze the UI.
pub async fn upload(filename: String) -> String {
    match backend::report::upload(filename).await {
        Ok(()) => String::new(),
        Err(err) => err,
    }
}