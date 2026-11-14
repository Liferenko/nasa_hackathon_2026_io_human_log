defmodule IoLogWeb.LedgerLiveTest do
  use IoLogWeb.ConnCase

  test "GET / renders the I/O screen with no input fields", %{conn: conn} do
    IoLog.Mock.generate(days: 2)

    html = conn |> get("/") |> html_response(200)

    assert html =~ "BodyLogs I/O Ledger"
    assert html =~ "Alex Poe"
    assert html =~ "renal stone risk"
    refute html =~ "<input"
    refute html =~ "<textarea"
  end
end
