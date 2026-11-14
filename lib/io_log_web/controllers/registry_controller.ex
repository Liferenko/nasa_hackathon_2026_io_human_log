defmodule IoLogWeb.RegistryController do
  @moduledoc """
  Labelling NFC stickers from the phone (forwarded by `nfc_logger/server.py`).

    * `GET /api/tags` - configured tag types, e.g. `["food", "water", ...]`
    * `POST /api/tags` - bind a tag UID to a tag type and an optional item:

          {"tag_id": "04:00:a1:2b:05:00:01", "tag": "food",
           "item": "Baby puree #1", "amount": 90, "unit": "g"}

  The binding is stored in `priv/nfc_registry.json`; later scans of that
  UID are logged with the item in the event payload.
  """

  use IoLogWeb, :controller

  alias IoLog.NfcRegistry

  def index(conn, _params) do
    json(conn, %{tags: NfcRegistry.tag_names()})
  end

  def create(conn, %{"tag_id" => uid} = params) do
    case NfcRegistry.register(uid, params) do
      {:ok, entry} ->
        conn
        |> put_status(:created)
        |> json(Map.merge(entry, %{"status" => "registered", "tag_id" => NfcRegistry.normalize_uid(uid)}))

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: reason})
    end
  end

  def create(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "tag_id is required"})
  end
end
