defmodule IoLogWeb.TagControllerTest do
  use IoLogWeb.ConnCase

  test "a paired phone tapping the toilet tag records toilet_number_2", %{conn: conn} do
    conn = get(conn, "/pair/crew_2")
    assert html_response(conn, 200) =~ "Jane Roe"

    conn = get(recycle(conn), "/t/toilet-2")
    assert html_response(conn, 200) =~ "Logged"

    assert [event] = IoLog.list_events()
    assert event.kind == "toilet_number_2"
    assert event.person == "crew_2"
    assert event.source == "nfc"
    assert event.zone == "toilet"
  end

  test "an unpaired phone is asked to pair first", %{conn: conn} do
    conn = get(conn, "/t/water")
    assert html_response(conn, 401) =~ "pair"
    assert IoLog.list_events() == []
  end

  test "an unknown tag is rejected", %{conn: conn} do
    conn = get(conn, "/t/nope?p=crew_1")
    assert html_response(conn, 404) =~ "Unknown tag"
  end
end
