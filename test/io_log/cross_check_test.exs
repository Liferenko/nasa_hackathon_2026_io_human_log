defmodule IoLog.CrossCheckTest do
  use IoLog.DataCase, async: false

  alias IoLog.Assessment

  @t0 ~U[2026-11-14 10:00:00.000000Z]

  defp at(seconds), do: DateTime.add(@t0, seconds, :second)

  defp rec(kind, seconds, opts) do
    {:ok, event} =
      IoLog.record(kind,
        person: "crew_1",
        source: Keyword.get(opts, :source, "nfc"),
        zone: Keyword.get(opts, :zone),
        occurred_at: at(seconds),
        payload: Keyword.get(opts, :payload, %{})
      )

    event
  end

  defp swallows(from, n), do: for(i <- 0..(n - 1), do: rec(:swallow, from + i * 5, source: "phone_accel"))

  describe "presence (zone_enter)" do
    test "food tapped after entering the galley is confirmed" do
      rec(:zone_enter, 0, zone: "galley")
      food = rec(:food_intake, 60, zone: "galley")
      events = IoLog.list_events()

      assert Assessment.status(food, Assessment.context(events)) == :confirmed
    end

    test "food tapped while the person is in the toilet zone is unusual" do
      rec(:zone_enter, 0, zone: "toilet")
      food = rec(:food_intake, 60, zone: "galley")
      ctx = IoLog.list_events() |> Assessment.context()

      assert Assessment.presence_zone(food, ctx) == "toilet"
      assert Assessment.status(food, ctx) == :unusual
    end

    test "toilet use while the person is in the galley is a conflict and raises an alert" do
      rec(:zone_enter, 0, zone: "galley")
      rec(:toilet_number_2, 60, zone: "toilet")
      events = IoLog.list_events()
      [stool] = Enum.filter(events, &(&1.kind == "toilet_number_2"))

      assert Assessment.status(stool, Assessment.context(events)) == :conflict
      summary = Assessment.summary("crew_1", events, at(120))
      assert Enum.any?(summary.alerts, &(&1.title =~ "location and sensor disagree"))
    end

    test "presence older than 30 minutes is not used" do
      rec(:zone_enter, 0, zone: "toilet")
      food = rec(:food_intake, 31 * 60, zone: "galley")
      ctx = IoLog.list_events() |> Assessment.context()

      assert Assessment.presence_zone(food, ctx) == nil
      assert Assessment.status(food, ctx) == :confirmed
    end
  end

  describe "swallow sensor" do
    test "a meal with swallowing shows the swallow count and no alert" do
      food = rec(:food_intake, 0, zone: "galley")
      swallows(10, 6)
      events = IoLog.list_events()

      assert Assessment.swallow_count(food, Assessment.context(events)) == 6
      summary = Assessment.summary("crew_1", events, at(600))
      assert summary.totals.swallows == 6
      refute Enum.any?(summary.alerts, &(&1.title =~ "swallow"))
    end

    test "food tapped but not swallowed raises an alert once the window has passed" do
      swallows(0, 2)
      rec(:food_intake, 3600, zone: "galley")
      events = IoLog.list_events()

      early = Assessment.summary("crew_1", events, at(3600 + 60))
      refute Enum.any?(early.alerts, &(&1.title =~ "without swallowing"))

      late = Assessment.summary("crew_1", events, at(3600 + 300))
      assert Enum.any?(late.alerts, &(&1.title =~ "without swallowing"))
    end

    test "no swallow sensor means no swallow judgement" do
      food = rec(:food_intake, 0, zone: "galley")
      events = IoLog.list_events()

      assert Assessment.swallow_count(food, Assessment.context(events)) == nil
      summary = Assessment.summary("crew_1", events, at(600))
      refute Enum.any?(summary.alerts, &(&1.title =~ "swallow"))
    end

    test "a swallowing burst without any intake tap is flagged as unlogged intake" do
      swallows(0, 6)
      events = IoLog.list_events()

      summary = Assessment.summary("crew_1", events, at(600))
      assert Enum.any?(summary.alerts, &(&1.title =~ "without a logged meal or drink"))
    end

    test "single saliva swallows are not a burst" do
      for i <- 0..5, do: rec(:swallow, i * 60, source: "phone_accel")
      summary = Assessment.summary("crew_1", IoLog.list_events(), at(600))
      refute Enum.any?(summary.alerts, &(&1.title =~ "without a logged meal"))
    end
  end
end
