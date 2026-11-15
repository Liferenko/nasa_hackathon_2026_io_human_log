defmodule IoLogWeb.Layouts do
  @moduledoc """
  Root layout. No asset pipeline: styles are inline and the Phoenix and
  LiveView clients are served from the dependencies under /vendor.
  """

  use Phoenix.Component

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Phoenix.Controller.get_csrf_token()} />
        <title>BodyLogs I/O Ledger</title>
        <style phx-no-curly-interpolation>
          :root { --bg:#0b1020; --card:#141b2e; --line:#26304a; --text:#e7ecf5; --muted:#8c97b0;
                  --ok:#3ecf8e; --warn:#f5b748; --bad:#ff6b6b; --info:#6ea8ff; --in:#4fb3ff; --out:#c08cff; }
          * { box-sizing: border-box; }
          body { margin:0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                 background: var(--bg); color: var(--text); }
          main { max-width: 1200px; margin: 0 auto; padding: 20px; }
          h1 { margin: 0 0 4px; font-size: 22px; }
          h2 { font-size: 16px; margin: 24px 0 10px; color: var(--muted); font-weight: 600; }
          .sub { color: var(--muted); font-size: 13px; }
          .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 14px; }
          .card { background: var(--card); border: 1px solid var(--line); border-radius: 12px; padding: 14px; }
          .card h3 { margin: 0 0 8px; font-size: 16px; display:flex; justify-content:space-between; }
          .kv { display:grid; grid-template-columns: 1fr auto; gap: 4px 8px; font-size: 13px; }
          .kv span:nth-child(even) { text-align:right; font-variant-numeric: tabular-nums; }
          .bar { height: 10px; border-radius: 5px; background: var(--line); overflow: hidden; margin: 2px 0 8px; }
          .bar > div { height: 100%; }
          .alert { margin-top: 8px; padding: 8px 10px; border-radius: 8px; font-size: 12.5px; border-left: 4px solid; background: #0f1527; }
          .alert b { display:block; margin-bottom: 2px; }
          .alert .act { color: var(--text); }
          .alert .src { color: var(--muted); font-size: 11px; }
          .alert.alert-alert { border-color: var(--bad); }
          .alert.alert-warning { border-color: var(--warn); }
          .alert.alert-info { border-color: var(--info); }
          .ok { color: var(--ok); }
          table { width: 100%; border-collapse: collapse; font-size: 13px; }
          th, td { text-align: left; padding: 6px 8px; border-bottom: 1px solid var(--line); }
          th { color: var(--muted); font-weight: 600; }
          .badge { padding: 2px 8px; border-radius: 999px; font-size: 11px; font-weight: 600; }
          .badge-confirmed { background: #12382a; color: var(--ok); }
          .badge-conflict { background: #3d1a1d; color: var(--bad); }
          .badge-unusual { background: #3a2e12; color: var(--warn); }
          .src-tag { color: var(--muted); font-size: 11px; }
          .flash { background:#12382a; color: var(--ok); padding:8px 12px; border-radius:8px; margin-bottom:12px; }
          .big { font-size: 34px; margin: 18px 0; }
          a.plain { color: inherit; text-decoration: none; }
          a.plain:hover { text-decoration: underline; }
          .topbar { display:flex; justify-content:space-between; align-items:flex-start; gap: 16px; }
          .button { display:inline-block; padding: 9px 14px; border-radius: 9px; border: 1px solid var(--line);
                    background: var(--card); color: var(--text); text-decoration: none; font-size: 13px; white-space: nowrap; }
          .button:hover { border-color: var(--info); }
          .live { font-size: 11px; vertical-align: middle; padding: 2px 7px; border-radius: 999px;
                  background: #3d1a1d; color: var(--bad); margin-left: 6px; animation: pulse 2s infinite; }
          @keyframes pulse { 0%,100% { opacity: 1; } 50% { opacity: .45; } }
          tr.fresh td { animation: glow 3s ease-out; }
          @keyframes glow { from { background: #1d4a3a; } to { background: transparent; } }
          .badge-unmapped { background: #1d2a44; color: var(--info); }
          .badge-duplicate { background: #26292f; color: var(--muted); }
          .person-layout { display:grid; grid-template-columns: 300px 1fr; gap: 14px; margin-top: 16px; }
          @media (max-width: 800px) { .person-layout { grid-template-columns: 1fr; } }
        </style>
        <script src="/vendor/phoenix.min.js"></script>
        <script src="/vendor/phoenix_live_view.min.js"></script>
        <script phx-no-curly-interpolation>
          window.addEventListener("DOMContentLoaded", () => {
            if (!document.querySelector("[data-phx-main]")) return;
            const csrf = document.querySelector("meta[name='csrf-token']").getAttribute("content");
            const liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, { params: { _csrf_token: csrf } });
            liveSocket.connect();
            window.liveSocket = liveSocket;
          });
        </script>
      </head>
      <body>
        {@inner_content}
      </body>
    </html>
    """
  end
end
