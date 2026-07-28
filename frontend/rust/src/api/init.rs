#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();

    #[cfg(target_os = "android")]
    ensure_android_context();
}

#[cfg(target_os = "android")]
fn ensure_android_context() {
    backend::init::android::ensure_context();
}

/// JNI_OnLoad is called by the ART runtime when System.loadLibrary() loads our .so.
/// We capture the JavaVM pointer here and initialize ndk_context,
/// so that midir can find it later.
#[cfg(target_os = "android")]
#[no_mangle]
pub extern "system" fn JNI_OnLoad(
    vm: *mut std::ffi::c_void,
    _reserved: *mut std::ffi::c_void,
) -> i32 {
    log::info!("nano: JNI_OnLoad called, initializing ndk_context");
    backend::init::android::init_context(vm);
    0x00010006 // JNI_VERSION_1_6
}
