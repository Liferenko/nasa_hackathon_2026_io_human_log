import Config

# SQLite database file lives in the project root (ignored by git).
config :io_log, IoLog.Repo,
  database: Path.expand("../io_log_dev.db", __DIR__),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# Bind to 0.0.0.0 so other devices on the same network (phones, ESP32
# boards) can reach the server at http://<your-mac-ip>:4000.
config :io_log, IoLogWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "4000")],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_only_8VxJ0f3rQ1mZ4kL7pN2sT9wY6bC5hD0gF3jK8nM1qR4tU7vX0zA2cE5gH8kL1nP4",
  watchers: []

# Show and generate demo times in Bishkek time (UTC+6).
config :io_log, :utc_offset_minutes, 360

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
