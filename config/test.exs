import Config

# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
config :io_log, IoLog.Repo,
  database: Path.expand("../io_log_test#{System.get_env("MIX_TEST_PARTITION")}.db", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test.
config :io_log, IoLogWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_only_Zr7Wq2Lp9Xk4Mv1Bn6Hc3Jd8Fs5Gt0Ya2Ue7Io4Pa9Sd1Fg6Hj3Kl8Zx5Cv0Bn2Mq",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
