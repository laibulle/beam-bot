defmodule BeamBot.Exchanges.Infrastructure.Subscribers.BinanceWsSubscriber do
  @moduledoc """
  Subscribes to Binance WebSocket events via PubSub and processes them.
  This module demonstrates how to consume the data broadcast by the BinanceWsAdapter.
  """
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Subscribe to the Binance WebSocket topics
    subscribe_to_topics()
    {:ok, %{}}
  end

  @impl true
  def handle_info({:binance_data, stream, data}, state) do
    # Process the WebSocket data
    Logger.info("BinanceWsSubscriber received data from #{stream}")
    Logger.debug("Data content: #{inspect(data)}")

    # Add your business logic to process the data here

    {:noreply, state}
  end

  # Helper functions

  defp subscribe_to_topics do
    # Subscribe to all btcusdt streams
    # You can add more specific stream subscriptions as needed
    Phoenix.PubSub.subscribe(BeamBot.PubSub, "binance:btcusdt@aggTrade")
    Phoenix.PubSub.subscribe(BeamBot.PubSub, "binance:btcusdt@markPrice")
    Logger.info("Subscribed to Binance WebSocket topics")
  end
end
