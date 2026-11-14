defmodule IoLogWeb.ConnCase do
  @moduledoc """
  Test case for tests that require a connection.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint IoLogWeb.Endpoint

      import Plug.Conn
      import Phoenix.ConnTest
    end
  end

  setup tags do
    IoLog.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
