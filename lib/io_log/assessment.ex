defmodule IoLog.Assessment do
  @moduledoc """
  Turns the raw ledger into what the crew can act on: per-person totals
  for the last 24 hours, alerts, action cards and a status for every
  event (confirmed / conflict / unusual / duplicate / unmapped).

  The assessment never changes events: it only reads them. A repeat tap is
  kept in the ledger and marked `duplicate`; it is left out of totals and
  alerts.

  Independent sources cross-check each other: a "zone_enter" tap says where
  the person really is, swallows from the throat sensor say whether a food
  or water tap was actually consumed.
  """

  alias IoLog.{Crew, Event, Norms}

  @window_s 24 * 60 * 60

  @doc """
  Summary for one person over the 24 hours before `now`.
  `events` is that person's events (any order).
  """
  @spec summary(String.t(), [Event.t()], DateTime.t()) :: map()
  def summary(person, events, now) do
    events = drop_duplicates(events)
    ctx = context(events)
    recent = Enum.filter(events, &within?(&1, now, @window_s))

    water_ml = sum(recent, "water_intake", "volume_ml")
    urine_ml = sum(recent, "toilet_number_1", "volume_ml")
    food_g = sum(recent, "food_intake", "mass_g")
    stools = Enum.filter(recent, &(&1.kind == "toilet_number_2"))

    totals = %{
      water_ml: water_ml,
      urine_ml: urine_ml,
      food_g: food_g,
      meals: count(recent, "food_intake"),
      drinks: count(recent, "water_intake"),
      voids: count(recent, "toilet_number_1"),
      stools: length(stools),
      last_bristol: last_value(stools, "bristol_type"),
      drinks_minus_urine_ml: water_ml - urine_ml,
      transit_h: transit_hours(events),
      swallows: count(recent, "swallow"),
      last_swallow_at:
        recent
        |> Enum.filter(&(&1.kind == "swallow"))
        |> Enum.max_by(& &1.occurred_at, DateTime, fn -> nil end)
        |> case do
          nil -> nil
          swallow -> swallow.occurred_at
        end
    }

    %{
      person: person,
      name: Crew.name(person),
      totals: totals,
      alerts: alerts(totals, events, now, ctx),
      event_count: length(recent)
    }
  end

  @doc """
  Ids of events that repeat an earlier tap: same person, same kind and same
  tag (or item) within `IoLog.Norms.debounce_s/1` seconds of the last
  counted event. Raw events stay in the ledger untouched.
  """
  @spec duplicate_ids([Event.t()]) :: MapSet.t()
  def duplicate_ids(events) do
    events
    |> Enum.filter(&Norms.debounce_s(&1.kind))
    |> Enum.group_by(&debounce_key/1)
    |> Enum.flat_map(fn {_key, group} -> repeats(group) end)
    |> MapSet.new()
  end

  @doc "Events without repeat taps (see `duplicate_ids/1`)."
  @spec drop_duplicates([Event.t()]) :: [Event.t()]
  def drop_duplicates(events) do
    dups = duplicate_ids(events)
    Enum.reject(events, &MapSet.member?(dups, &1.id))
  end

  defp debounce_key(%Event{} = e) do
    {e.person, e.kind, payload(e, "tag_uid") || payload(e, "item")}
  end

  # Walk one group oldest first; a tap within the window of the last
  # counted tap is a repeat. Ties on time are broken by id.
  defp repeats(group) do
    window = group |> hd() |> Map.fetch!(:kind) |> Norms.debounce_s()

    group
    |> Enum.sort_by(&{DateTime.to_unix(&1.occurred_at, :microsecond), &1.id})
    |> Enum.reduce({nil, []}, fn e, {last, dups} ->
      if last && DateTime.diff(e.occurred_at, last.occurred_at, :millisecond) < window * 1000 do
        {last, [e.id | dups]}
      else
        {e, dups}
      end
    end)
    |> elem(1)
  end

  @doc """
  Cross-source context for `status/2` and `swallow_count/2`, built once
  from a list of events (any people, any order).
  """
  @spec context([Event.t()]) :: map()
  def context(events) do
    %{
      duplicates: duplicate_ids(events),
      presence: events |> Enum.filter(&(&1.kind == "zone_enter")) |> Enum.group_by(& &1.person),
      swallows: events |> Enum.filter(&(&1.kind == "swallow")) |> Enum.group_by(& &1.person)
    }
  end

  @doc """
  Status of an event within its context (from `context/1`, or just a set of
  duplicate ids):

    * `:duplicate` - a repeat tap;
    * otherwise as `status/1`, but judged by where the person really was
      (the latest "zone_enter" within `IoLog.Norms.presence_s/0`) when
      that is known, instead of the zone of the tag.
  """
  @spec status(Event.t(), map() | MapSet.t()) :: atom()
  def status(event, %MapSet{} = duplicates),
    do: status(event, %{duplicates: duplicates, presence: %{}, swallows: %{}})

  def status(%Event{id: id} = event, ctx) do
    zone = presence_zone(event, ctx)

    cond do
      MapSet.member?(ctx.duplicates, id) -> :duplicate
      zone -> status(%{event | zone: zone})
      true -> status(event)
    end
  end

  @doc "Zone the person entered last before `event` (nil if unknown)."
  @spec presence_zone(Event.t(), map()) :: String.t() | nil
  def presence_zone(%Event{kind: kind, person: person, occurred_at: at}, ctx) do
    if Norms.expected_zone(kind) do
      ctx.presence
      |> Map.get(person, [])
      |> Enum.filter(fn p ->
        diff = DateTime.diff(at, p.occurred_at)
        diff >= 0 and diff <= Norms.presence_s()
      end)
      |> Enum.max_by(& &1.occurred_at, DateTime, fn -> nil end)
      |> case do
        nil -> nil
        enter -> enter.zone
      end
    end
  end

  @doc """
  Swallows of the same person from 2 minutes before a food or water tap to
  `IoLog.Norms.swallow_window_s/0` after it. `nil` for other events or when
  the person wears no swallow sensor (no swallows at all).
  """
  @spec swallow_count(Event.t(), map()) :: non_neg_integer() | nil
  def swallow_count(%Event{kind: kind, person: person, occurred_at: at}, ctx)
      when kind in ["food_intake", "water_intake"] do
    case Map.get(ctx.swallows, person, []) do
      [] ->
        nil

      swallows ->
        Enum.count(swallows, fn s ->
          diff = DateTime.diff(s.occurred_at, at)
          diff >= -120 and diff <= Norms.swallow_window_s()
        end)
    end
  end

  def swallow_count(_event, _ctx), do: nil

  @doc "Status of a single event, judged by kind and zone."
  @spec status(Event.t()) :: :confirmed | :conflict | :unusual | :unmapped
  def status(%Event{kind: "unmapped_scan"}), do: :unmapped

  def status(%Event{kind: kind, zone: zone}) do
    expected = Norms.expected_zone(kind)

    cond do
      is_nil(expected) or is_nil(zone) or zone == expected -> :confirmed
      kind in ["toilet_number_1", "toilet_number_2"] -> :conflict
      true -> :unusual
    end
  end

  # -- alerts and action cards -------------------------------------------

  defp alerts(totals, events, now, ctx) do
    [
      urine_alert(totals),
      water_alert(totals),
      stool_alert(totals),
      unusual_place_alert(events, now, ctx),
      conflict_alert(events, now, ctx),
      fluid_source_alert(events, now),
      not_swallowed_alert(events, now, ctx),
      unlogged_swallowing_alert(events, now)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp urine_alert(%{urine_ml: ml}) do
    if ml < Norms.min_urine_ml() do
      %{
        level: :alert,
        title: "Urine #{ml} ml in 24 h, below 2 L/day: renal stone risk",
        action: "Drink +600 ml spread over the next 6 hours",
        source: "NASA HRP: Risk of Renal Stone Formation"
      }
    end
  end

  defp water_alert(%{water_ml: ml}) do
    if ml < Norms.planned_water_ml() * 0.6 do
      %{
        level: :warning,
        title: "Drinks #{ml} ml in 24 h vs planned #{Norms.planned_water_ml()} ml",
        action: "Drink 500 ml in the next 2 hours",
        source: "NASA BVAD drinking water baseline"
      }
    end
  end

  defp stool_alert(%{last_bristol: type}) when type in [1, 2] do
    %{
      level: :warning,
      title: "Bristol type #{type}: hard stool, often linked to low fluid intake",
      action: "Increase fluids and fibre; recheck tomorrow",
      source: "Bristol Stool Form Scale"
    }
  end

  defp stool_alert(_), do: nil

  defp unusual_place_alert(events, now, ctx) do
    count =
      events
      |> Enum.filter(&(within?(&1, now, 2 * @window_s) and status(&1, ctx) == :unusual))
      |> length()

    cond do
      count >= 3 ->
        %{
          level: :alert,
          title: "#{count} meals outside the galley in 2 days: overload signal",
          action: "Check workload and protect meal breaks",
          source: "Scenario 8"
        }

      count > 0 ->
        %{
          level: :info,
          title: "#{count} meal(s) outside the galley in 2 days",
          action: "Watch the pattern",
          source: "Scenario 8"
        }

      true ->
        nil
    end
  end

  defp conflict_alert(events, now, ctx) do
    count =
      events
      |> Enum.filter(&(within?(&1, now, 3 * @window_s) and status(&1, ctx) == :conflict))
      |> length()

    if count > 0 do
      %{
        level: :warning,
        title: "#{count} event(s) where location and sensor disagree",
        action: "Read and validate (values are never edited)",
        source: "Scenario 7"
      }
    end
  end

  # Scenario 9: almost no drinking for 3 days in a row, yet urine output is
  # normal and stable. Where does the fluid come from? Logging gap,
  # unlogged drinking, sensor fault or a medical issue: needs a check.
  defp fluid_source_alert(events, now) do
    days =
      for back <- 0..2 do
        window_end = DateTime.add(now, -back * @window_s, :second)
        day = Enum.filter(events, &within?(&1, window_end, @window_s))
        {sum(day, "water_intake", "volume_ml"), sum(day, "toilet_number_1", "volume_ml")}
      end

    planned = Norms.planned_water_ml()
    waters = Enum.map(days, &elem(&1, 0))
    urines = Enum.map(days, &elem(&1, 1))
    mean_urine = Enum.sum(urines) / 3

    very_low_water? = Enum.all?(waters, &(&1 < planned * Norms.very_low_water_share()))

    stable_normal_urine? =
      mean_urine >= Norms.min_urine_ml() * 0.8 and
        (Enum.max(urines) - Enum.min(urines)) / mean_urine <= 0.1

    if very_low_water? and stable_normal_urine? do
      share = round(Enum.sum(waters) / 3 / planned * 100)

      %{
        level: :alert,
        title:
          "Water in ~#{share}% of planned for 3 days, yet urine stable at " <>
            "~#{Float.round(mean_urine / 1000, 1)} L/day: fluid source unexplained",
        action: "External check by the flight surgeon; verify sensors; extra monitoring",
        source: "Scenario 9"
      }
    end
  end

  # Food or water tapped, but the throat sensor saw (almost) no swallowing:
  # the package was taken, not consumed? Judged once the window has passed.
  defp not_swallowed_alert(events, now, ctx) do
    window = Norms.swallow_window_s()

    count =
      Enum.count(events, fn e ->
        n = swallow_count(e, ctx)

        e.kind in ["food_intake", "water_intake"] and within?(e, now, @window_s) and
          DateTime.diff(now, e.occurred_at) >= window and n != nil and
          n < Norms.min_swallows()
      end)

    if count > 0 do
      %{
        level: :warning,
        title: "#{count} food/water tap(s) without swallowing: taken, not consumed?",
        action: "Ask the crew member; check the throat sensor fit",
        source: "Swallow sensor x NFC"
      }
    end
  end

  # Bursts of swallowing with no food or water tap around them: eating or
  # drinking that was not logged (see scenario 9, unexplained fluid source).
  defp unlogged_swallowing_alert(events, now) do
    swallows =
      events
      |> Enum.filter(&(&1.kind == "swallow" and within?(&1, now, @window_s)))
      |> Enum.sort_by(&DateTime.to_unix(&1.occurred_at, :millisecond))

    intakes = Enum.filter(events, &(&1.kind in ["food_intake", "water_intake"]))
    count = count_unlogged_bursts(swallows, intakes, 0)

    if count > 0 do
      %{
        level: :warning,
        title: "#{count} swallowing burst(s) without a logged meal or drink: unlogged intake?",
        action: "Check for untagged food or water; extra monitoring",
        source: "Swallow sensor x NFC, scenario 9"
      }
    end
  end

  defp count_unlogged_bursts([], _intakes, acc), do: acc

  defp count_unlogged_bursts([first | tail] = swallows, intakes, acc) do
    {burst, rest} =
      Enum.split_with(swallows, &(DateTime.diff(&1.occurred_at, first.occurred_at) <= 120))

    logged? =
      Enum.any?(intakes, fn i ->
        diff = DateTime.diff(first.occurred_at, i.occurred_at)
        diff <= 600 and diff >= -180
      end)

    cond do
      length(burst) < Norms.swallow_burst() -> count_unlogged_bursts(tail, intakes, acc)
      logged? -> count_unlogged_bursts(rest, intakes, acc)
      true -> count_unlogged_bursts(rest, intakes, acc + 1)
    end
  end

  # -- helpers -----------------------------------------------------------

  # Gut transit time: latest stool vs the latest marker meal at least
  # 8 hours before it.
  defp transit_hours(events) do
    stool =
      events
      |> Enum.filter(&(&1.kind == "toilet_number_2"))
      |> Enum.max_by(& &1.occurred_at, DateTime, fn -> nil end)

    with %Event{occurred_at: stool_at} <- stool,
         %Event{occurred_at: meal_at} <- marker_meal_before(events, stool_at) do
      Float.round(DateTime.diff(stool_at, meal_at) / 3600, 1)
    else
      _ -> nil
    end
  end

  defp marker_meal_before(events, stool_at) do
    events
    |> Enum.filter(fn e ->
      e.kind == "food_intake" and payload(e, "marker_meal") == true and
        DateTime.diff(stool_at, e.occurred_at) >= 8 * 3600
    end)
    |> Enum.max_by(& &1.occurred_at, DateTime, fn -> nil end)
  end

  defp within?(%Event{occurred_at: at}, now, seconds) do
    diff = DateTime.diff(now, at)
    diff >= 0 and diff <= seconds
  end

  defp sum(events, kind, key) do
    events
    |> Enum.filter(&(&1.kind == kind))
    |> Enum.map(&(payload(&1, key) || labelled_amount(&1, key) || 0))
    |> Enum.sum()
  end

  # A tag labelled with an item ("amount" + "unit", see IoLog.NfcRegistry)
  # counts when its unit matches the measured key: g for mass, ml for volume.
  defp labelled_amount(event, key) do
    unit = if String.ends_with?(key, "_ml"), do: "ml", else: "g"

    with ^unit <- payload(event, "unit"),
         amount when is_number(amount) <- to_number(payload(event, "amount")) do
      amount
    else
      _ -> nil
    end
  end

  defp to_number(value) when is_number(value), do: value

  defp to_number(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _} -> number
      :error -> nil
    end
  end

  defp to_number(_), do: nil

  defp count(events, kind), do: Enum.count(events, &(&1.kind == kind))

  defp last_value(events, key) do
    case Enum.max_by(events, & &1.occurred_at, DateTime, fn -> nil end) do
      nil -> nil
      event -> payload(event, key)
    end
  end

  defp payload(%Event{payload: payload}, key) when is_map(payload) do
    Map.get(payload, key) || Map.get(payload, String.to_atom(key))
  end

  defp payload(_, _), do: nil
end
