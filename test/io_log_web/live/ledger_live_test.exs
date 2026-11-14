defmodule IoLogWeb.LedgerLiveTest do
  use IoLogWeb.ConnCase

  test "GET /nasa renders NASA legacy data with no input fields", %{conn: conn} do
    IoLog.Mock.generate(days: 2)

    html = conn |> get("/nasa") |> html_response(200)

    assert html =~ "NASA legacy data"
    assert html =~ "Alex Poe"
    assert html =~ "renal stone risk"
    refute html =~ "<input"
    refute html =~ "<textarea"
  end

  test "the legacy page ignores real device data", %{conn: conn} do
    {:ok, _} = IoLog.record(:water_intake, person: "someone_real", source: "nfc")

    html = conn |> get("/nasa") |> html_response(200)
    refute html =~ "someone_real"
  end
end
