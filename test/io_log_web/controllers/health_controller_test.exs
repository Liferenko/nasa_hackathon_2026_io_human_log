defmodule IoLogWeb.HealthControllerTest do
  use IoLogWeb.ConnCase

  test "GET /api/health returns app name and event count", %{conn: conn} do
    {:ok, _} = IoLog.record(:food_intake)

    conn = get(conn, "/api/health")
    assert json_response(conn, 200) == %{"app" => "io_log", "events" => 1}
  end
end
