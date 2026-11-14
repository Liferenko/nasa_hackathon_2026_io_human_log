# NFC Tag Logger (prototype)

Reads the UID of passive NFC tags (NTAG21x stickers) with an Android phone via
Web NFC and posts it to a tiny Python server.

## Files

- `server.py` - stdlib-only HTTP server: serves the page, stores scans in `scans.jsonl`
- `index.html` - Web NFC page (Chrome on Android, HTTPS only)

## Run

Web NFC requires HTTPS, so the server is exposed over the tailnet with
`tailscale serve` (real TLS certificate on `*.ts.net`).

One-time setup in the Tailscale admin console (DNS tab): enable **MagicDNS**
and **HTTPS Certificates**. Install Tailscale on the phones and join the same tailnet.

```sh
python3 server.py              # listens on :8765
tailscale serve --bg 8765      # HTTPS -> https://<machine>.<tailnet>.ts.net
```

Open the printed `https://<machine>.<tailnet>.ts.net` URL in Chrome on the phone,
set a device name, tap "Start scanning" and hold a tag to the phone.

Notes:
- Plain `http://100.x.y.z:8765` will NOT work: Web NFC needs a secure context.
- Public access without Tailscale on the client: `tailscale funnel --bg 8765`.
- Stop serving: `tailscale serve reset`.
- On Xiaomi (MIUI/HyperOS) disable battery optimization for Tailscale and allow autostart.

## API

- `POST /api/scans` - `{"tag_id", "device", "scanned_at"}` -> appended to `scans.jsonl`
- `GET /api/scans` - last 100 scans
