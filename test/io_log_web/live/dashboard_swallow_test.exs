defmodule IoLogWeb.DashboardSwallowTest do
  use IoLogWeb.ConnCase

  alias IoLogWeb.LedgerComponents

  @t0 ~U[2026-11-14 10:00:00.000000Z]

  defp swallow(seconds, person \\ "crew_1") do
    {:ok, e} =
      IoLog.record(:swallow,
        person: person,
        source: "phone_accel",
        occurred_at: DateTime.add(@t0, seconds, :second)
      )

    e
  end

  test "swallows less than 2 minutes apart collapse into one growing row per person" do
    for s <- [0, 20, 50], do: swallow(s)
    swallow(400)
    swallow(10, "crew_2")

    {:ok, food} = IoLog.record(:food_intake, person: "crew_1", source: "nfc", zone: "galley", occurred_at: @t0)

    rows = LedgerComponents.journal_rows(IoLog.list_events(), 50)

    assert [late, burst, other, food_row] = rows
    assert late.kind == "swallowing" and late.payload["count"] == 1
    assert burst.kind == "swallowing" and burst.payload["count"] == 3
    assert burst.occurred_at == DateTime.add(@t0, 50, :second)
    assert other.person == "crew_2" and other.payload["count"] == 1
    assert food_row.id == food.id
  end

  test "the main board shows swallowing rows and the card shows the swallow count", %{conn: conn} do
    now = DateTime.utc_now()

    for s <- [30, 20, 10] do
      IoLog.record(:swallow,
        person: "crew_1",
        source: "phone_accel",
        occurred_at: DateTime.add(now, -s, :second)
      )
    end

    html = conn |> get("/") |> html_response(200)
    assert html =~ "Swallowing"
    assert html =~ "3 swallows"
    assert html =~ "Swallows (throat sensor)"
  end
end
