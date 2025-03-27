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
    {:ok, %{message_count: 0, last_message: nil, last_updated: nil}}
  end

  @impl true
  def handle_info({:binance_data, stream, data}, state) do
    # Process the WebSocket data
    Logger.info("BinanceWsSubscriber received data from #{stream}")
    Logger.debug("Data content: #{inspect(data)}")

    # Add your business logic to process the data here

    # Update state with message statistics
    updated_state = %{
      state
      | message_count: state.message_count + 1,
        last_message: {stream, data},
        last_updated: DateTime.utc_now()
    }

    {:noreply, updated_state}
  end

  @doc """
  Get statistics about received WebSocket messages
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    {:reply, state, state}
  end

  @doc """
  Check if messages are being received and report status
  """
  def check_messages do
    stats = get_stats()

    IO.puts("Binance WebSocket Message Stats:")
    IO.puts("Total messages received: #{stats.message_count}")

    case stats.last_message do
      nil ->
        IO.puts("No messages received yet. Check if streams are correctly configured.")
        IO.puts("Make sure Binance WebSocket Adapter is properly connected.")
        IO.puts("Try subscribing to more active streams like btcusdt@aggTrade")

      {stream, _data} ->
        last_time = stats.last_updated
        time_diff = DateTime.diff(DateTime.utc_now(), last_time, :second)

        IO.puts("Last message from stream: #{stream}")
        IO.puts("Last message received: #{time_diff} seconds ago")

        if time_diff > 60 do
          IO.puts("⚠️ Warning: No messages received in the last minute.")
          IO.puts("Check connection or subscribe to more active streams.")
        else
          IO.puts("✅ Messages are being received recently")
        end
    end
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
