use std::path::{Path, PathBuf};
use std::sync::OnceLock;

static REPORT_DIR: OnceLock<PathBuf> = OnceLock::new();

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