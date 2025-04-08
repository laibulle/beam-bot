defmodule BeamBot.Exchanges.UseCases.SyncHistoricalDataForSymbolUseCase do
  @moduledoc """
  This module is responsible for syncing historical market data from Binance to Redis.
  It handles fetching klines data for different timeframes and storing them efficiently.
  """

  require Logger

  @binance_req_adapter Application.compile_env(:beam_bot, :binance_req_adapter)
  @klines_tuples_adapter Application.compile_env(:beam_bot, :klines_tuples_repository)

  @doc """
  Syncs historical klines data for a trading pair from Binance to Redis.

  ## Parameters
    - symbol: The trading pair symbol (e.g., "BTCUSDT")
    - interval: The interval between candlesticks (e.g., "1h", "4h", "1d")
    - days: Number of days of historical data to fetch (default: 30)

  ## Returns
    - {:ok, count} on success, where count is the number of klines stored
    - {:error, reason} on failure

  ## Examples
      iex> BeamBot.Exchanges.UseCases.SyncHistoricalDataForSymbolUseCase.sync_historical_data("BTCUSDT", "1h", DateTime.utc_now(), DateTime.add(DateTime.utc_now(), -30 * 24 * 60 * 60, :second))
      {:ok, 720}
  """
  def sync_historical_data(symbol, interval, to, from) do
    # Convert to Unix timestamps in milliseconds for Binance API
    start_timestamp = DateTime.to_unix(from, :millisecond)
    end_timestamp = DateTime.to_unix(to, :millisecond)

    {:ok, res} =
      @binance_req_adapter.get_klines(symbol, interval, 1000, start_timestamp, end_timestamp)

    Logger.debug("Fetched #{length(res)} klines for #{symbol} in #{interval} interval")

    @klines_tuples_adapter.save_klines_tuples(symbol, interval, res)
  end
end
