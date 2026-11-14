defmodule IoLog.Event do
  @moduledoc """
  A single body input/output event in the append-only ledger.

  Events are immutable: once recorded they are never updated or deleted.
  Corrections (in later milestones) should be recorded as new events.
  """

  use Ecto.Schema
  import Ecto.Changeset

  # The single source of truth for allowed event kinds.
  # Extend this list to support new kinds of body I/O events.
  # "unmapped_scan" keeps the raw scan of an NFC tag that is not labelled yet:
  # every scan is a journal entry, its meaning can be added later.
  @kinds ~w(food_intake water_intake toilet_number_1 toilet_number_2 unmapped_scan)

  # Known sources. Not enforced yet, documented for future milestones.
  @sources ~w(manual_iex nfc ble_zone scale flow mock)

  @default_person "crew_1"
  @default_source "manual_iex"

  schema "events" do
    field :kind, :string
    field :person, :string, default: @default_person
    field :source, :string, default: @default_source
    field :zone, :string
    field :payload, :map, default: %{}
    field :occurred_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @type t :: %__MODULE__{}

  @doc "Returns the list of allowed event kinds (as strings)."
  @spec kinds() :: [String.t()]
  def kinds, do: @kinds

  @doc "Returns the list of known event sources (as strings)."
  @spec sources() :: [String.t()]
  def sources, do: @sources

  @doc """
  Builds a changeset for a new event. Only used for inserts:
  the ledger has no update path.
  """
  def changeset(event \\ %__MODULE__{}, attrs) do
    event
    |> cast(attrs, [:kind, :person, :source, :zone, :payload, :occurred_at])
    |> put_default_occurred_at()
    |> validate_required([:kind, :person, :source, :occurred_at])
    |> validate_inclusion(:kind, @kinds)
  end

  defp put_default_occurred_at(changeset) do
    case get_field(changeset, :occurred_at) do
      nil -> put_change(changeset, :occurred_at, DateTime.utc_now())
      _ -> changeset
    end
  end
end
