use tokio::{
	runtime::Runtime,
	sync::mpsc,
	task::JoinHandle,
	time::{interval, Duration},
};
use zeromq::{PubSocket, Socket, SocketSend};

#[derive(Clone)]
pub struct DebugHandle {
	server: std::sync::Arc<DebugServer>,
}

impl DebugHandle {
	pub fn new() -> Self {
		Self {
			server: std::sync::Arc::new(DebugServer::open()),
		}
	}

	/// Stream data to the ZMQ server (non-blocking, drops if the network lags).
	pub fn stream_data(&self, data: &[u8]) {
		self.server.stream_data(data);
	}
}

const ZMQ_PORT: u16 = 9000;

struct DebugServer {
	#[allow(dead_code)] // kept to hold the Tokio runtime alive
	rt: tokio::runtime::Runtime,
	tx: mpsc::Sender<Vec<u8>>,
	_handle: JoinHandle<()>,
}

impl DebugServer {
	/// Opens the ZMQ debug server bound to 0.0.0.0:9000
	pub fn open() -> Self {
		log::trace!("new runtime");
		let rt = Runtime::new().expect("Failed to create Tokio runtime");
		log::trace!("new runtime ok");

		// Bounded channel to prevent memory leaks if network stalls.
		// Drops extra frames if the network client falls behind the audio source.
		let (tx, mut rx) = mpsc::channel::<Vec<u8>>(100);

		let handle = rt.spawn(async move {
			let bind_addr = format!("tcp://0.0.0.0:{ZMQ_PORT}");
			let mut socket = PubSocket::new();

			if let Err(e) = socket.bind(&bind_addr).await {
				log::error!("[ZMQ] Bind error on {bind_addr}: {e}");
				return;
			}
			log::info!("[ZMQ] Server bound successfully to {bind_addr}");

			let mut i = 1;
			let mut ticker = interval(Duration::from_millis(500));
			ticker.tick().await; // consume the first immediate tick
			loop {
				tokio::select! {
					data = rx.recv() => {
						match data {
							Some(data) => {
								eprintln!("[DBG stream] {}", data.len());
								if let Err(e) = socket.send(data.into()).await {
									log::error!("[ZMQ] Send failed: {e}");
								}
							}
							None => {
								log::warn!("[ZMQ] rx channel closed! ZMQ loop exiting.");
								break;
							}
						}
					}
					_ = ticker.tick() => {
						let msg = format!("hello [{}]", i);
						eprintln!("[DBG ticker] {msg}");
						if let Err(e) = socket.send(msg.into()).await {
							eprintln!("[DBG] send hello failed: {e}");
						}
						i += 1;
					}
				}
			}
		});
		Self { rt, tx, _handle: handle }
	}

	/// Stream data into the ZMQ server (non-blocking).
	pub fn stream_data(&self, data: &[u8]) {
		let _ = self.tx.try_send(data.to_vec());
	}
}
