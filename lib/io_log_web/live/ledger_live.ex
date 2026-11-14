defmodule IoLogWeb.LedgerLive do
  @moduledoc """
  "NASA legacy data": the I/O screen on NASA-based mock data for the demo
  crew (source "mock" only). Per crew member intake vs outtake for the
  last 24 hours, alerts with action cards, and the mock journal.

  Read-only by design: there is no input field on this page.
  """

  use IoLogWeb, :live_view

  import IoLogWeb.LedgerComponents

  alias IoLog.{Assessment, Crew, Norms}

  @timeline_size 40

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: IoLog.subscribe()
    {:ok, load(socket)}
  end

  @impl true
  def handle_info({:event_recorded, %{source: "mock"}}, socket), do: {:noreply, load(socket)}
  def handle_info(:ledger_reset, socket), do: {:noreply, load(socket)}
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp load(socket) do
    now = DateTime.utc_now()
    events = IoLog.list_events(source: "mock", limit: 5_000)
    by_person = Enum.group_by(events, & &1.person)

    summaries =
      (Crew.ids() ++ Map.keys(by_person))
      |> Enum.uniq()
      |> Enum.map(&Assessment.summary(&1, Map.get(by_person, &1, []), now))

    assign(socket,
      now: now,
      summaries: summaries,
      timeline: Enum.take(events, @timeline_size),
      total: length(events),
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
          <h1>NASA legacy data</h1>
          <div class="sub">
            Demo crew on NASA-based mock data (BVAD, NASA-STD-3001, HRP renal stone risk). Last 24 hours, {@total} mock events.
          </div>
        </div>
        <a href="/" class="button">Live dashboard</a>
      </div>

      <h2>Crew, last 24 hours</h2>
      <div class="grid">
        <.person_card
          :for={s <- @summaries}
          summary={s}
          name={Crew.name(s.person)}
          planned_water={@planned_water}
          min_urine={@min_urine}
        />
      </div>

      <h2>Mock journal, newest first</h2>
      <.journal events={@timeline} now={@now} />
    </main>
    """
  end
end
