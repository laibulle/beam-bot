defmodule BeamBotWeb.HomeLive do
  import Phoenix.Component
  use BeamBotWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.link
      navigate={~p"/dashboard/"}
      class="block w-full text-center bg-gray-600 text-white px-4 py-2 rounded-md hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2"
    >
      Go to Dashboard
    </.link>
    """
  end
end
