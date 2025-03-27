defmodule BeamBot.Exchanges.CLI.BinanceCmd do
  @moduledoc """
  CLI commands for interacting with the Binance WebSocket adapter.
  """

  alias BeamBot.Exchanges.Infrastructure.Adapters.BinanceWsAdapter
  alias BeamBot.Exchanges.Infrastructure.Subscribers.BinanceWsSubscriber

  @doc """
  Check if the Binance WebSocket connection is alive and its current status.

  ## Examples
  iex> BeamBot.Exchanges.CLI.BinanceCmd.check_connection()
  """
  def check_connection do
    if BinanceWsAdapter.alive?() do
      # Get connection details
      status = BinanceWsAdapter.connection_status()

      case status.status do
        :connected ->
          IO.puts("✅ Binance WebSocket connection is ACTIVE")

        :connecting ->
          IO.puts("⏳ Binance WebSocket is CONNECTING")
          IO.puts("Reconnection attempts: #{status.reconnect_count}")
      end

      # Display connection details
      IO.puts("PID: #{inspect(status.pid)}")
      IO.puts("Registered name: #{inspect(status.registered_name)}")

      if status.last_message_time do
        time_diff = DateTime.diff(DateTime.utc_now(), status.last_message_time, :second)
        IO.puts("Last message received: #{time_diff} seconds ago")
      else
        IO.puts("No messages received yet")
      end

      IO.puts("Memory usage: #{inspect(status.memory_usage)} bytes")

      # Extract message queue length from tuple
      {_, message_queue_len} = status.message_queue_len
      IO.puts("Message queue length: #{message_queue_len}")

      IO.puts("Current streams: #{inspect(BinanceWsAdapter.get_streams())}")

      # Try a ping
      case BinanceWsAdapter.ping() do
        {:ok, message} -> IO.puts("Ping result: #{message}")
        {:error, error} -> IO.puts("Ping error: #{error}")
      end
    else
      IO.puts("❌ Binance WebSocket connection is DOWN")
      IO.puts("Check application logs for errors")
    end
  end

  @doc """
  Check if messages are being received from Binance WebSocket

  ## Examples
  iex> BeamBot.Exchanges.CLI.BinanceCmd.check_messages()
  """
  def check_messages do
    if BinanceWsAdapter.alive?() do
      BinanceWsSubscriber.check_messages()
    else
      IO.puts("❌ Binance WebSocket connection is DOWN")
      IO.puts("The WebSocket connection must be established first")
    end
  end

  @doc """
  Run a full diagnostic on the Binance WebSocket system
  """
  def diagnose do
    IO.puts("\n=== BINANCE WEBSOCKET DIAGNOSTIC ===\n")

    IO.puts("1. Checking WebSocket connection...")
    check_connection()

    IO.puts("\n2. Checking message reception...")
    check_messages()

    IO.puts("\n=== DIAGNOSTIC COMPLETE ===\n")

    IO.puts("If you're not receiving messages, try these steps:")
    IO.puts("1. Subscribe to more active streams: subscribe([\"btcusdt@depth\"])")
    IO.puts("2. Check your internet connection")
    IO.puts("3. Ensure you're using the correct WebSocket URL for the market you want")
    IO.puts("4. Verify the Binance API is operational")
    IO.puts("5. Restart the application: mix phx.server")
  end

  @doc """
  Subscribe to additional Binance streams.
  """
  def subscribe(streams) when is_list(streams) do
    IO.puts("Subscribing to streams: #{inspect(streams)}")
    BinanceWsAdapter.subscribe(streams)
    IO.puts("Subscription request sent")
  end

  @doc """
  Unsubscribe from Binance streams.
  """
  def unsubscribe(streams) when is_list(streams) do
    IO.puts("Unsubscribing from streams: #{inspect(streams)}")
    BinanceWsAdapter.unsubscribe(streams)
    IO.puts("Unsubscription request sent")
  end

  @doc """
  List example streams you can subscribe to.
  """
  def list_example_streams do
    examples = [
      "btcusdt@depth",
      "ethusdt@aggTrade",
      "btcusdt@kline_1m",
      "ethusdt@kline_5m",
      "btcusdt@ticker",
      "ethusdt@miniTicker"
    ]

    IO.puts("Example streams you can subscribe to:")
    Enum.each(examples, fn stream -> IO.puts("  - #{stream}") end)
    IO.puts("\nUse: BeamBot.Exchanges.CLI.BinanceCmd.subscribe([\"stream_name\"]) to subscribe")
  end
end
