defmodule IoLog.Assessment do
  @moduledoc """
  Turns the raw ledger into what the crew can act on: per-person totals
  for the last 24 hours, alerts, action cards and a status for every
  event (confirmed / conflict / unusual).

  The assessment never changes events: it only reads them.
  """

  alias IoLog.{Crew, Event, Norms}

  @window_s 24 * 60 * 60

  @doc """
  Summary for one person over the 24 hours before `now`.
  `events` is that person's events (any order).
  """
  @spec summary(String.t(), [Event.t()], DateTime.t()) :: map()
  def summary(person, events, now) do
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
      transit_h: transit_hours(events)
    }

    %{
      person: person,
      name: Crew.name(person),
      totals: totals,
      alerts: alerts(totals, events, now),
      event_count: length(recent)
    }
  end

  @doc "Status of a single event, judged by kind and zone."
  @spec status(Event.t()) :: :confirmed | :conflict | :unusual
  def status(%Event{kind: kind, zone: zone}) do
    expected = Norms.expected_zone(kind)

    cond do
      is_nil(expected) or is_nil(zone) or zone == expected -> :confirmed
      kind in ["toilet_number_1", "toilet_number_2"] -> :conflict
      true -> :unusual
    end
  end

  # -- alerts and action cards -------------------------------------------

  defp alerts(totals, events, now) do
    [
      urine_alert(totals),
      water_alert(totals),
      stool_alert(totals),
      unusual_place_alert(events, now),
      conflict_alert(events, now)
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

  defp unusual_place_alert(events, now) do
    count =
      events
      |> Enum.filter(&(within?(&1, now, 2 * @window_s) and status(&1) == :unusual))
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

  defp conflict_alert(events, now) do
    count =
      events
      |> Enum.filter(&(within?(&1, now, 3 * @window_s) and status(&1) == :conflict))
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
    |> Enum.map(&(payload(&1, key) || 0))
    |> Enum.sum()
  end

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
