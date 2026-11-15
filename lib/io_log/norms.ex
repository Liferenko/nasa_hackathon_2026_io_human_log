defmodule IoLog.Norms do
  @moduledoc """
  Reference values used by the mock generator and the assessment.

  Sources (NASA):
    * Drinking water baseline 2.79 kg per crew member per day
      (Life Support Baseline Values and Assumptions Document, BVAD;
      ICES-2022-388).
    * Urine output of at least 2 L/day keeps stone-forming salts in
      solution (NASA JSC, renal stone risk; NTRS 20000020539; HRP Evidence
      "Risk of Renal Stone Formation").
    * On average about 6 urinations per day and stool of 150 g per
      defecation (NASA-STD-3001 Body Waste Management technical brief).
  """

  @doc "Planned drinking water per day, ml (BVAD baseline 2.79 kg)."
  def planned_water_ml, do: 2_800

  @doc """
  Water intake below this share of the planned value counts as "almost no
  drinking" for the unexplained-fluid-source check (scenario 9).
  """
  def very_low_water_share, do: 0.2

  @doc "Minimum daily urine output, ml (NASA renal stone risk)."
  def min_urine_ml, do: 2_000

  @doc "Average number of urinations per day (NASA-STD-3001)."
  def urinations_per_day, do: 6

  @doc "Average stool mass per defecation, g (NASA-STD-3001)."
  def stool_mass_g, do: 150

  @doc """
  Debounce window, seconds: a repeat tap of the same tag by the same person
  within this window is a duplicate, not a new event. Short values suit the
  live demo (food 10 s, toilet 30 s). Water has none: each tap is one sip,
  and sips can come less than 2 s apart.
  """
  def debounce_s("food_intake"), do: 10
  def debounce_s("toilet_number_1"), do: 30
  def debounce_s("toilet_number_2"), do: 30
  def debounce_s("zone_enter"), do: 10
  def debounce_s(_), do: nil

  @doc """
  Presence in a zone (a "zone_enter" tap) is trusted for this long, seconds.
  """
  def presence_s, do: 30 * 60

  @doc """
  Swallow check for a food or water tap: at least `min_swallows/0` swallows
  between 2 minutes before and `swallow_window_s/0` seconds after the tap.
  Short values suit the live demo.
  """
  def swallow_window_s, do: 180
  def min_swallows, do: 3

  @doc """
  Swallowing without a logged intake: at least this many swallows within
  2 minutes and no food or water tap 10 minutes before or 3 minutes after.
  Single swallows (saliva, roughly once a minute) do not count.
  """
  def swallow_burst, do: 5

  @doc "Zones where each kind of event is expected."
  def expected_zone("food_intake"), do: "galley"
  def expected_zone("water_intake"), do: nil
  def expected_zone("toilet_number_1"), do: "toilet"
  def expected_zone("toilet_number_2"), do: "toilet"
  def expected_zone(_), do: nil
end
