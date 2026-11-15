defmodule IoLogWeb.SensorController do
  @moduledoc """
  `POST /api/sensors` - events detected by a sensor on a device, e.g. one
  swallow from the phone accelerometer on the throat (`/swallow`):

      {"kind": "swallow", "device": "Altynbek biologist",
       "detected_at": "2026-11-14T09:41:02.120Z", "source": "phone_accel",
       "payload": {"peak": 0.42, "duration_ms": 640, "threshold": 0.12}}

  The device name maps to a person via `priv/nfc_registry.json`, as for
  NFC scans. The event is appended to the ledger as is.
  """

  use IoLogWeb, :controller

  alias IoLog.NfcRegistry

  @kinds ~w(swallow)

  def create(conn, %{"kind" => kind} = params) when kind in @kinds do
    device = params["device"]
    payload = if is_map(params["payload"]), do: params["payload"], else: %{}

    {:ok, event} =
      IoLog.record(kind,
        person: NfcRegistry.person_for_device(device),
        source: params["source"] || "phone_accel",
        occurred_at: parse_time(params["detected_at"]),
        payload:
          Map.merge(payload, %{
            "device" => device,
            "received_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
            "event_uid" => params["event_uid"]
          })
      )

    conn
    |> put_status(:created)
    |> json(%{status: "logged", id: event.id, kind: event.kind, person: event.person})
  end

  def create(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "kind must be one of: #{Enum.join(@kinds, ", ")}"})
  end

  defp parse_time(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end

  defp parse_time(_), do: nil
end
