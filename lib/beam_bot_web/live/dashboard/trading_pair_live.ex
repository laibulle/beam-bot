defmodule BeamBotWeb.TradingPairLive do
  use BeamBotWeb, :live_view

  @impl true
  def mount(%{"symbol" => _symbol}, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    """
  end
end
