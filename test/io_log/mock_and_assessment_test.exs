defmodule IoLog.MockAndAssessmentTest do
  use IoLog.DataCase, async: false

  alias IoLog.{Assessment, Mock}

  @now ~U[2026-11-14 18:00:00.000000Z]

  setup do
    count = Mock.generate(days: 4, now: @now)
    {:ok, count: count}
  end

  defp summary(person) do
    events = IoLog.list_events(person: person)
    Assessment.summary(person, events, @now)
  end

  test "generates mock events for 5 crew members, all labelled mock", %{count: count} do
    assert count > 100
    events = IoLog.list_events()
    assert Enum.all?(events, &(&1.source == "mock"))
    assert events |> Enum.map(& &1.person) |> Enum.uniq() |> length() == 5
    refute Enum.any?(events, &(DateTime.compare(&1.occurred_at, @now) == :gt))
  end

  test "healthy crew member has no renal alert" do
    s = summary("crew_1")
    assert s.totals.urine_ml >= 2_000
    refute Enum.any?(s.alerts, &(&1.title =~ "renal"))
  end

  test "Alex Poe gets a renal stone risk alert with an action card" do
    s = summary("crew_3")
    assert s.totals.urine_ml < 2_000
    assert alert = Enum.find(s.alerts, &(&1.title =~ "renal stone risk"))
    assert alert.action =~ "600 ml"
  end

  test "Sam Moe eats outside the galley and has a location conflict" do
    events = IoLog.list_events(person: "crew_4")
    assert Enum.any?(events, &(Assessment.status(&1) == :unusual))
    assert Enum.any?(events, &(Assessment.status(&1) == :conflict))
  end

  test "Kai Zoe: almost no water but stable urine raises an unexplained-fluid alert" do
    s = summary("crew_5")
    assert alert = Enum.find(s.alerts, &(&1.title =~ "fluid source unexplained"))
    assert alert.action =~ "flight surgeon"
  end

  test "healthy and under-drinking crew do not get the unexplained-fluid alert" do
    for person <- ["crew_1", "crew_3"] do
      refute Enum.any?(summary(person).alerts, &(&1.title =~ "fluid source unexplained"))
    end
  end

  test "gut transit time is estimated from the marker meal" do
    assert %{totals: %{transit_h: hours}} = summary("crew_1")
    assert is_float(hours) and hours > 8 and hours < 48
  end

  test "clear! removes mock events only" do
    {:ok, _} = IoLog.record(:water_intake, source: "nfc")
    Mock.clear!()
    assert [%{source: "nfc"}] = IoLog.list_events()
  end
end
