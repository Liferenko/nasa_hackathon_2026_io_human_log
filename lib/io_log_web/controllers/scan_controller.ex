defmodule IoLogWeb.ScanController do
  @moduledoc """
  `POST /api/scans` - receives NFC scans forwarded by the Web NFC logger
  (`nfc_logger/server.py`):

      {"tag_id": "04:00:81:1c:05:00:01", "device": "Mi flip3",
       "scanned_at": "2026-11-14T08:21:28.359Z"}

  A registered tag becomes a ledger event with `source: "nfc"`, the tag's
  zone and the phone's scan time. If the UID labels a specific item
  (e.g. a food package), its "item", "amount" and "unit" go into the payload. An unregistered tag is answered with 202
  and the UID, so it can be added to `priv/nfc_registry.json`.
  """

  use IoLogWeb, :controller

  require Logger

  alias IoLog.NfcRegistry

  def create(conn, %{"tag_id" => uid} = params) do
    device = params["device"]

    case NfcRegistry.resolve_tag(uid) do
      {:ok, tag, %{kind: kind} = config} ->
        person = NfcRegistry.person_for_device(device)

        {:ok, event} =
          IoLog.record(kind,
            person: person,
            source: "nfc",
            zone: Map.get(config, :zone),
            occurred_at: parse_time(params["scanned_at"]),
            payload:
              Map.merge(Map.get(config, :item, %{}), %{
                "tag" => tag,
                "tag_uid" => NfcRegistry.normalize_uid(uid),
                "device" => device,
                "received_at" => params["received_at"]
              })
          )

        conn
        |> put_status(:created)
        |> json(%{
          status: "logged",
          id: event.id,
          kind: event.kind,
          person: event.person,
          tag: tag,
          item: get_in(config, [:item, "item"])
        })

      {:error, :unregistered_tag} ->
        Logger.info("Unregistered NFC tag #{uid} from #{device}")

        conn
        |> put_status(:accepted)
        |> json(%{status: "unregistered_tag", tag_id: NfcRegistry.normalize_uid(uid)})
    end
  end

  def create(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "tag_id is required"})
  end

  defp parse_time(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end

  defp parse_time(_), do: nil
end
