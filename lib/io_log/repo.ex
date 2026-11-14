defmodule IoLog.Repo do
  use Ecto.Repo,
    otp_app: :io_log,
    adapter: Ecto.Adapters.SQLite3
end
