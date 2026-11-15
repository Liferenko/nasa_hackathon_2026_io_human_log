defmodule IoLogWeb.Router do
  use IoLogWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {IoLogWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", IoLogWeb do
    pipe_through :browser

    # Live dashboard: real devices only. Read-only, no input fields.
    live "/", DashboardLive, :index
    live "/p/:person", PersonLive, :show

    # NASA legacy data: the demo crew on NASA-based mock data.
    live "/nasa", LedgerLive, :index

    # Phone pairing: open once on a phone to make it a crew member's device.
    get "/pair/:person", TagController, :pair

    # NFC tags carry an NDEF URL like http://<host>:4000/t/toilet-2
    get "/t/:tag", TagController, :tap

    # Swallow sensor: a phone on the throat, open this page on it (HTTPS).
    get "/swallow", SwallowController, :show
  end

  scope "/api", IoLogWeb do
    pipe_through :api

    get "/health", HealthController, :index

    # NFC scans forwarded by nfc_logger/server.py
    post "/scans", ScanController, :create

    # Label a sticker: bind a tag UID to a tag type and an item (food package...)
    get "/tags", RegistryController, :index
    post "/tags", RegistryController, :create

    # Sensor readings detected on a device (e.g. swallows from /swallow)
    post "/sensors", SensorController, :create
  end
end
