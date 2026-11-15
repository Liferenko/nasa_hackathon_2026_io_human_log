defmodule IoLog do
  @moduledoc """
  BodyLogs I/O Ledger: an append-only log of human body input/output
  events (food, water, toilet) for astronauts.

  This is the public API. The ledger is immutable by design, so there
  are no update or delete functions.

  ## Examples

      IoLog.record(:food_intake)
      IoLog.record(:toilet_number_1, person: "crew_2", payload: %{volume_ml: 320})
      IoLog.list_events(person: "crew_2")
  """

  import Ecto.Query, warn: false

  alias IoLog.{Event, Repo}

  @pubsub IoLog.PubSub
  @topic "events"

  @doc "PubSub topic on which `{:event_recorded, %IoLog.Event{}}` is broadcast."
  def topic, do: @topic

  @doc """
  Subscribes the calling process to new events.
  Messages arrive as `{:event_recorded, %IoLog.Event{}}`.
  """
  def subscribe, do: Phoenix.PubSub.subscribe(@pubsub, @topic)

  @doc """
  Records a new event of `kind` (atom or string).

  ## Options

    * `:person` - who the event belongs to (default `"crew_1"`)
    * `:source` - where the event came from (default `"manual_iex"`;
      later: `"nfc"`, `"ble_zone"`, `"scale"`, `"flow"`, `"mock"`)
    * `:zone` - optional location/zone label
    * `:payload` - free-form map stored as JSON (default `%{}`)
    * `:occurred_at` - `DateTime` of the event (default: now, UTC)

  Store-and-forward: a device that lost its link keeps readings and sends
  them again later. If the payload carries an `"event_uid"` that is
  already in the ledger, the existing event is returned and nothing is
  inserted or broadcast, so a retry never doubles an event.

  Returns `{:ok, %IoLog.Event{}}` or `{:error, %Ecto.Changeset{}}`.
  """
  @spec record(atom() | String.t(), keyword()) ::
          {:ok, Event.t()} | {:error, Ecto.Changeset.t()}
  def record(kind, opts \\ []) when is_atom(kind) or is_binary(kind) do
    attrs =
      opts
      |> Keyword.take([:person, :source, :zone, :payload, :occurred_at])
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()
      |> Map.put(:kind, to_string(kind))

    case find_by_uid(event_uid(attrs)) do
      %Event{} = existing ->
        {:ok, existing}

      nil ->
        attrs
        |> Event.changeset()
        |> Repo.insert()
        |> broadcast()
    end
  end

  @doc "The event recorded with this device-side `event_uid`, or nil."
  @spec find_by_uid(String.t() | nil) :: Event.t() | nil
  def find_by_uid(uid) when is_binary(uid) and uid != "" do
    Event
    |> where([e], fragment("json_extract(?, '$.event_uid') = ?", e.payload, ^uid))
    |> limit(1)
    |> Repo.one()
  end

  def find_by_uid(_), do: nil

  defp event_uid(%{payload: payload}) when is_map(payload),
    do: Map.get(payload, "event_uid") || Map.get(payload, :event_uid)

  defp event_uid(_), do: nil

  @doc """
  Lists events, newest first.

  ## Options

    * `:person` - only return events for this person
    * `:source` - only events from this source (e.g. `"mock"`)
    * `:exclude_source` - skip events from this source (e.g. `"mock"`)
    * `:limit` - maximum number of events to return
  """
  @spec list_events(keyword()) :: [Event.t()]
  def list_events(opts \\ []) do
    Event
    |> filter_person(opts[:person])
    |> filter_source(opts[:source])
    |> exclude_source(opts[:exclude_source])
    |> limit_query(opts[:limit])
    |> order_by([e], desc: e.occurred_at, desc: e.id)
    |> Repo.all()
  end

  @doc "Returns the total number of recorded events."
  @spec count_events() :: non_neg_integer()
  def count_events, do: Repo.aggregate(Event, :count)

  defp filter_person(query, nil), do: query
  defp filter_person(query, person), do: where(query, [e], e.person == ^to_string(person))

  defp filter_source(query, nil), do: query
  defp filter_source(query, source), do: where(query, [e], e.source == ^source)

  defp exclude_source(query, nil), do: query
  defp exclude_source(query, source), do: where(query, [e], e.source != ^source)

  defp limit_query(query, nil), do: query
  defp limit_query(query, limit) when is_integer(limit) and limit > 0, do: limit(query, ^limit)

  defp broadcast({:ok, event} = result) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:event_recorded, event})
    result
  end

  defp broadcast(error), do: error
end
