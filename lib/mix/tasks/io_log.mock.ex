defmodule Mix.Tasks.IoLog.Mock do
  @shortdoc "Reloads NASA-based mock I/O data (clears old mock events only)"

  @moduledoc """
  Clears previous mock events (source "mock") and generates new ones.

      mix io_log.mock            # 4 days for 5 crew members
      mix io_log.mock --days 5

  With the server running, prefer `IoLog.Mock.reload!()` in iex: the
  screen updates live.
  """

  use Mix.Task

  @impl true
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [days: :integer])
    Mix.Task.run("app.start")
    count = IoLog.Mock.reload!(days: Keyword.get(opts, :days, 4))
    Mix.shell().info("Inserted #{count} mock events.")
  end
end
