defmodule IoLog.DebounceTest do
  use IoLog.DataCase, async: false

  alias IoLog.Assessment

  @t0 ~U[2026-11-14 10:00:00.000000Z]

  defp scan(kind, seconds, opts \\ []) do
    {:ok, event} =
      IoLog.record(kind,
        person: Keyword.get(opts, :person, "crew_1"),
        source: "nfc",
        zone: Keyword.get(opts, :zone),
        occurred_at: DateTime.add(@t0, seconds, :second),
        payload: %{"tag_uid" => Keyword.get(opts, :uid, "04:aa"), "amount" => 90, "unit" => "g"}
      )

    event
  end

  test "a repeat food tap within 10 s is a duplicate, after 10 s it counts again" do
    first = scan(:food_intake, 0, zone: "galley")
    repeat = scan(:food_intake, 5, zone: "galley")
    again = scan(:food_intake, 12, zone: "galley")

    dups = Assessment.duplicate_ids([first, repeat, again])
    assert MapSet.to_list(dups) == [repeat.id]
    assert Assessment.status(repeat, dups) == :duplicate
    assert Assessment.status(first, dups) == :confirmed
  end

  test "toilet taps are debounced for 30 s" do
    a = scan(:toilet_number_2, 0, zone: "toilet")
    b = scan(:toilet_number_2, 25, zone: "toilet")
    c = scan(:toilet_number_2, 31, zone: "toilet")

    assert Assessment.duplicate_ids([a, b, c]) |> MapSet.to_list() == [b.id]
  end

  test "different people, tags or kinds are never duplicates of each other" do
    events = [
      scan(:food_intake, 0),
      scan(:food_intake, 1, person: "crew_2"),
      scan(:food_intake, 2, uid: "04:bb"),
      scan(:toilet_number_2, 3)
    ]

    assert Assessment.duplicate_ids(events) == MapSet.new()
  end

  test "duplicates stay in the ledger but are left out of the totals" do
    scan(:food_intake, 0, zone: "galley")
    scan(:food_intake, 3, zone: "galley")
    scan(:toilet_number_2, 60, zone: "toilet")
    scan(:toilet_number_2, 70, zone: "toilet")

    events = IoLog.list_events(person: "crew_1")
    assert length(events) == 4

    summary = Assessment.summary("crew_1", events, DateTime.add(@t0, 120, :second))
    assert summary.totals.meals == 1
    assert summary.totals.food_g == 90
    assert summary.totals.stools == 1
  end
end
