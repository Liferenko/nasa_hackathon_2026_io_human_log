defmodule IoLogWeb.ErrorHTML do
  @moduledoc "Renders plain-text HTML error pages, e.g. \"Not Found\"."

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
