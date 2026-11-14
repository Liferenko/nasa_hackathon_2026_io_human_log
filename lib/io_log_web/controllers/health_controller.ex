defmodule IoLogWeb.HealthController do
  use IoLogWeb, :controller

  def index(conn, _params) do
    json(conn, %{app: "io_log", events: IoLog.count_events()})
  end
end
