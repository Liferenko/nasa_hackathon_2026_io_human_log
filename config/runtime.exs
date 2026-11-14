import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts.

if System.get_env("PHX_SERVER") do
  config :io_log, IoLogWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      environment variable DATABASE_PATH is missing.
      For example: /var/lib/io_log/io_log.db
      """

  config :io_log, IoLog.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :io_log, IoLogWeb.Endpoint,
    url: [host: host, port: port, scheme: "http"],
    http: [ip: {0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base
end
