#!/usr/bin/env python3
"""Minimal NFC scan collector. Standard library only.

GET  /            -> serves index.html (the Web NFC page)
POST /api/scans   -> body {"tag_id", "device", "scanned_at"}; appended to scans.jsonl
                     and forwarded to the Phoenix ledger (IO_LOG_URL)
GET  /api/scans   -> last 100 scans as JSON
GET  /api/tags    -> tag types, proxied to the Phoenix ledger
POST /api/tags    -> body {"tag_id", "tag", "item", "amount", "unit"}: label a
                     sticker (e.g. a food package), proxied to the Phoenix ledger

Run:  python3 server.py [port]
Web NFC requires HTTPS, so expose it over the tailnet:
      tailscale serve --bg 8765
"""
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

BASE = Path(__file__).resolve().parent
DATA_FILE = BASE / "scans.jsonl"
INDEX_FILE = BASE / "index.html"

# Every scan is also forwarded to the Phoenix ledger (io_log). Set
# IO_LOG_URL="" to disable forwarding.
LEDGER_URL = os.environ.get("IO_LOG_URL", "http://127.0.0.1:4000/api/scans")
# Sticker labelling endpoint of the same Phoenix app.
TAGS_URL = os.environ.get("IO_LOG_TAGS_URL", "http://127.0.0.1:4000/api/tags")


def call_ledger(url, body=None):
    """GET (body=None) or POST JSON to the Phoenix app.
    Returns (http_status, json_body); 502 if the app is unreachable."""
    req = urllib.request.Request(
        url,
        data=None if body is None else json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
        method="GET" if body is None else "POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=3) as resp:
            return resp.status, json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as e:  # 4xx/5xx with a JSON error body
        try:
            return e.code, json.loads(e.read() or b"{}")
        except ValueError:
            return e.code, {"error": str(e)}
    except Exception as e:  # app down, timeout
        return 502, {"error": f"ledger unreachable: {e}"}


def forward_to_ledger(record):
    """POST the scan to the Phoenix ledger. Never raises: the local
    scans.jsonl stays the source of truth if the ledger is down."""
    if not LEDGER_URL:
        return {"status": "disabled"}
    try:
        req = urllib.request.Request(
            LEDGER_URL,
            data=json.dumps(record).encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=2) as resp:
            return json.loads(resp.read() or b"{}")
    except Exception as e:  # ledger down, timeout, bad response
        return {"status": "forward_failed", "error": str(e)}


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
        elif self.path == "/api/tags":
            self._send(*call_ledger(TAGS_URL))
        elif self.path == "/api/scans":
            lines = DATA_FILE.read_text().splitlines() if DATA_FILE.exists() else []
            self._send(200, [json.loads(l) for l in lines[-100:]])
        else:
            self._send(404, {"error": "not found"})

    def do_POST(self):
        if self.path == "/api/tags":
            return self._post_tag()
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
        ledger = forward_to_ledger(record)
        print(f"[scan] {record['device']}: {tag_id} -> ledger: {ledger.get('status')}", flush=True)
        self._send(201, {**record, "ledger": ledger})

    def _post_tag(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            payload = json.loads(self.rfile.read(length))
        except Exception as e:
            return self._send(400, {"error": str(e)})
        status, body = call_ledger(TAGS_URL, payload)
        print(f"[tag] {payload.get('tag_id')} -> {payload.get('tag')} "
              f"{payload.get('item', '')}: {status}", flush=True)
        self._send(status, body)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    print(f"Listening on http://0.0.0.0:{port}")
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
