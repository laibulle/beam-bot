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
  @default_streams ["markPrice", "aggTrade"]

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_state) do
    # Get all active trading pairs
    trading_pairs =
      @trading_pairs_repository.list_trading_pairs()
      |> Enum.filter(& &1.is_active)

    Logger.info(
      "Starting Binance WebSocket supervisor with #{length(trading_pairs)} active trading pairs"
    )

    # Define children specs for each trading pair with unique IDs
    children =
      Enum.map(trading_pairs, fn trading_pair ->
        %{
          id: {:binance_ws, trading_pair.symbol},
          start: {BinanceWsAdapter, :start_link, [trading_pair.symbol, @default_streams]}
        }
      end)

    # Use one_for_all strategy to enable parallel startup of WebSocket connections
    opts = [strategy: :one_for_all]
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
