defmodule IoLogWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :io_log

  # The session will be stored in the cookie and signed.
  @session_options [
    store: :cookie,
    key: "_io_log_key",
    signing_salt: "io_log_signing",
    same_site: "Lax",
    # Keep the phone pairing (person identity) for 30 days.
    max_age: 30 * 24 * 60 * 60
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  # No asset pipeline: serve the prebuilt Phoenix and LiveView clients
  # straight from the dependencies.
  plug Plug.Static, at: "/vendor", from: {:phoenix, "priv/static"}, only: ~w(phoenix.min.js)

  plug Plug.Static,
    at: "/vendor",
    from: {:phoenix_live_view, "priv/static"},
    only: ~w(phoenix_live_view.min.js)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :io_log
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug IoLogWeb.Router
end
