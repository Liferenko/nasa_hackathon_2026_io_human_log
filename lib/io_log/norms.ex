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

  @doc "Minimum daily urine output, ml (NASA renal stone risk)."
  def min_urine_ml, do: 2_000

  @doc "Average number of urinations per day (NASA-STD-3001)."
  def urinations_per_day, do: 6

  @doc "Average stool mass per defecation, g (NASA-STD-3001)."
  def stool_mass_g, do: 150

  @doc "Zones where each kind of event is expected."
  def expected_zone("food_intake"), do: "galley"
  def expected_zone("water_intake"), do: nil
  def expected_zone("toilet_number_1"), do: "toilet"
  def expected_zone("toilet_number_2"), do: "toilet"
  def expected_zone(_), do: nil
end
