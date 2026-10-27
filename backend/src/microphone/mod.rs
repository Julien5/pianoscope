#![allow(dead_code)]

pub mod consumer;
pub mod detection;
pub mod device;
pub mod file;
pub(crate) mod processor;

use std::path::PathBuf;
use std::sync::Mutex;

use crate::debug::DebugServerHandle;
use crate::event;
use crate::microphone::device::ActiveDevice;
use crate::microphone::file::ActiveWavFile;

pub fn wavfile(filename: &str) -> WavfileSpec {
    WavfileSpec {
        path: PathBuf::from(filename),
        paced: true,
        looped: true,
    }
}

pub fn wavfile_test(filename: &str) -> WavfileSpec {
    WavfileSpec {
        path: PathBuf::from(filename),
        paced: false,
        looped: false,
    }
}

pub struct Session<A> {
    active: Mutex<Option<A>>,
}

impl<A> Session<A> {
    pub fn none() -> Self {
        Self {
            active: Mutex::new(None),
        }
    }

    fn install(&self, active: A) {
        let old = {
            let mut current = self.active.lock().unwrap();
            current.replace(active)
        };
        drop(old);
    }
}

pub struct Device {
    session: Session<ActiveDevice>,
}

#[derive(Clone)]
pub struct WavfileSpec {
    pub path: PathBuf,
    pub paced: bool,
    pub looped: bool,
}

pub struct Wavfile {
    pub spec: WavfileSpec,
    session: Session<ActiveWavFile>,
}

pub enum Input {
    DeviceInput(Device),
    FileInput(Wavfile),
}

pub struct Microphone {
    input: Input,
}

pub struct Senders {
    pub event_sender: event::EventSender,
    pub error_sender: event::ErrorSender,
    pub debug_handle: Option<DebugServerHandle>,
}

fn install<A>(session: &Session<A>, result: Result<A, String>, error: event::ErrorSender) {
    match result {
        Ok(active) => session.install(active),
        Err(message) => error(message),
    }
}

impl Microphone {
    pub fn new_device() -> Self {
        let input = Input::DeviceInput(Device {
            session: Session::none(),
        });
        Self { input }
    }

    pub fn new_wavfile(path: &str) -> Self {
        let input = Input::FileInput(Wavfile {
            spec: wavfile(path),
            session: Session::none(),
        });
        Self { input }
    }

    pub fn new_wavfile_test(path: &str) -> Self {
        let input = Input::FileInput(Wavfile {
            spec: wavfile_test(path),
            session: Session::none(),
        });
        Self { input }
    }

    pub fn start_stream(
        &self,
        event_sender: event::EventSender,
        error_sender: event::ErrorSender,
        debug_handle: Option<DebugServerHandle>,
    ) {
        let error = error_sender.clone();
        let senders = Senders {
            event_sender,
            error_sender,
            debug_handle,
        };
        let factory = processor::BlockProcessorFactory {
            senders,
            parameters: None,
        };
        self.disconnect();
        match &self.input {
            Input::DeviceInput(device) => {
                let active = ActiveDevice::new(factory, error.clone());
                install(&device.session, active, error);
            }
            Input::FileInput(wavfile) => {
                let active = ActiveWavFile::new(&wavfile.spec, factory, error.clone());
                install(&wavfile.session, active, error);
            }
        }
    }

    pub fn disconnect(&self) {
        // drop to disconnect
        match &self.input {
            Input::DeviceInput(device) => {
                let old = device.session.active.lock().unwrap().take();
                drop(old);
            }
            Input::FileInput(device) => {
                let old = device.session.active.lock().unwrap().take();
                drop(old);
            }
        }
    }

    pub fn stream_done(&self) -> bool {
        match &self.input {
            Input::DeviceInput(d) => d
                .session
                .active
                .lock()
                .unwrap()
                .as_ref()
                .is_none_or(|a| a.is_finished()),
            Input::FileInput(d) => d
                .session
                .active
                .lock()
                .unwrap()
                .as_ref()
                .is_none_or(|a| a.is_finished()),
        }
    }
}
