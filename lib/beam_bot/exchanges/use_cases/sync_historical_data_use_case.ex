defmodule BeamBot.Exchanges.UseCases.SyncHistoricalDataUseCase do
  @moduledoc """
  This module is responsible for syncing historical market data from Binance to Redis.
  It handles fetching klines data for different timeframes and storing them efficiently.
  """

  require Logger

  @binance_req_adapter Application.compile_env(:beam_bot, :binance_req_adapter)
  @klines_adapter Application.compile_env(:beam_bot, :klines_adapter)

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
      iex> BeamBot.Exchanges.UseCases.SyncHistoricalDataUseCase.sync_historical_data("BTCUSDT", "1h", 30)
      {:ok, 720}
  """
  def sync_historical_data(symbol, interval, days \\ 30) do
    # Calculate start and end times
    end_time = DateTime.utc_now()
    start_time = DateTime.add(end_time, -days * 24 * 60 * 60, :second)

    # Convert to Unix timestamps in milliseconds for Binance API
    start_timestamp = DateTime.to_unix(start_time, :millisecond)
    end_timestamp = DateTime.to_unix(end_time, :millisecond)

    # Fetch historical data from Binance
    with {:ok, klines} <-
           @binance_req_adapter.get_klines(symbol, interval, 1000, start_timestamp, end_timestamp),
         {:ok, :stored} <- @klines_adapter.store_klines(symbol, interval, klines) do
      {:ok, length(klines)}
    else
      {:error, reason} ->
        Logger.error("Failed to sync historical data: #{inspect(reason)}")
        {:error, reason}

      error ->
        Logger.error("Failed to sync historical data: #{inspect(error)}")
        {:error, "Failed to sync historical data: #{inspect(error)}"}
    end
  end

  @doc """
  Syncs historical klines data for multiple trading pairs and intervals.

  ## Parameters
    - pairs: List of trading pair symbols (e.g., ["BTCUSDT", "ETHUSDT"])
    - intervals: List of intervals (e.g., ["1h", "4h", "1d"])
    - days: Number of days of historical data to fetch (default: 30)

  ## Returns
    - {:ok, results} on success, where results is a map of symbol -> interval -> count
    - {:error, reason} on failure

  ## Examples
      iex> BeamBot.Exchanges.UseCases.SyncHistoricalDataUseCase.sync_multiple_pairs(["BTCUSDT", "ETHUSDT"], ["1h", "4h"], 30)
      {:ok, %{"BTCUSDT" => %{"1h" => 720, "4h" => 180}, "ETHUSDT" => %{"1h" => 720, "4h" => 180}}}
  """
  def sync_multiple_pairs(pairs, intervals, days \\ 30) do
    results = collect_sync_results(pairs, intervals, days)
    process_sync_results(results)
  end

  defp collect_sync_results(pairs, intervals, days) do
    for symbol <- pairs,
        interval <- intervals,
        into: %{} do
      case sync_historical_data(symbol, interval, days) do
        {:ok, count} ->
          {symbol, Map.put(%{}, interval, count)}

        {:error, reason} ->
          Logger.error("Failed to sync #{symbol} #{interval}: #{inspect(reason)}")
          {symbol, Map.put(%{}, interval, {:error, reason})}
      end
    end
  end

  defp process_sync_results(results) do
    if has_failed_syncs?(results) do
      {:error, "Some syncs failed", results}
    else
      {:ok, results}
    end
  end

  defp has_failed_syncs?(results) do
    Enum.any?(results, fn {_symbol, intervals} ->
      Enum.any?(intervals, fn {_interval, result} -> match?({:error, _}, result) end)
    end)
  end
end
