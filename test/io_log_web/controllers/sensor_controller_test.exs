defmodule IoLogWeb.SensorControllerTest do
  use IoLogWeb.ConnCase

  setup do
    path = Path.join(System.tmp_dir!(), "nfc_registry_#{System.unique_integer([:positive])}.json")
    File.write!(path, ~S({"uids": {}, "devices": {"Mi flip3": "crew_2"}}))
    Application.put_env(:io_log, :nfc_registry_path, path)

    on_exit(fn ->
      Application.delete_env(:io_log, :nfc_registry_path)
      File.rm(path)
    end)

    :ok
  end

  test "a swallow from the phone is logged for the device's person", %{conn: conn} do
    conn =
      post(conn, "/api/sensors", %{
        "kind" => "swallow",
        "device" => "Mi flip3",
        "detected_at" => "2026-11-14T09:41:02.120Z",
        "payload" => %{"peak" => 0.42, "duration_ms" => 640}
      })

    assert %{"status" => "logged", "kind" => "swallow", "person" => "crew_2"} =
             json_response(conn, 201)

    assert [event] = IoLog.list_events()
    assert event.source == "phone_accel"
    assert event.payload["duration_ms"] == 640
    assert event.occurred_at == ~U[2026-11-14 09:41:02.120000Z]
  end

  test "unknown sensor kinds are rejected", %{conn: conn} do
    conn = post(conn, "/api/sensors", %{"kind" => "food_intake", "device" => "Mi flip3"})
    assert json_response(conn, 422)["error"] =~ "swallow"
    assert IoLog.list_events() == []
  end

  test "the swallow sensor page lists the registered devices", %{conn: conn} do
    body = conn |> get("/swallow") |> html_response(200)
    assert body =~ "Swallow sensor"
    assert body =~ ~s(["Mi flip3"])
  end
end
