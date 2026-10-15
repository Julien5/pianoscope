pub use backend::report::{CrashReport, Feedback, UploadOutcome};

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

/// Field-for-field mirror of `backend::report::UploadOutcome`. `cancelled` is a
/// field of its own rather than an error string so that Dart cannot read a
/// user-requested stop as a failed upload. Keep in sync with
/// `backend/src/report.rs`.
#[flutter_rust_bridge::frb(mirror(UploadOutcome))]
pub struct _UploadOutcome {
    pub cancelled: bool,
    pub error: String,
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

/// One cancellable run of uploads. The Dart side keeps it alive for the length
/// of a batch and calls [UploadSession::cancel] to stop; the token behind it
/// dies with the handle, so nothing has to be reset between batches.
#[flutter_rust_bridge::frb(opaque)]
pub struct UploadSession {
    session: backend::report::UploadSession,
}

impl UploadSession {
    #[flutter_rust_bridge::frb(sync)]
    pub fn new() -> Self {
        Self {
            session: backend::report::UploadSession::new(),
        }
    }

    /// Deliberately *not* `#[frb(sync)]`: like the upload itself this is a
    /// network call and must stay off the platform thread.
    pub async fn upload(&self, filename: String) -> UploadOutcome {
        self.session.upload(filename).await
    }

    /// Flipping the token is instantaneous, so the button that calls this does
    /// not have to await anything.
    #[flutter_rust_bridge::frb(sync)]
    pub fn cancel(&self) {
        self.session.cancel();
    }
}
