defmodule IoLogWeb.PersonLive do
  @moduledoc "One person's live I/O card and journal (real devices only)."

  use IoLogWeb, :live_view

  import IoLogWeb.LedgerComponents

  alias IoLog.{Assessment, NfcRegistry, Norms}

  @impl true
  def mount(%{"person" => person}, _session, socket) do
    if connected?(socket), do: IoLog.subscribe()
    {:ok, socket |> assign(person: person) |> load()}
  end

  @impl true
  def handle_info({:event_recorded, %{person: person}}, %{assigns: %{person: person}} = socket),
    do: {:noreply, load(socket)}

  def handle_info(:ledger_reset, socket), do: {:noreply, load(socket)}
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp load(%{assigns: %{person: person}} = socket) do
    now = DateTime.utc_now()
    events = IoLog.list_events(person: person, exclude_source: "mock", limit: 2_000)
    names = NfcRegistry.people()

    assign(socket,
      now: now,
      names: names,
      name: person_name(person, names),
      summary: Assessment.summary(person, events, now),
      journal: Enum.take(events, 100),
      planned_water: Norms.planned_water_ml(),
      min_urine: Norms.min_urine_ml()
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main>
      <div class="topbar">
        <div>
          <h1>{@name} <span class="live">LIVE</span></h1>
          <div class="sub">Personal logging journal. Real devices only.</div>
        </div>
        <a href="/" class="button">All people</a>
      </div>

      <div class="person-layout">
        <.person_card
          summary={@summary}
          name={@name}
          planned_water={@planned_water}
          min_urine={@min_urine}
        />
        <div>
          <.journal events={@journal} names={@names} now={@now} show_person={false} />
        </div>
      </div>
    </main>
    """
  end
end
