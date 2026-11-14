defmodule IoLogWeb.LedgerLive do
  @moduledoc """
  The I/O screen: per crew member intake vs outtake for the last 24 hours,
  alerts with action cards, and a live timeline of ledger events.

  Read-only by design: there is no input field on this page. Data comes
  from sensors, NFC taps and (for the demo) NASA-based mock data.
  """

  use IoLogWeb, :live_view

  alias IoLog.{Assessment, Crew, Norms}

  @timeline_size 40

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
    events = IoLog.list_events(limit: 5_000)
    by_person = Enum.group_by(events, & &1.person)

    people =
      (Crew.ids() ++ Map.keys(by_person))
      |> Enum.uniq()

    summaries = Enum.map(people, &Assessment.summary(&1, Map.get(by_person, &1, []), now))

    assign(socket,
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
      <h1>BodyLogs I/O Ledger</h1>
      <div class="sub">
        Body input/output for astronaut health. Zero manual input: every value comes from a sensor, an NFC tap or NASA-based mock data. Last 24 hours, {@total} events in the ledger.
      </div>

      <h2>Crew, last 24 hours</h2>
      <div class="grid">
        <div :for={s <- @summaries} class="card" id={"crew-" <> s.person}>
          <h3>
            <span>{s.name}</span>
            <span class="src-tag">{s.person}</span>
          </h3>
          <div class="kv">
            <span>Water in</span><span>{litres(s.totals.water_ml)} / {litres(@planned_water)}</span>
          </div>
          <div class="bar"><div style={"width: #{pct(s.totals.water_ml, @planned_water)}%; background: var(--in);"}></div></div>
          <div class="kv">
            <span>Urine out</span><span>{litres(s.totals.urine_ml)} / min {litres(@min_urine)}</span>
          </div>
          <div class="bar"><div style={"width: #{pct(s.totals.urine_ml, @min_urine)}%; background: var(--out);"}></div></div>
          <div class="kv">
            <span>Food</span><span>{s.totals.food_g} g, {s.totals.meals} meals</span>
            <span>Drinks minus urine</span><span>{s.totals.drinks_minus_urine_ml} ml</span>
            <span>Urinations</span><span>{s.totals.voids}</span>
            <span>Stool</span><span>{s.totals.stools}{bristol_suffix(s.totals.last_bristol)}</span>
            <span>Gut transit time</span><span>{transit(s.totals.transit_h)}</span>
          </div>
          <div :if={s.alerts == []} class="alert alert-info"><b class="ok">All within NASA reference values</b></div>
          <div :for={a <- s.alerts} class={"alert alert-#{a.level}"}>
            <b>{a.title}</b>
            <div class="act">Action: {a.action}</div>
            <div class="src">{a.source}</div>
          </div>
        </div>
      </div>

      <h2>Ledger, newest first</h2>
      <div class="card">
        <table>
          <thead>
            <tr><th>Time</th><th>Who</th><th>Event</th><th>Values</th><th>Zone</th><th>Source</th><th>Status</th></tr>
          </thead>
          <tbody id="timeline">
            <tr :for={e <- @timeline} id={"event-#{e.id}"}>
              <td>{local_time(e.occurred_at)}</td>
              <td>{person_name(e.person)}</td>
              <td>{kind_label(e.kind)}</td>
              <td>{amount(e)}</td>
              <td>{e.zone || "-"}</td>
              <td class="src-tag">{e.source}</td>
              <td><span class={"badge badge-#{Assessment.status(e)}"}>{Assessment.status(e)}</span></td>
            </tr>
          </tbody>
        </table>
      </div>
    </main>
    """
  end

  defp pct(_value, 0), do: 0
  defp pct(value, target), do: min(round(value / target * 100), 100)

  defp bristol_suffix(nil), do: ""
  defp bristol_suffix(type), do: ", Bristol #{type}"

  defp transit(nil), do: "-"
  defp transit(hours), do: "#{hours} h"
end
