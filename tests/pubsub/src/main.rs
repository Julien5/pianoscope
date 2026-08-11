use std::time::Duration;

use tokio::time::sleep;
use zeromq::{PubSocket, Socket, SocketSend};

#[tokio::main]
async fn main() {
    let mut socket = PubSocket::new();
    socket
        .bind("tcp://0.0.0.0:9000")
        .await
        .expect("failed to bind tcp://0.0.0.0:9000");

    println!("publishing on tcp://0.0.0.0:9000");

    let mut i = 1;
    loop {
        let msg = format!("hello [{}]", i);
        println!("sent: {}", msg);
        socket
            .send(msg.into())
            .await
            .expect("failed to publish message");
        i += 1;
        sleep(Duration::from_millis(500)).await;
    }
}