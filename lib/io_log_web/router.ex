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

    # The I/O screen. Read-only: there is no input field anywhere.
    live "/", LedgerLive, :index

    # Phone pairing: open once on a phone to make it a crew member's device.
    get "/pair/:person", TagController, :pair

    # NFC tags carry an NDEF URL like http://<host>:4000/t/toilet-2
    get "/t/:tag", TagController, :tap
  end

  scope "/api", IoLogWeb do
    pipe_through :api

    get "/health", HealthController, :index

    # NFC scans forwarded by nfc_logger/server.py
    post "/scans", ScanController, :create

    # Label a sticker: bind a tag UID to a tag type and an item (food package...)
    get "/tags", RegistryController, :index
    post "/tags", RegistryController, :create
  end
end
