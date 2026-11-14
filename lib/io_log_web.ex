defmodule IoLogWeb do
  @moduledoc """
  The entrypoint for defining the web interface: controllers, router,
  LiveViews and components.

  Use it in your modules as:

      use IoLogWeb, :controller
      use IoLogWeb, :router
      use IoLogWeb, :live_view
  """

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      import Plug.Conn
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      import IoLogWeb.Format
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import IoLogWeb.Format
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/router/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
