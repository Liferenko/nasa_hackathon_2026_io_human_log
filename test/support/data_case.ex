defmodule IoLog.DataCase do
  @moduledoc """
  Test case for tests that need access to the database.
  Each test runs inside a sandboxed transaction that is rolled back.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias IoLog.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import IoLog.DataCase
    end
  end

  setup tags do
    IoLog.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc "Sets up the sandbox based on the test tags."
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(IoLog.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc "Transforms changeset errors into a map of messages."
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
