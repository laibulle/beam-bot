defmodule BeamBot.Exchanges.Infrastructure.Workers.BinanceWsSupervisor do
  @moduledoc """
  Supervisor for managing Binance WebSocket connections for all active trading pairs.
  Each trading pair gets its own WebSocket connection managed by this supervisor.
  """
  use Supervisor
  require Logger

  alias BeamBot.Exchanges.Infrastructure.Adapters.BinanceWsAdapter

  @trading_pairs_repository Application.compile_env(:beam_bot, :trading_pairs_repository)

  # Default streams to subscribe to for each symbol
  @default_streams [
    "markPrice",
    "kline_1m",
    "kline_5m",
    "kline_15m",
    "kline_30m",
    "kline_1h",
    "kline_4h",
    "kline_6h",
    "kline_8h",
    "kline_12h",
    "kline_1d"
  ]

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Custom start function that returns the already started pid.
  This is used to supervise pre-started processes.
  """
  def start_child(pid) when is_pid(pid), do: {:ok, pid}

  @impl true
  def init(_state) do
    # Get all active trading pairs
    trading_pairs =
      @trading_pairs_repository.list_trading_pairs()
      |> Enum.filter(& &1.is_active)

    Logger.debug(
      "Starting Binance WebSocket supervisor with #{length(trading_pairs)} active trading pairs"
    )

    # Clean up any existing processes for these trading pairs
    Enum.each(trading_pairs, fn trading_pair ->
      case Registry.lookup(BeamBot.Registry, {BinanceWsAdapter, trading_pair.symbol}) do
        [{pid, _}] ->
          Logger.debug("Found existing process for #{trading_pair.symbol}, terminating it")
          Process.exit(pid, :normal)

        [] ->
          :ok
      end
    end)

    # Start children concurrently using Task.async_stream
    children =
      trading_pairs
      |> Task.async_stream(
        fn trading_pair ->
          # Start the child process directly
          {:ok, pid} = BinanceWsAdapter.start_link(trading_pair.symbol, @default_streams)
          # Return the child spec with the already started pid
          %{
            id: {:binance_ws, trading_pair.symbol},
            start: {__MODULE__, :start_child, [pid]},
            restart: :permanent,
            type: :worker
          }
        end,
        max_concurrency: 100,
        ordered: false
      )
      |> Enum.map(fn {:ok, child} -> child end)

    # Use one_for_one strategy to handle failures independently
    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end

  @doc """
  Get the status of all WebSocket connections managed by this supervisor.
  """
  def get_connection_statuses do
    trading_pairs =
      @trading_pairs_repository.list_trading_pairs()
      |> Enum.filter(& &1.is_active)

    Enum.map(trading_pairs, fn trading_pair ->
      BinanceWsAdapter.connection_status(trading_pair.symbol)
    end)
  end

  @doc """
  Get the status of a specific WebSocket connection.
  """
  def get_connection_status(symbol) when is_binary(symbol) do
    BinanceWsAdapter.connection_status(symbol)
  end

  @doc """
  Get the list of streams a specific WebSocket connection is subscribed to.
  """
  def get_streams(symbol) when is_binary(symbol) do
    BinanceWsAdapter.get_streams(symbol)
  end

  @doc """
  Subscribe to additional streams for a specific symbol.
  """
  def subscribe(symbol, streams) when is_binary(symbol) and is_list(streams) do
    BinanceWsAdapter.subscribe(symbol, streams)
  end

  @doc """
  Unsubscribe from streams for a specific symbol.
  """
  def unsubscribe(symbol, streams) when is_binary(symbol) and is_list(streams) do
    BinanceWsAdapter.unsubscribe(symbol, streams)
  end

  @doc """
  Ping a specific WebSocket connection to check connectivity.
  """
  def ping(symbol) when is_binary(symbol) do
    BinanceWsAdapter.ping(symbol)
  end

  @doc """
  Check if a specific WebSocket connection is alive.
  """
  def alive?(symbol) when is_binary(symbol) do
    BinanceWsAdapter.alive?(symbol)
  end
end
