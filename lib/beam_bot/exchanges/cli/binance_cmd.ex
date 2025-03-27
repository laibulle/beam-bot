defmodule BeamBot.Exchanges.CLI.BinanceCmd do
  @moduledoc """
  CLI commands for interacting with the Binance WebSocket adapter.
  """

  alias BeamBot.Exchanges.Infrastructure.Adapters.BinanceWsAdapter

  @doc """
  Check if the Binance WebSocket connection is alive and its current status.
  """
  def check_connection do
    if BinanceWsAdapter.alive?() do
      IO.puts("✅ Binance WebSocket connection is ACTIVE")

      # Get more details
      status = BinanceWsAdapter.connection_status()
      IO.puts("PID: #{inspect(status.pid)}")
      IO.puts("Registered name: #{inspect(status.connected_since)}")
      IO.puts("Memory usage: #{inspect(status.memory_usage)} bytes")
      IO.puts("Message queue length: #{inspect(status.message_queue_len)}")

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
