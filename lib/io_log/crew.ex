defmodule IoLog.Crew do
  @moduledoc """
  The demo crew. Ids are what the ledger stores; names are for display.
  Names match the Gherkin scenarios in `features/io_ledger.feature`.
  """

  @crew [
    {"crew_1", "John Doe"},
    {"crew_2", "Jane Roe"},
    {"crew_3", "Alex Poe"},
    {"crew_4", "Sam Moe"},
    {"crew_5", "Kai Zoe"}
  ]

  @doc "All crew ids in display order."
  @spec ids() :: [String.t()]
  def ids, do: Enum.map(@crew, &elem(&1, 0))

  @doc "Display name for a crew id (falls back to the id itself)."
  @spec name(String.t()) :: String.t()
  def name(id) do
    case List.keyfind(@crew, id, 0) do
      {_, name} -> name
      nil -> id
    end
  end

  @doc "True if the id belongs to the demo crew."
  @spec member?(String.t()) :: boolean()
  def member?(id), do: List.keymember?(@crew, id, 0)
end
