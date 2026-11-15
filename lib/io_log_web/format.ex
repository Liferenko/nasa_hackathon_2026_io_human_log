defmodule IoLogWeb.Format do
  @moduledoc "Small display helpers shared by LiveViews and controllers."

  alias IoLog.{Clock, Crew, Event}

  @kind_labels %{
    "food_intake" => "Food",
    "water_intake" => "Water",
    "toilet_number_1" => "Urine",
    "toilet_number_2" => "Stool",
    "unmapped_scan" => "Unlabelled tag",
    "zone_enter" => "Entered zone",
    "swallow" => "Swallow",
    "swallowing" => "Swallowing"
  }

  @doc "Local wall-clock time, e.g. \"Sat 14:05\"."
  def local_time(%DateTime{} = dt) do
    local = Clock.to_local(dt)
    day = local |> DateTime.to_date() |> Date.day_of_week() |> day_name()
    "#{day} #{pad(local.hour)}:#{pad(local.minute)}"
  end

  def local_time(_), do: "-"

  @doc "Display label for an event kind."
  def kind_label(kind), do: Map.get(@kind_labels, kind, kind)

  @doc """
  Display name of a person: `"people"` in `priv/nfc_registry.json` first,
  then the demo crew names, then the id itself.
  """
  def person_name(person), do: person_name(person, IoLog.NfcRegistry.people())

  @doc "Same as `person_name/1` with an already loaded names map."
  def person_name(person, names), do: Map.get(names, person) || Crew.name(person)

  @doc "One-line summary of an event's measured values."
  def amount(%Event{kind: kind, payload: p}) do
    p = p || %{}

    case kind do
      "food_intake" ->
        join([
          get(p, "item"),
          unit(get(p, "mass_g"), "g") || unit(get(p, "amount"), get(p, "unit"))
        ])

      "water_intake" ->
        unit(get(p, "volume_ml"), "ml")

      "toilet_number_1" ->
        join([unit(get(p, "volume_ml"), "ml"), get(p, "color")])

      "toilet_number_2" ->
        join([unit(get(p, "mass_g"), "g"), bristol(get(p, "bristol_type"))])

      "unmapped_scan" ->
        join([get(p, "tag_uid"), get(p, "device")])

      "swallow" ->
        join([unit(get(p, "peak"), "m/s²"), unit(get(p, "duration_ms"), "ms")])

      "swallowing" ->
        swallowing(get(p, "count"), get(p, "from"), get(p, "to"))

      _ ->
        ""
    end
  end

  @doc """
  Swallow check shown next to a food or water tap, e.g. " · 5 swallows".
  Empty when the person wears no swallow sensor.
  """
  def swallow_note(nil), do: ""
  def swallow_note(1), do: " · 1 swallow"
  def swallow_note(n), do: " · #{n} swallows"

  @doc "Formats millilitres as litres with one decimal, e.g. \"2.4 L\"."
  def litres(ml) when is_number(ml), do: "#{Float.round(ml / 1000, 1)} L"
  def litres(_), do: "-"

  @doc "Clock time only, e.g. \"16:05\"."
  def clock(%DateTime{} = dt) do
    local = Clock.to_local(dt)
    "#{pad(local.hour)}:#{pad(local.minute)}"
  end

  def clock(_), do: "-"

  defp swallowing(1, _from, _to), do: "1 swallow"

  defp swallowing(count, from, to) do
    span = if clock(from) == clock(to), do: clock(to), else: "#{clock(from)}–#{clock(to)}"
    "#{count} swallows, #{span}"
  end

  defp bristol(nil), do: nil
  defp bristol(type), do: "Bristol #{type}"

  defp get(map, key), do: Map.get(map, key) || Map.get(map, String.to_atom(key))

  defp unit(nil, _), do: nil
  defp unit(value, nil), do: "#{value}"
  defp unit(value, unit), do: "#{value} #{unit}"

  defp join(parts), do: parts |> Enum.reject(&is_nil/1) |> Enum.join(", ")

  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")

  defp day_name(n), do: Enum.at(~w(Mon Tue Wed Thu Fri Sat Sun), n - 1)
end
