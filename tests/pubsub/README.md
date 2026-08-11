## zeromq rust/python

A minimal ZeroMQ PUB/SUB demo: a Rust publisher + a Python subscriber.

The server (publisher) emits `hello [1]`, `hello [2]`, ... on a TCP socket at
port 9000. The client (subscriber) connects and prints the messages it
receives.

### Run

Build/run the server (pure-Rust `zeromq` crate):

```
source /home/julien/projects/config/profile/profile.rust.sh
cargo run
```

In another terminal, run the client (pyzmq):

```
python3 client.py                 # prints 5 messages
python3 client.py -n 3            # prints 3 messages
```

Note on PUB/SUB: pub sockets drop messages sent before the subscriber has
connected and subscribed ("slow joiner"), so the client only receives messages
published after it is connected.