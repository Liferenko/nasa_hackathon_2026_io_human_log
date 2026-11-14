defmodule IoLogWeb.LedgerComponents do
  @moduledoc "Shared building blocks of the I/O screens: person cards and the journal."

  use IoLogWeb, :html

  alias IoLog.Assessment

  @doc "A person's 24-hour I/O card with alerts and action cards."
  attr :summary, :map, required: true
  attr :name, :string, required: true
  attr :planned_water, :integer, required: true
  attr :min_urine, :integer, required: true
  attr :href, :string, default: nil

  def person_card(assigns) do
    ~H"""
    <div class="card" id={"crew-" <> @summary.person}>
      <h3>
        <a :if={@href} href={@href} class="plain">{@name}</a>
        <span :if={!@href}>{@name}</span>
        <span class="src-tag">{@summary.person}</span>
      </h3>
      <div class="kv">
        <span>Water in</span><span>{litres(@summary.totals.water_ml)} / {litres(@planned_water)}</span>
      </div>
      <div class="bar">
        <div style={"width: #{pct(@summary.totals.water_ml, @planned_water)}%; background: var(--in);"}></div>
      </div>
      <div class="kv">
        <span>Urine out</span><span>{litres(@summary.totals.urine_ml)} / min {litres(@min_urine)}</span>
      </div>
      <div class="bar">
        <div style={"width: #{pct(@summary.totals.urine_ml, @min_urine)}%; background: var(--out);"}></div>
      </div>
      <div class="kv">
        <span>Food</span><span>{@summary.totals.food_g} g, {@summary.totals.meals} meals</span>
        <span>Drinks minus urine</span><span>{@summary.totals.drinks_minus_urine_ml} ml</span>
        <span>Urinations</span><span>{@summary.totals.voids}</span>
        <span>Stool</span><span>{@summary.totals.stools}{bristol_suffix(@summary.totals.last_bristol)}</span>
        <span>Gut transit time</span><span>{transit(@summary.totals.transit_h)}</span>
      </div>
      <div :if={@summary.alerts == []} class="alert alert-info">
        <b class="ok">All within NASA reference values</b>
      </div>
      <div :for={a <- @summary.alerts} class={"alert alert-#{a.level}"}>
        <b>{a.title}</b>
        <div class="act">Action: {a.action}</div>
        <div class="src">{a.source}</div>
      </div>
    </div>
    """
  end

  @doc "The journal table, newest first. Rows recorded in the last few seconds glow."
  attr :events, :list, required: true
  attr :names, :map, default: %{}
  attr :now, :any, required: true
  attr :show_person, :boolean, default: true

  def journal(assigns) do
    ~H"""
    <div class="card">
      <p :if={@events == []} class="sub">No entries yet. Tap an NFC tag with a phone.</p>
      <table :if={@events != []}>
        <thead>
          <tr>
            <th>Time</th>
            <th :if={@show_person}>Who</th>
            <th>Event</th>
            <th>Values</th>
            <th>Zone</th>
            <th>Source</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody id="timeline">
          <tr :for={e <- @events} id={"event-#{e.id}"} class={fresh_class(e, @now)}>
            <td>{local_time(e.occurred_at)}</td>
            <td :if={@show_person}>
              <a href={"/p/" <> URI.encode(e.person)} class="plain">{person_name(e.person, @names)}</a>
            </td>
            <td>{kind_label(e.kind)}</td>
            <td>{amount(e)}</td>
            <td>{e.zone || "-"}</td>
            <td class="src-tag">{e.source}</td>
            <td>
              <span class={"badge badge-#{Assessment.status(e)}"}>{Assessment.status(e)}</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp fresh_class(event, now) do
    if DateTime.diff(now, event.inserted_at) <= 10, do: "fresh", else: nil
  end

  defp pct(_value, 0), do: 0
  defp pct(value, target), do: min(round(value / target * 100), 100)

  defp bristol_suffix(nil), do: ""
  defp bristol_suffix(type), do: ", Bristol #{type}"

  defp transit(nil), do: "-"
  defp transit(hours), do: "#{hours} h"
end
