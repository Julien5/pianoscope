import argparse

import zmq


def main():
    parser = argparse.ArgumentParser(description="Minimal ZeroMQ SUB client")
    parser.add_argument("--endpoint", default="tcp://127.0.0.1:9000")
    parser.add_argument("-n", "--count", type=int, default=5)
    args = parser.parse_args()

    ctx = zmq.Context()
    sock = ctx.socket(zmq.SUB)
    sock.connect(args.endpoint)
    sock.setsockopt(zmq.SUBSCRIBE, b"")

    print(f"connected to {args.endpoint}")
    for _ in range(args.count):
        print(sock.recv_string())


if __name__ == "__main__":
    main()