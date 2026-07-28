pub fn init_context(vm: *mut std::ffi::c_void) {
    unsafe {
        ndk_context::initialize_android_context(vm, std::ptr::null_mut());
    }
}

/*
example use:
pub extern "system" fn JNI_OnLoad(
    vm: *mut std::ffi::c_void,
    _reserved: *mut std::ffi::c_void,
) -> i32 {
    log::info!("nano: JNI_OnLoad called, initializing ndk_context");
    unsafe {
        ndk_context::initialize_android_context(vm, std::ptr::null_mut());
    }
    0x00010006 // JNI_VERSION_1_6
}
*/

pub fn ensure_context() {
    if std::panic::catch_unwind(ndk_context::android_context).is_ok() {
        log::info!("nano: ndk_context already initialized (by JNI_OnLoad)");
    } else {
        log::warn!("nano: ndk_context still not initialized after JNI_OnLoad");
    }
}

#[cfg(target_os = "android")]
pub fn system_property(name: &str) -> Option<String> {
    use std::ffi::CStr;
    let c_name = std::ffi::CString::new(name).ok()?;
    let mut buf = [0u8; 256];
    let len = unsafe {
        libc::__system_property_get(
            c_name.as_ptr() as *const libc::c_char,
            buf.as_mut_ptr() as *mut libc::c_char,
        )
    };
    if len > 0 {
        let val = unsafe { CStr::from_ptr(buf.as_ptr() as *const libc::c_char) };
        val.to_str().ok().map(|s| s.to_string())
    } else {
        None
    }
}
