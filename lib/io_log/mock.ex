defmodule IoLog.Mock do
  @moduledoc """
  Generates NASA-based mock I/O data for the demo crew (phase 2 of the
  demo, until real sensors are connected).

  Every generated event has `source: "mock"`, so mock data is clearly
  labelled and can be cleared without touching real events.

  Built-in story (matches `features/io_ledger.feature`):
    * crew_1 John Doe and crew_2 Jane Roe: healthy baseline
    * crew_3 Alex Poe: drinks too little -> urine below 2 L/day
      (renal stone risk) and harder stool
    * crew_4 Sam Moe: eats lunch at the workstation, and one toilet
      event arrives while his device is in the lab (location conflict)
    * crew_5 Kai Zoe: drinks only ~14% of the planned water, yet urine
      output stays stable at ~2.1 L/day (unexplained fluid source)

  Usage:

      IoLog.Mock.reload!()          # clear old mock data, generate 4 days
      IoLog.Mock.generate(days: 2)  # add more without clearing
  """

  import Ecto.Query, warn: false

  alias IoLog.{Clock, Crew, Event, Norms, Repo}

  @menu [
    "Beef stew",
    "Chicken teriyaki",
    "Mac and cheese",
    "Tortilla with tuna",
    "Scrambled eggs",
    "Oatmeal with raisins",
    "Shrimp cocktail",
    "Rice with vegetables"
  ]

  @doc "Deletes mock events only (source \"mock\"). Real events are never touched."
  @spec clear!() :: non_neg_integer()
  def clear! do
    {count, _} = Repo.delete_all(from(e in Event, where: e.source == "mock"))
    broadcast_reset()
    count
  end

  @doc "Clears old mock data and generates a fresh set."
  @spec reload!(keyword()) :: non_neg_integer()
  def reload!(opts \\ []) do
    clear!()
    generate(opts)
  end

  @doc """
  Generates mock events for every crew member.

  Options: `:days` (default 4), `:now` (default `DateTime.utc_now/0`),
  `:seed` (default 2026, so the demo is repeatable).
  Returns the number of inserted events.
  """
  @spec generate(keyword()) :: non_neg_integer()
  def generate(opts \\ []) do
    days = Keyword.get(opts, :days, 4)
    now = Keyword.get(opts, :now, DateTime.utc_now()) |> DateTime.truncate(:microsecond)
    :rand.seed(:exsss, {Keyword.get(opts, :seed, 2026), 7, 11})

    first_day = now |> Clock.local_date() |> Date.add(-(days - 1))

    rows =
      for person <- Crew.ids(),
          offset <- 0..(days - 1),
          day = Date.add(first_day, offset),
          event <- day_events(person, day, offset),
          DateTime.compare(event.occurred_at, now) != :gt do
        Map.merge(event, %{person: person, source: "mock", inserted_at: now})
      end

    {count, _} = Repo.insert_all(Event, rows, log: false)
    broadcast_reset()
    count
  end

  # -- one day for one person -------------------------------------------

  defp day_events(person, day, offset) do
    meals(person, day, offset) ++
      drinks(person, day) ++ urinations(person, day, offset) ++ stool(person, day)
  end

  defp meals(person, day, offset) do
    [
      {7, 30, 350..450, false},
      {12, 30, 450..600, true},
      {18, 30, 450..600, false}
    ]
    |> Enum.map(fn {h, m, mass_range, marker?} ->
      zone =
        if person == "crew_4" and marker? and offset > 0, do: "workstation", else: "galley"

      %{
        kind: "food_intake",
        zone: zone,
        occurred_at: at(day, h, m, 30),
        payload: %{
          "item" => Enum.random(@menu),
          "mass_g" => Enum.random(mass_range),
          # Lunch is the marker meal used to estimate gut transit time.
          "marker_meal" => marker?,
          "tag" => "food-pack"
        }
      }
    end)
  end

  defp drinks(person, day) do
    {count, volume_range} =
      case person do
        # Alex Poe under-drinks: about 1.0-1.3 L/day.
        "crew_3" -> {5, 180..260}
        # Kai Zoe: about 0.4 L/day, 14% of the planned 2.8 L.
        "crew_5" -> {2, 190..205}
        _ -> {9, 280..340}
      end

    for i <- 0..(count - 1) do
      minute = 7 * 60 + div(i * 15 * 60, count) + Enum.random(0..40)

      %{
        kind: "water_intake",
        zone: Enum.random(["galley", "galley", "workstation"]),
        occurred_at: at(day, div(minute, 60), rem(minute, 60), 0),
        payload: %{"volume_ml" => Enum.random(volume_range), "tag" => "cup-" <> person}
      }
    end
  end

  defp urinations(person, day, offset) do
    daily_ml =
      case person do
        "crew_3" -> Enum.random(1_150..1_450)
        # Suspiciously stable output despite almost no drinking.
        "crew_5" -> Enum.random(2_080..2_140)
        _ -> Enum.random(2_100..2_500)
      end

    voids = Norms.urinations_per_day()

    for i <- 0..(voids - 1) do
      minute = 6 * 60 + 40 + div(i * 16 * 60, voids) + Enum.random(0..30)
      volume = div(daily_ml, voids) + void_jitter(person)

      # Scenario 7: one of Sam Moe's toilet events arrives while his
      # personal device places him in the lab.
      zone = if person == "crew_4" and offset == 1 and i == 3, do: "lab", else: "toilet"

      %{
        kind: "toilet_number_1",
        zone: zone,
        occurred_at: at(day, div(minute, 60), rem(minute, 60), 0),
        payload: %{
          "volume_ml" => volume,
          "flow_ml_s" => Float.round(volume / Enum.random(18..32), 1),
          "color" => urine_color(person)
        }
      }
    end
  end

  defp stool(person, day) do
    bristol = if person == "crew_3", do: Enum.random([1, 2]), else: Enum.random([3, 4, 4, 5])

    [
      %{
        kind: "toilet_number_2",
        zone: "toilet",
        occurred_at: at(day, 8, 40, 60),
        payload: %{
          "mass_g" => Norms.stool_mass_g() + Enum.random(-30..30),
          "bristol_type" => bristol
        }
      }
    ]
  end

  defp void_jitter("crew_5"), do: Enum.random(-5..5)
  defp void_jitter(_), do: Enum.random(-40..40)

  defp urine_color("crew_3"), do: "dark yellow"
  defp urine_color(_), do: Enum.random(["pale yellow", "pale yellow", "straw"])

  defp at(day, hour, minute, jitter_min) do
    day
    |> Clock.from_local(Time.new!(min(hour, 23), minute, 0))
    |> DateTime.add(Enum.random(0..max(jitter_min, 0)) * 60, :second)
    |> DateTime.add(Enum.random(0..59), :second)
    |> DateTime.truncate(:microsecond)
    |> Map.put(:microsecond, {0, 6})
  end

  defp broadcast_reset do
    Phoenix.PubSub.broadcast(IoLog.PubSub, IoLog.topic(), :ledger_reset)
  end
end
