defmodule IoLog.NfcRegistry do
  @moduledoc """
  Resolves what an NFC scan means.

    * tag UID (e.g. "04:00:81:1c:05:00:01") -> tag name ("toilet-2") ->
      event kind and zone from `config :io_log, :nfc_tags`
    * device name (set on the phone's Web NFC page) -> crew id

  The mapping lives in `priv/nfc_registry.json` and is read on every scan,
  so new stickers and phones can be registered without a restart.
  Unknown devices are logged under their own device name.

  A UID entry is either a plain tag name or an object describing the
  labelled item, e.g. a food package:

      "04:00:81:1c:05:00:01": "toilet-2",
      "04:00:a1:2b:05:00:01": {"tag": "food", "item": "Baby puree #1", "amount": 90, "unit": "g"}

  Item entries are created from the phone with `register/2`
  (`POST /api/tags`).
  """

  require Logger

  @item_fields ~w(item amount unit)

  @doc """
  Resolves a tag UID to `{:ok, tag_name, config}`, where `config` is the
  tag's `%{kind: ..., zone: ...}` plus `:item` (a map with "item",
  "amount", "unit") when the UID labels a specific item.
  """
  @spec resolve_tag(String.t()) :: {:ok, String.t(), map()} | {:error, :unregistered_tag}
  def resolve_tag(uid) do
    uid = normalize_uid(uid)

    with entry when not is_nil(entry) <- Map.get(uids(), uid),
         {name, item} <- split_entry(entry),
         {:ok, config} <- Map.fetch(tags(), name) do
      {:ok, name, if(item == %{}, do: config, else: Map.put(config, :item, item))}
    else
      _ -> {:error, :unregistered_tag}
    end
  end

  @doc """
  Registers (or re-registers) a tag UID as an item of tag type `"tag"`.

  `attrs` is a map with "tag" (required, one of the configured tag names)
  and optional "item", "amount", "unit". Returns `{:ok, entry}` or
  `{:error, reason}`.
  """
  @spec register(String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def register(uid, attrs) do
    uid = normalize_uid(uid)
    tag = attrs["tag"]

    cond do
      uid == "" ->
        {:error, "tag_id is required"}

      not Map.has_key?(tags(), tag) ->
        {:error, "unknown tag type #{inspect(tag)}, expected one of: #{known_tags()}"}

      true ->
        entry =
          attrs
          |> Map.take(@item_fields)
          |> Enum.reject(fn {_k, v} -> v in [nil, ""] end)
          |> Map.new()
          |> Map.put("tag", tag)

        registry = registry()
        uids = registry |> Map.get("uids", %{}) |> Map.put(uid, entry)

        case write_registry(Map.put(registry, "uids", uids)) do
          :ok -> {:ok, entry}
          {:error, reason} -> {:error, "cannot write registry: #{inspect(reason)}"}
        end
    end
  end

  @doc "Resolves a device name to a crew id (falls back to the device name)."
  @spec person_for_device(String.t() | nil) :: String.t()
  def person_for_device(device) when device in [nil, ""], do: "unknown_device"

  def person_for_device(device) do
    registry()
    |> Map.get("devices", %{})
    |> Map.get(device, device)
  end

  @doc "Lower-case, colon-separated UID, so \"04:00:81:1C\" and \"04:00:81:1c\" match."
  @spec normalize_uid(String.t()) :: String.t()
  def normalize_uid(uid), do: uid |> to_string() |> String.trim() |> String.downcase()

  @doc "Configured tag names, sorted."
  @spec tag_names() :: [String.t()]
  def tag_names, do: tags() |> Map.keys() |> Enum.sort()

  defp split_entry(name) when is_binary(name), do: {name, %{}}

  defp split_entry(%{"tag" => name} = entry) when is_binary(name),
    do: {name, Map.take(entry, @item_fields)}

  defp split_entry(_), do: :invalid

  defp tags, do: Application.get_env(:io_log, :nfc_tags, %{})

  defp known_tags, do: Enum.join(tag_names(), ", ")

  defp uids do
    registry()
    |> Map.get("uids", %{})
    |> Map.new(fn {uid, entry} -> {normalize_uid(uid), entry} end)
  end

  defp registry do
    path = path()

    with {:ok, body} <- File.read(path),
         {:ok, map} when is_map(map) <- Jason.decode(body) do
      map
    else
      error ->
        Logger.warning("Cannot read #{path}: #{inspect(error)}")
        %{}
    end
  end

  defp write_registry(map) do
    path = path()
    tmp = path <> ".tmp"

    with :ok <- File.write(tmp, Jason.encode_to_iodata!(map, pretty: true)) do
      File.rename(tmp, path)
    end
  end

  # Overridable for tests: `config :io_log, :nfc_registry_path, "/tmp/x.json"`
  defp path do
    Application.get_env(:io_log, :nfc_registry_path) ||
      Application.app_dir(:io_log, "priv/nfc_registry.json")
  end
end
