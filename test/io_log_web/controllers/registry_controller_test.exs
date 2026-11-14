defmodule IoLogWeb.RegistryControllerTest do
  use IoLogWeb.ConnCase

  # Work on a temp copy so tests never touch priv/nfc_registry.json
  setup do
    path = Path.join(System.tmp_dir!(), "nfc_registry_#{System.unique_integer([:positive])}.json")
    File.write!(path, ~s({"uids": {"04:00:81:1c:05:00:01": "toilet-2"}, "devices": {"Mi flip3": "crew_2"}}))
    Application.put_env(:io_log, :nfc_registry_path, path)

    on_exit(fn ->
      Application.delete_env(:io_log, :nfc_registry_path)
      File.rm(path)
    end)

    {:ok, path: path}
  end

  test "lists tag types", %{conn: conn} do
    assert %{"tags" => tags} = json_response(get(conn, "/api/tags"), 200)
    assert "food" in tags
  end

  test "registers a food package and later scans carry the item", %{conn: conn, path: path} do
    conn1 =
      post(conn, "/api/tags", %{
        "tag_id" => "04:00:A1:2B:05:00:01",
        "tag" => "food",
        "item" => "Baby puree #1",
        "amount" => 90,
        "unit" => "g"
      })

    assert %{"status" => "registered", "tag_id" => "04:00:a1:2b:05:00:01", "item" => "Baby puree #1"} =
             json_response(conn1, 201)

    # existing plain entries survive the rewrite
    assert %{"uids" => %{"04:00:81:1c:05:00:01" => "toilet-2"}} = path |> File.read!() |> Jason.decode!()

    conn2 =
      post(build_conn(), "/api/scans", %{"tag_id" => "04:00:a1:2b:05:00:01", "device" => "Mi flip3"})

    assert %{"status" => "logged", "kind" => "food_intake", "item" => "Baby puree #1"} =
             json_response(conn2, 201)

    assert [event] = IoLog.list_events()
    assert event.payload["item"] == "Baby puree #1"
    assert event.payload["amount"] == 90
    assert event.payload["unit"] == "g"
    assert event.payload["tag"] == "food"
  end

  test "rejects an unknown tag type", %{conn: conn} do
    conn = post(conn, "/api/tags", %{"tag_id" => "04:00:a1", "tag" => "rocket-fuel"})
    assert %{"error" => "unknown tag type" <> _} = json_response(conn, 422)
  end

  test "tag_id is required", %{conn: conn} do
    assert json_response(post(conn, "/api/tags", %{"tag" => "food"}), 400)
  end
end
