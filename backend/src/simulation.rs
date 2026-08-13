pub fn setting() -> Option<String> {
    let val = std::env::var("SIMULATION").ok().or_else(|| {
        #[cfg(target_os = "android")]
        {
            use crate::init::android;
            android::system_property("debug.frontend.simulation")
        }
        #[cfg(not(target_os = "android"))]
        {
            None
        }
    })?;
    if val.is_empty() {
        return None;
    }
    Some(val)
}

pub fn enabled() -> bool {
    setting().is_some()
}
