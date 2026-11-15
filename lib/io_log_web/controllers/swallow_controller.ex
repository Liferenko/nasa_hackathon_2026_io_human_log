defmodule IoLogWeb.SwallowController do
  @moduledoc """
  `GET /swallow` - turns a phone into a swallow sensor.

  The phone sits on the throat (a neck strap or a band), screen out. When a
  person swallows, the larynx moves up and down; the accelerometer sees a
  short burst (swallowing accelerometry). The page detects each burst in the
  browser and sends one `swallow` event to `POST /api/sensors`.

  Needs HTTPS for motion sensors (e.g. `tailscale serve`). Nothing is typed:
  the only choices are the device name (once) and the sensitivity.

  While the page is open it also listens for NFC tags (Web NFC, Chrome on
  Android): tapping a labelled food package to the phone sends the scan to
  `POST /api/scans`, so food intake is logged without leaving this page.
  """

  use IoLogWeb, :controller

  alias IoLog.NfcRegistry

  def show(conn, _params) do
    devices = NfcRegistry.devices() |> Map.keys() |> Enum.sort()
    html(conn, String.replace(page(), "__DEVICES__", Jason.encode!(devices)))
  end

  defp page do
    ~S"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Swallow sensor</title>
      <style>
        body { margin: 0; padding: 16px; background: #0b0f1a; color: #e6e9f2;
               font: 15px/1.4 -apple-system, system-ui, sans-serif; }
        h1 { font-size: 20px; margin: 0 0 4px; }
        .sub { color: #8a93a8; font-size: 13px; margin-bottom: 14px; }
        select, button { font-size: 16px; padding: 10px 12px; border-radius: 10px;
                         border: 1px solid #2a3245; background: #151b2b; color: #e6e9f2; }
        button.primary { background: #1d4a3a; border-color: #2f7a5f; width: 100%; margin-top: 10px; }
        .row { display: flex; gap: 8px; align-items: center; margin: 10px 0; }
        .big { font-size: 64px; font-weight: 700; text-align: center; margin: 8px 0 0; }
        .label { text-align: center; color: #8a93a8; }
        canvas { width: 100%; height: 140px; background: #121828; border-radius: 10px; margin-top: 12px; }
        #status, #nfc { margin-top: 10px; font-size: 13px; color: #8a93a8; min-height: 18px; }
        .ok { color: #4ade80; } .bad { color: #f87171; }
        input[type=range] { flex: 1; }
      </style>
    </head>
    <body>
      <h1>Swallow sensor</h1>
      <div class="sub">Phone on the throat, below the chin. Each swallow is logged automatically.</div>

      <div class="row">
        <select id="device"></select>
      </div>
      <div class="row">
        <span>Sensitivity</span>
        <input id="k" type="range" min="2" max="10" step="0.5" value="5">
        <span id="kv">5</span>
      </div>
      <button id="start" class="primary">Start (keep still 2 s to calibrate)</button>

      <div class="big" id="count">0</div>
      <div class="label">swallows logged</div>
      <canvas id="plot" width="600" height="140"></canvas>
      <div id="status">Not started.</div>
      <div id="nfc">NFC: off</div>
      <button id="nfcBtn" style="display:none;width:100%;margin-top:8px">Enable NFC</button>

      <script>
        const DEVICES = __DEVICES__;
        const MIN_ABS = 0.08;       // m/s², floor for the threshold
        const MIN_DUR = 200;        // ms, shorter bursts are taps or noise
        const MAX_DUR = 1800;       // ms, longer bursts are body movement
        const QUIET = 150;          // ms below threshold ends a burst
        const REFRACTORY = 800;     // ms between two swallows
        const CALIBRATE = 2000;     // ms of stillness at start

        const $ = (id) => document.getElementById(id);
        const sel = $("device");
        for (const d of DEVICES) sel.add(new Option(d, d));
        sel.value = localStorage.getItem("swallow_device") || DEVICES[0] || "";
        sel.onchange = () => localStorage.setItem("swallow_device", sel.value);
        $("k").oninput = () => { $("kv").textContent = $("k").value; };

        let running = false, count = 0, calib = [], calibUntil = 0;
        let mean = 0, variance = 0.0004, smooth = 0, gravity = null;
        let inBurst = false, burstStart = 0, burstPeak = 0, belowSince = null, lastEnd = 0;
        const trace = [];

        function threshold() {
          return Math.max(MIN_ABS, mean + Number($("k").value) * Math.sqrt(variance));
        }

        function linear(e) {
          const a = e.acceleration;
          if (a && a.x !== null) return [a.x, a.y, a.z];
          const g = e.accelerationIncludingGravity;
          if (!g || g.x === null) return null;
          const raw = [g.x, g.y, g.z];
          gravity = gravity ? gravity.map((v, i) => 0.9 * v + 0.1 * raw[i]) : raw;
          return raw.map((v, i) => v - gravity[i]);
        }

        function onMotion(e) {
          if (!running) return;
          const v = linear(e);
          if (!v) return;
          const m = Math.hypot(v[0], v[1], v[2]);
          smooth = 0.6 * smooth + 0.4 * m;
          const t = performance.now();

          if (t < calibUntil) { calib.push(smooth); return; }
          if (calib.length) {
            mean = calib.reduce((s, x) => s + x, 0) / calib.length;
            variance = calib.reduce((s, x) => s + (x - mean) ** 2, 0) / calib.length;
            calib = [];
            setStatus("Calibrated. Swallow to test.", "ok");
          }

          const thr = threshold();
          trace.push([t, smooth, thr]);
          while (trace.length && t - trace[0][0] > 6000) trace.shift();

          if (!inBurst) {
            if (smooth > thr && t - lastEnd > REFRACTORY) {
              inBurst = true; burstStart = t; burstPeak = smooth; belowSince = null;
            } else {
              mean = 0.995 * mean + 0.005 * smooth;
              variance = 0.995 * variance + 0.005 * (smooth - mean) ** 2;
            }
            return;
          }

          burstPeak = Math.max(burstPeak, smooth);
          if (t - burstStart > MAX_DUR + 500) { inBurst = false; lastEnd = t; return; }
          if (smooth >= thr) { belowSince = null; return; }
          if (belowSince === null) { belowSince = t; return; }
          if (t - belowSince < QUIET) return;

          const duration = Math.round(belowSince - burstStart);
          inBurst = false; lastEnd = t;
          if (duration >= MIN_DUR && duration <= MAX_DUR) report(burstStart, burstPeak, duration, thr);
        }

        async function report(start, peak, duration, thr) {
          const detectedAt = new Date(Date.now() - (performance.now() - start)).toISOString();
          count += 1;
          $("count").textContent = count;
          try {
            const res = await fetch("/api/sensors", {
              method: "POST",
              headers: { "content-type": "application/json" },
              body: JSON.stringify({
                kind: "swallow", device: sel.value, source: "phone_accel", detected_at: detectedAt,
                payload: { peak: +peak.toFixed(3), duration_ms: duration, threshold: +thr.toFixed(3) }
              })
            });
            setStatus(res.ok ? "Logged at " + new Date().toLocaleTimeString() : "Server said " + res.status, res.ok ? "ok" : "bad");
          } catch (err) {
            setStatus("Not sent: " + err.message, "bad");
          }
        }

        function setStatus(text, cls) { const s = $("status"); s.textContent = text; s.className = cls || ""; }

        function draw() {
          const c = $("plot"), ctx = c.getContext("2d");
          ctx.clearRect(0, 0, c.width, c.height);
          if (trace.length > 1) {
            const t0 = trace[trace.length - 1][0] - 6000;
            const top = Math.max(0.3, ...trace.map((p) => p[1]), ...trace.map((p) => p[2])) * 1.2;
            const x = (t) => (t - t0) / 6000 * c.width, y = (v) => c.height - v / top * c.height;
            for (const [idx, color] of [[2, "#f59e0b"], [1, "#4ade80"]]) {
              ctx.strokeStyle = color; ctx.lineWidth = 2; ctx.beginPath();
              trace.forEach((p, i) => i ? ctx.lineTo(x(p[0]), y(p[idx])) : ctx.moveTo(x(p[0]), y(p[idx])));
              ctx.stroke();
            }
          }
          requestAnimationFrame(draw);
        }

        // --- NFC: food packages are tapped while the swallow sensor runs ---
        let nfcOn = false, lastTag = null, lastTagAt = 0;

        function setNfc(text, cls) { const n = $("nfc"); n.textContent = "NFC: " + text; n.className = cls || ""; }

        async function startNfc() {
          if (nfcOn) return;
          if (!("NDEFReader" in window)) { setNfc("not available (needs Chrome on Android)"); return; }
          try {
            const reader = new NDEFReader();
            await reader.scan();
            nfcOn = true;
            setNfc("listening, tap a food package", "ok");
            reader.addEventListener("reading", ({ serialNumber }) => onTag(serialNumber || "no-serial"));
            reader.addEventListener("readingerror", () => setNfc("tag not readable", "bad"));
          } catch (err) {
            const hint = err.name === "NotAllowedError"
              ? " Allow NFC for this site (lock icon > Permissions), then tap Enable NFC." : "";
            setNfc("error: " + err.message + hint, "bad");
            $("nfcBtn").style.display = "block";
            return;
          }
          $("nfcBtn").style.display = "none";
        }

        $("nfcBtn").onclick = startNfc;

        async function onTag(tagId) {
          const now = Date.now();
          if (tagId === lastTag && now - lastTagAt < 2000) return;
          lastTag = tagId; lastTagAt = now;
          if (navigator.vibrate) navigator.vibrate(80);
          try {
            const res = await fetch("/api/scans", {
              method: "POST",
              headers: { "content-type": "application/json" },
              body: JSON.stringify({ tag_id: tagId, device: sel.value, scanned_at: new Date(now).toISOString() })
            });
            const body = await res.json().catch(() => ({}));
            const time = new Date(now).toLocaleTimeString();
            if (res.status === 201) setNfc(time + " logged " + (body.item || body.tag || body.kind), "ok");
            else if (res.status === 202) setNfc(time + " unregistered tag " + tagId, "bad");
            else setNfc("server said " + res.status, "bad");
          } catch (err) {
            setNfc("not sent: " + err.message, "bad");
          }
        }

        $("start").onclick = async () => {
          if (running) { running = false; $("start").textContent = "Start"; setStatus("Paused."); return; }
          if (typeof DeviceMotionEvent !== "undefined" && DeviceMotionEvent.requestPermission) {
            const p = await DeviceMotionEvent.requestPermission();
            if (p !== "granted") { setStatus("Motion permission denied.", "bad"); return; }
          }
          if (!window.isSecureContext) setStatus("Needs HTTPS for motion sensors.", "bad");
          startNfc();
          try { await navigator.wakeLock?.request("screen"); } catch (_) {}
          running = true; calib = []; calibUntil = performance.now() + CALIBRATE;
          $("start").textContent = "Pause";
          setStatus("Calibrating: keep still...");
        };

        window.addEventListener("devicemotion", onMotion);
        requestAnimationFrame(draw);
      </script>
    </body>
    </html>
    """
  end
end
