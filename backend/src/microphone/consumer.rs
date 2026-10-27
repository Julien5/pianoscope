use std::{
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    thread::{self, JoinHandle},
    time::Duration,
};

use rtrb::{PopError, Producer};

use crate::microphone::processor::BlockProcessorParameters;

use super::processor::BlockProcessorFactory;

pub struct Consumer {
    stop: Arc<AtomicBool>,
    worker: Option<JoinHandle<()>>,
}

pub const WINDOW_SECONDS: f32 = 0.125;

impl Consumer {
    pub fn spawn(
        mut factory: BlockProcessorFactory,
        parameters: BlockProcessorParameters,
    ) -> Result<(Producer<f32>, Self), String> {
        assert!(
            parameters.sample_rate > 0,
            "sample rate must be greater than zero"
        );
        factory.parameters = Some(parameters.clone());
        let (producer, mut consumer) = rtrb::RingBuffer::new(parameters.sample_rate as usize * 2);
        let stop = Arc::new(AtomicBool::new(false));
        let copy = stop.clone();
        let worker = thread::Builder::new()
            .name("nano-mic-processing".into())
            .spawn(move || {
                let mut processor = factory.create();
                let mut buf: Vec<f32> = Vec::with_capacity(parameters.window_len);
                loop {
                    match consumer.pop() {
                        Ok(sample) => buf.push(sample),
                        Err(PopError::Empty) => {
                            if consumer.is_abandoned() || copy.load(Ordering::Relaxed) {
                                break;
                            }
                            thread::sleep(Duration::from_micros(200));
                        }
                    }
                    if buf.len() >= parameters.window_len {
                        processor.process(&buf);
                        buf.clear();
                    }
                }
                if !buf.is_empty() {
                    processor.process(&buf);
                }
            })
            .map_err(|error| format!("failed to spawn: {:?}", error))?;

        Ok((
            producer,
            Self {
                stop,
                worker: Some(worker),
            },
        ))
    }

    pub fn stop_token(&self) -> Arc<AtomicBool> {
        self.stop.clone()
    }

    pub fn is_finished(&self) -> bool {
        self.worker.as_ref().is_none_or(|w| w.is_finished())
    }
}

impl Drop for Consumer {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        if let Some(worker) = self.worker.take() {
            let _ = worker.join();
        }
    }
}
