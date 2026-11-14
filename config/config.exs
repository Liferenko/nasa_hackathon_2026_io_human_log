# General application configuration shared by all environments.
import Config

config :io_log,
  ecto_repos: [IoLog.Repo],
  generators: [timestamp_type: :utc_datetime_usec]

# NFC tags: the tag id is the last part of the NDEF URL written on the tag,
# e.g. http://<host>:4000/t/toilet-2
config :io_log, :nfc_tags, %{
  "food" => %{kind: "food_intake", zone: "galley"},
  "water" => %{kind: "water_intake", zone: "galley"},
  "toilet-1" => %{kind: "toilet_number_1", zone: "toilet"},
  "toilet-2" => %{kind: "toilet_number_2", zone: "toilet"}
}

# Endpoint configuration
config :io_log, IoLogWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: IoLogWeb.ErrorHTML, json: IoLogWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: IoLog.PubSub,
  live_view: [signing_salt: "io_log_live_view"]

# Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
