import zmq

context = zmq.Context()
socket = context.socket(zmq.SUB)
socket.connect("tcp://127.0.0.1:9000")

# CRITICAL: Subscribe to ALL topics (empty string prefix)
socket.setsockopt(zmq.SUBSCRIBE, b"")

print("Connected to port 9000. Waiting for packets...")
while True:
    raw_bytes = socket.recv()
    l = len(raw_bytes);
    if l >= 15:
        print(f"Received {len(raw_bytes)} bytes! sum=", sum(raw_bytes))
    else:
        print(f"Received:",raw_bytes);
