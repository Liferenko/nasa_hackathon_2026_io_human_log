#!/usr/bin/env python3
"""Minimal NFC scan collector. Standard library only.

GET  /            -> serves index.html (the Web NFC page)
POST /api/scans   -> body {"tag_id", "device", "scanned_at"}; appended to scans.jsonl
GET  /api/scans   -> last 100 scans as JSON

Run:  python3 server.py [port]
Web NFC requires HTTPS, so expose it over the tailnet:
      tailscale serve --bg 8000
"""
import json
import sys
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

BASE = Path(__file__).resolve().parent
DATA_FILE = BASE / "scans.jsonl"
INDEX_FILE = BASE / "index.html"


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body, content_type="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            self._send(200, INDEX_FILE.read_bytes(), "text/html; charset=utf-8")
        elif self.path == "/api/scans":
            lines = DATA_FILE.read_text().splitlines() if DATA_FILE.exists() else []
            self._send(200, [json.loads(l) for l in lines[-100:]])
        else:
            self._send(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/api/scans":
            return self._send(404, {"error": "not found"})
        try:
            length = int(self.headers.get("Content-Length", 0))
            payload = json.loads(self.rfile.read(length))
            tag_id = str(payload["tag_id"]).strip()
            if not tag_id:
                raise ValueError("empty tag_id")
        except Exception as e:
            return self._send(400, {"error": str(e)})

        record = {
            "tag_id": tag_id,
            "device": str(payload.get("device", "unknown")),
            "scanned_at": payload.get("scanned_at"),          # phone clock
            "received_at": datetime.now(timezone.utc).isoformat(),  # server clock
        }
        with DATA_FILE.open("a") as f:
            f.write(json.dumps(record) + "\n")
        print(f"[scan] {record['device']}: {tag_id}", flush=True)
        self._send(201, record)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    print(f"Listening on http://0.0.0.0:{port}")
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
