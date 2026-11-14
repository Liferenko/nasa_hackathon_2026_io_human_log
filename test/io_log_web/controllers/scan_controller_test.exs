defmodule IoLogWeb.ScanControllerTest do
  use IoLogWeb.ConnCase

  test "a registered tag scanned by a registered phone is logged", %{conn: conn} do
    conn =
      post(conn, "/api/scans", %{
        "tag_id" => "04:00:81:1C:05:00:01",
        "device" => "Mi flip3",
        "scanned_at" => "2026-11-14T08:21:28.359Z"
      })

    assert %{"status" => "logged", "kind" => "toilet_number_2", "person" => "crew_2"} =
             json_response(conn, 201)

    assert [event] = IoLog.list_events()
    assert event.source == "nfc"
    assert event.zone == "toilet"
    assert event.occurred_at == ~U[2026-11-14 08:21:28.359000Z]
    assert event.payload["tag_uid"] == "04:00:81:1c:05:00:01"
  end

  test "an unknown phone is logged under its device name", %{conn: conn} do
    conn =
      post(conn, "/api/scans", %{"tag_id" => "04:00:7d:1e:05:00:01", "device" => "lab tablet"})

    assert %{"person" => "lab tablet", "kind" => "water_intake"} = json_response(conn, 201)
  end

  test "an unregistered tag is reported, not logged", %{conn: conn} do
    conn = post(conn, "/api/scans", %{"tag_id" => "04:ff:ff", "device" => "Mi flip3"})
    assert %{"status" => "unregistered_tag", "tag_id" => "04:ff:ff"} = json_response(conn, 202)
    assert IoLog.list_events() == []
  end

  test "tag_id is required", %{conn: conn} do
    conn = post(conn, "/api/scans", %{"device" => "Mi flip3"})
    assert json_response(conn, 400)
  end
end
