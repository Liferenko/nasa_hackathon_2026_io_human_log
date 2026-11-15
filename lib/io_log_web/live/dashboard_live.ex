defmodule IoLogWeb.DashboardLive do
  @moduledoc """
  The main page: live data from real devices only (NFC scans from the
  phones; mock data is excluded). One card per person, newest scans on top.
  Every scan, labelled or not, is a journal entry.
  """

  use IoLogWeb, :live_view

  import IoLogWeb.LedgerComponents

  alias IoLog.{Assessment, NfcRegistry, Norms}

  @journal_size 50

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: IoLog.subscribe()
    {:ok, load(socket)}
  end

  @impl true
  def handle_info({:event_recorded, _event}, socket), do: {:noreply, load(socket)}
  def handle_info(:ledger_reset, socket), do: {:noreply, load(socket)}
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp load(socket) do
    now = DateTime.utc_now()
    events = IoLog.list_events(exclude_source: "mock", limit: 5_000)
    names = NfcRegistry.people()

    summaries =
      events
      |> Enum.group_by(& &1.person)
      |> Enum.map(fn {person, person_events} ->
        Assessment.summary(person, person_events, now)
      end)
      |> Enum.sort_by(& &1.person)

    assign(socket,
      now: now,
      names: names,
      summaries: summaries,
      # Swallows come in dozens per meal: one growing "swallowing" row per
      # burst here, the per-person page lists them one by one.
      journal: journal_rows(events, @journal_size),
      context: Assessment.context(events),
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
          <h1>BodyLogs I/O Ledger <span class="live">LIVE</span></h1>
          <div class="sub">
            Real devices only. Every NFC tap and sensor reading is a journal entry, nothing is typed. {@total} entries.
          </div>
        </div>
        <a href="/nasa" class="button">NASA legacy data</a>
      </div>

      <h2>People, last 24 hours</h2>
      <p :if={@summaries == []} class="sub">Nobody has scanned yet.</p>
      <div class="grid">
        <.person_card
          :for={s <- @summaries}
          summary={s}
          name={person_name(s.person, @names)}
          href={"/p/" <> URI.encode(s.person)}
          planned_water={@planned_water}
          min_urine={@min_urine}
        />
      </div>

      <h2>Journal, newest first</h2>
      <.journal events={@journal} names={@names} now={@now} context={@context} />
    </main>
    """
  end
end
