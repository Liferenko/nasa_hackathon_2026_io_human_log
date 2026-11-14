defmodule IoLog.Application do
  # See https://hexdocs.pm/elixir/Application.html
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      IoLog.Repo,
      {Phoenix.PubSub, name: IoLog.PubSub},
      IoLogWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: IoLog.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    IoLogWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
