defmodule IoLog.StoreAndForwardTest do
  use IoLogWeb.ConnCase

  setup do
    path = Path.join(System.tmp_dir!(), "nfc_registry_#{System.unique_integer([:positive])}.json")

    File.write!(path, ~S"""
    {"uids": {"04:00:7d:1e:05:00:01": "water"}, "devices": {"Mi flip3": "crew_2"}}
    """)

    Application.put_env(:io_log, :nfc_registry_path, path)

    on_exit(fn ->
      Application.delete_env(:io_log, :nfc_registry_path)
      File.rm(path)
    end)

    :ok
  end

  test "a reading resent with the same event_uid is stored once", %{conn: conn} do
    body = %{
      "kind" => "swallow",
      "device" => "Mi flip3",
      "detected_at" => "2026-11-15T09:00:00Z",
      "event_uid" => "uid-1"
    }

    first = conn |> post("/api/sensors", body) |> json_response(201)
    again = build_conn() |> post("/api/sensors", body) |> json_response(201)

    assert first["id"] == again["id"]
    assert [event] = IoLog.list_events()
    assert event.payload["event_uid"] == "uid-1"
  end

  test "a resent NFC scan is stored once", %{conn: conn} do
    body = %{"tag_id" => "04:00:7d:1e:05:00:01", "device" => "Mi flip3", "event_uid" => "uid-2"}

    conn |> post("/api/scans", body) |> json_response(201)
    build_conn() |> post("/api/scans", body) |> json_response(201)

    assert [%{kind: "water_intake"}] = IoLog.list_events()
  end

  test "readings without event_uid are never merged" do
    IoLog.record(:swallow, person: "crew_1")
    IoLog.record(:swallow, person: "crew_1")
    assert length(IoLog.list_events()) == 2
  end

  test "an event synced late keeps its original time and is marked on the board", %{conn: conn} do
    detected = DateTime.add(DateTime.utc_now(), -300, :second) |> DateTime.to_iso8601()

    conn
    |> post("/api/sensors", %{"kind" => "swallow", "device" => "Mi flip3", "detected_at" => detected, "event_uid" => "uid-3"})
    |> json_response(201)

    [event] = IoLog.list_events()
    assert IoLogWeb.Format.sync_note(event) == "stored on device, synced 5 min later"

    html = build_conn() |> get("/p/crew_2") |> html_response(200)
    assert html =~ "stored on device, synced 5 min later"
  end
end
