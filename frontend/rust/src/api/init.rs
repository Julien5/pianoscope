#[cfg(not(target_arch = "wasm32"))]
fn setup_log() {
    println!("init logger");
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
        //.filter_level(log::LevelFilter::Off)
        .try_init();
}

#[cfg(target_arch = "wasm32")]
fn setup_log() {
    println!("init logger not needed in browser (i dont know why)");
}

pub fn setup() {
    setup_log();
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
    setup();
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
