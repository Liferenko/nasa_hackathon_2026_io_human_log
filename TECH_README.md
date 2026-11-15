# BodyLogs I/O Ledger: technical README

Everything needed to run, develop and test `io_log`.
For the project overview, see [README.md](README.md).

## Stack

- Elixir 1.15+ / Erlang/OTP 25+ (verified with Elixir 1.18)
- Phoenix 1.8 + LiveView 1.1, Bandit HTTP server, no asset pipeline
  (the Phoenix and LiveView JS clients are served from the deps under `/vendor`)
- Ecto + SQLite (`ecto_sqlite3`)
- Phoenix.PubSub for live updates
- Python 3 for the Web NFC logger (`nfc_logger/`)

## Setup and run

```sh
mix setup            # deps.get + ecto.create + ecto.migrate
mix io_log.mock      # optional: 4 days of NASA-based mock data for 5 crew
iex -S mix phx.server
```

Open http://localhost:4000 for the I/O screen. The server listens on
`0.0.0.0:4000`, so phones on the same network (or Tailscale) can reach it at
`http://<your-computer>:4000`.

## The I/O screen (`/`)

- One card per crew member for the last 24 hours: water in vs planned
  2.8 L (NASA BVAD), urine out vs 2 L/day minimum (NASA renal stone risk),
  food, urinations, stool with Bristol type, gut transit time.
- Alerts with action cards, e.g. "Drink +600 ml spread over the next 6 hours".
- A live ledger table with a status per event: `confirmed`, `conflict`
  (toilet event outside the toilet zone) or `unusual` (eating outside the galley).
- No input field anywhere: the page is read-only and updates live.

## Mock data (demo phase 2)

```elixir
IoLog.Mock.reload!()         # clear old mock events, generate 4 days
IoLog.Mock.reload!(days: 5)
IoLog.Mock.clear!()          # removes events with source "mock" only
```

The built-in story matches `features/io_ledger.feature`:
John Doe and Jane Roe are healthy, Alex Poe under-drinks (renal stone risk,
hard stool), Sam Moe eats at the workstation and has one location conflict,
Kai Zoe drinks only ~14% of the planned water while urine stays stable at
~2.1 L/day (unexplained fluid source, needs an external check).
Reference values are in `lib/io_log/norms.ex` with their NASA sources.

## NFC via the Web NFC logger (`nfc_logger/`)

The phones read tag UIDs with the Web NFC page served by `nfc_logger/server.py`
(port 8765, HTTPS through `tailscale serve`). Every scan is stored in
`nfc_logger/scans.jsonl` and forwarded to this app:

```
phone (Web NFC) -> nfc_logger :8765 -> POST http://127.0.0.1:4000/api/scans -> ledger -> I/O screen
```

- `priv/nfc_registry.json` maps tag UIDs to tag names (`toilet-2`, `water`, ...)
  and device names to crew ids. It is read on every scan: edit, save, done.
- An unregistered UID is answered with `{"status":"unregistered_tag"}` and not logged.
- An unknown device is logged under its own device name (e.g. a ground team phone).
- Disable forwarding with `IO_LOG_URL="" python3 server.py`.

## NFC tags (zero manual input)

1. Pair each phone once: open `http://<host>:4000/pair/crew_1` on the first
   phone, `.../pair/crew_2` on the second. The pairing is kept in a cookie.
2. Write an NDEF URL record on each tag, e.g. `http://<host>:4000/t/toilet-2`.
3. Tapping a tag with a paired phone records the event with `source: "nfc"`
   and the tag's zone; the I/O screen updates live.

Registered tags (`config :io_log, :nfc_tags` in `config/config.exs`):

| Tag        | Event             | Zone   |
|------------|-------------------|--------|
| `food`     | `food_intake`     | galley |
| `water`    | `water_intake`    | galley |
| `toilet-1` | `toilet_number_1` | toilet |
| `toilet-2` | `toilet_number_2` | toilet |

Without pairing, `?p=crew_1` on the URL also works (for quick tests).

## Recording events from iex

```elixir
IoLog.record(:food_intake)
IoLog.record(:water_intake)
IoLog.record(:toilet_number_2)
IoLog.record(:toilet_number_1, person: "crew_2", payload: %{volume_ml: 320})
IoLog.list_events()
IoLog.list_events(person: "crew_2")
```

`IoLog.record/2` returns `{:ok, %IoLog.Event{}}`, or `{:error, changeset}`
for an unknown kind.

| Option         | Default        | Notes                                                      |
|----------------|----------------|------------------------------------------------------------|
| `:person`      | `"crew_1"`     | Crew member id (`crew_1`..`crew_4` have display names)      |
| `:source`      | `"manual_iex"` | `nfc`, `ble_zone`, `scale`, `flow`, `mock`                 |
| `:zone`        | `nil`          | `galley`, `toilet`, `workstation`, `lab`, ...              |
| `:payload`     | `%{}`          | Free-form map, stored as JSON (read back with string keys) |
| `:occurred_at` | now (UTC)      | `DateTime` when the event happened                         |

Allowed kinds live in `@kinds` in `lib/io_log/event.ex`. Every recorded event
is broadcast on the PubSub topic `"events"` as `{:event_recorded, event}`.

## Other endpoints

```sh
curl http://localhost:4000/api/health
# {"app":"io_log","events":187}
```

## Time zone

The ledger stores UTC. Dev shows and generates demo times in Bishkek time
(`config :io_log, :utc_offset_minutes, 360` in `config/dev.exs`).

## Tests

```sh
mix test
```

## Project layout

```
lib/io_log.ex                       Public API: record/2, list_events/1, subscribe/0
lib/io_log/event.ex                 Event schema, allowed kinds
lib/io_log/norms.ex                 NASA reference values (with sources)
lib/io_log/assessment.ex            Totals, alerts, action cards, event status
lib/io_log/mock.ex                  NASA-based mock data generator
lib/io_log/crew.ex, clock.ex        Demo crew names, local time helpers
lib/io_log_web/live/ledger_live.ex  The I/O screen (LiveView)
lib/io_log_web/controllers/         NFC tap + pairing, health, errors
lib/mix/tasks/io_log.mock.ex        mix io_log.mock
features/io_ledger.feature          Core scenarios (Gherkin)
```
