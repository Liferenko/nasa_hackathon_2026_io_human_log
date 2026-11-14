defmodule IoLog.Clock do
  @moduledoc """
  The ledger stores UTC. The demo shows and generates times in one local
  offset, set with `config :io_log, :utc_offset_minutes, 360` (Bishkek,
  UTC+6). Default: 0.
  """

  @doc "Configured offset from UTC in minutes."
  @spec offset_minutes() :: integer()
  def offset_minutes, do: Application.get_env(:io_log, :utc_offset_minutes, 0)

  @doc "Shifts a UTC `DateTime` to local wall-clock time (still tagged UTC)."
  @spec to_local(DateTime.t()) :: DateTime.t()
  def to_local(%DateTime{} = dt), do: DateTime.add(dt, offset_minutes() * 60, :second)

  @doc "Turns a local wall-clock date and time into a UTC `DateTime`."
  @spec from_local(Date.t(), Time.t()) :: DateTime.t()
  def from_local(date, time) do
    date
    |> DateTime.new!(time, "Etc/UTC")
    |> DateTime.add(-offset_minutes() * 60, :second)
  end

  @doc "Local calendar date of a UTC `DateTime`."
  @spec local_date(DateTime.t()) :: Date.t()
  def local_date(dt), do: dt |> to_local() |> DateTime.to_date()
end
