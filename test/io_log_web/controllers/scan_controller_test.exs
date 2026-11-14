defmodule IoLogWeb.ScanControllerTest do
  use IoLogWeb.ConnCase

  # Work on a temp registry so tests never depend on priv/nfc_registry.json
  setup do
    path = Path.join(System.tmp_dir!(), "nfc_registry_#{System.unique_integer([:positive])}.json")

    File.write!(path, ~S"""
    {
      "uids": {"04:00:81:1c:05:00:01": "toilet-2", "04:00:7d:1e:05:00:01": "water"},
      "devices": {"Mi flip3": "crew_2"},
      "people": {"crew_2": "Jane (engineer)"}
    }
    """)

    Application.put_env(:io_log, :nfc_registry_path, path)

    on_exit(fn ->
      Application.delete_env(:io_log, :nfc_registry_path)
      File.rm(path)
    end)

    :ok
  end

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

  test "an unregistered tag is still a journal entry (unmapped_scan)", %{conn: conn} do
    conn = post(conn, "/api/scans", %{"tag_id" => "04:FF:FF", "device" => "Mi flip3"})
    assert %{"status" => "unregistered_tag", "tag_id" => "04:ff:ff"} = json_response(conn, 202)

    assert [event] = IoLog.list_events()
    assert event.kind == "unmapped_scan"
    assert event.person == "crew_2"
    assert event.payload["tag_uid"] == "04:ff:ff"
  end

  test "tag_id is required", %{conn: conn} do
    conn = post(conn, "/api/scans", %{"device" => "Mi flip3"})
    assert json_response(conn, 400)
    assert IoLog.list_events() == []
  end

  test "the live dashboard shows real scans with people names, not mock data", %{conn: conn} do
    post(conn, "/api/scans", %{"tag_id" => "04:00:81:1c:05:00:01", "device" => "Mi flip3"})
    IoLog.Mock.generate(days: 1)

    html = conn |> get("/") |> html_response(200)
    assert html =~ "Jane (engineer)"
    assert html =~ "NASA legacy data"
    refute html =~ "Alex Poe"
    refute html =~ "<input"

    person_html = conn |> get("/p/crew_2") |> html_response(200)
    assert person_html =~ "Jane (engineer)"
    assert person_html =~ "Stool"
  end
end
