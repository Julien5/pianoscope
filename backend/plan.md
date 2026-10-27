Let's craft final.

Right — `Consumer` is a better name. Reformulated:

```
Microphone
└─ input: Input
   ├─ Device  { device_index: Option<usize>, session: Session<ActiveDevice> }
   └─ WavFile { path, paced, looped,        session: Session<ActiveWavFile> }

Session<A> { active: Mutex<Option<A>> }          // restartable, &self
ActiveDevice  { stream: cpal::Stream,           consumer: Consumer }
ActiveWavFile { file_reader: JoinHandle<()>,    consumer: Consumer }

Consumer { stop: Arc<AtomicBool>, worker: Option<JoinHandle<()>> }   // exactly one thread
```

`Consumer` is the consumer side of the ring buffer: it takes samples produced by the cpal callback / WAV reader, assembles windows, and runs the `BlockProcessor`. It owns **only one worker** — the consumer/processing thread. The WAV file-reader thread belongs to `ActiveWavFile`, not to `Consumer`.

```rust
impl Consumer {
    fn spawn(
        factory: BlockProcessorFactory,
        sample_rate: u32,
    ) -> (Producer<f32>, Self) {
        let (producer, ring_consumer) = rtrb::RingBuffer::new(sample_rate as usize * 2);
        let stop = Arc::new(AtomicBool::new(false));
        let worker = spawn_consumer_thread(ring_consumer, factory, stop.clone(), sample_rate);
        (producer, Self { stop, worker: Some(worker) })
    }

    fn stop_token(&self) -> Arc<AtomicBool> { self.stop.clone() }

    fn is_finished(&self) -> bool {
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
```

The source-specific active states then own the producer side:

```rust
impl Device {
    fn build_active(&self, factory, error) -> Result<ActiveDevice, String> {
        let device = resolve_device(self.device_index)?;
        let config = device.default_input_config()?;
        let (producer, consumer) = Consumer::spawn(factory, config.sample_rate());
        let stream = build_device_stream(&device, &config, producer, error)?;
        Ok(ActiveDevice { stream, consumer })
    }
}

impl WavFile {
    fn build_active(&self, factory, error) -> Result<ActiveWavFile, String> {
        let sample_rate = read_wav_sample_rate(&self.path)?;
        let (producer, consumer) = Consumer::spawn(factory, sample_rate);
        let file_reader = spawn_wav_reader(
            &self, producer, consumer.stop_token(), sample_rate, error,
        );
        Ok(ActiveWavFile { file_reader, consumer })
    }
}
```

Teardown stays correct because `Active*` is dropped outside the session lock:

- `ActiveDevice`: `stream` is declared before `consumer`, so dropping the stream releases the producer, then `Consumer::drop` signals and joins the consumer thread.
- `ActiveWavFile`: `Drop` signals `consumer.stop_token()` first (so a backpressured reader exits), joins `file_reader`, then `Consumer::drop` joins the consumer thread.
- `ActiveWavFile::is_finished` must check both: `file_reader.is_finished() && consumer.is_finished()`.
- `Device::is_finished` only checks `consumer.is_finished()`.

Two naming notes:

- `rtrb` already exports `Consumer` (hardware.rs:9). In `consumer.rs`, alias it (`use rtrb::Consumer as RingConsumer;`) or fully qualify `rtrb::Consumer<f32>`. Our type is `capture::Consumer`.
- `sample_rate` no longer needs to live in the struct: `Consumer::spawn` uses it for ring capacity/window length and passes it into the thread; `WavFile` keeps its local copy for the reader. Drop the old `Mutex<u32>` and `sample_rate()` accessor unless something outside needs it.

Suggested module layout:

```
microphone/
  mod.rs           // Microphone
  capture/
    mod.rs         // Input, Device, WavFile, Session, ActiveDevice, ActiveWavFile
    consumer.rs    // Consumer + spawn_consumer_thread
    device.rs      // cpal stream + downmix/push
    wav_file.rs    // WAV reading + reader thread
    session.rs     // Session<A>
  processor.rs     // BlockProcessor + BlockProcessorFactory
```

Open questions:

1. `Consumer::spawn(factory, sample_rate) -> (Producer<f32>, Consumer)`, or `Consumer::new(...)`/`Consumer::start(...)`? `spawn` reads best since it always starts the thread.
2. Should `Consumer` retain `sample_rate`/a `sample_rate()` accessor, or is it purely spawn-time configuration?
3. Keep `ActiveDevice`/`ActiveWavFile`, or name them `DeviceCapture`/`WavFileCapture` to echo `Consumer`'s vocabulary?


