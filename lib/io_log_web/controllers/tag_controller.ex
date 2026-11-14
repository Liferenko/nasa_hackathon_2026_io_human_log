defmodule IoLogWeb.TagController do
  @moduledoc """
  NFC entry points.

    * `GET /pair/:person` - open once on a phone; the phone becomes that
      crew member's personal device (stored in a signed session cookie).
    * `GET /t/:tag` - the URL written on an NFC tag. Tapping the tag with
      a paired phone records the tag's event for that person, with
      source "nfc" and the tag's zone. No typing involved.

  Tags are configured in `config :io_log, :nfc_tags`.
  """

  use IoLogWeb, :controller

  import IoLogWeb.Format, only: [kind_label: 1, person_name: 1, local_time: 1]

  def pair(conn, %{"person" => person}) do
    conn
    |> put_session(:person, person)
    |> page(200, "Paired", "This phone now belongs to #{person_name(person)} (#{person}).")
  end

  def tap(conn, %{"tag" => tag} = params) do
    person = get_session(conn, :person) || params["p"]

    with {:ok, %{kind: kind} = config} <- fetch_tag(tag),
         person when is_binary(person) <- person,
         {:ok, event} <-
           IoLog.record(kind,
             person: person,
             source: "nfc",
             zone: Map.get(config, :zone),
             payload: %{"tag" => tag}
           ) do
      page(
        conn,
        200,
        "Logged",
        "#{kind_label(event.kind)} for #{person_name(person)} at #{local_time(event.occurred_at)}"
      )
    else
      :unknown_tag ->
        page(conn, 404, "Unknown tag", "Tag \"#{tag}\" is not registered. Known: #{known_tags()}")

      nil ->
        page(
          conn,
          401,
          "Phone not paired",
          "Open /pair/crew_1 (or crew_2...) on this phone once."
        )

      {:error, _changeset} ->
        page(conn, 422, "Not logged", "The event for tag \"#{tag}\" was rejected.")
    end
  end

  defp fetch_tag(tag) do
    case Map.fetch(tags(), tag) do
      {:ok, config} -> {:ok, config}
      :error -> :unknown_tag
    end
  end

  defp tags, do: Application.get_env(:io_log, :nfc_tags, %{})

  defp known_tags, do: tags() |> Map.keys() |> Enum.sort() |> Enum.join(", ")

  # A tiny phone-friendly page; no template files needed.
  defp page(conn, status, title, text) do
    body = """
    <!DOCTYPE html><html><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>#{esc(title)}</title>
    <style>body{font-family:-apple-system,sans-serif;background:#0b1020;color:#e7ecf5;
    padding:32px;text-align:center}h1{font-size:30px}p{font-size:18px;color:#8c97b0}</style>
    </head><body><h1>#{esc(title)}</h1><p>#{esc(text)}</p></body></html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(status, body)
  end

  defp esc(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
