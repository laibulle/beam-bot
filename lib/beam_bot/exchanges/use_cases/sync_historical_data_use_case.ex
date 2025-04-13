defmodule BeamBot.Exchanges.UseCases.SyncHistoricalDataForSymbolUseCase do
  @moduledoc """
  This module is responsible for syncing historical market data from Binance to Redis.
  It handles fetching klines data for different timeframes and storing them efficiently.
  """

  require Logger

  @binance_req_adapter Application.compile_env(:beam_bot, :binance_req_adapter)
  @klines_tuples_adapter Application.compile_env(:beam_bot, :klines_tuples_repository)
  @sync_history_repository Application.compile_env(:beam_bot, :sync_history_repository)

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
       iex> BeamBot.Exchanges.UseCases.SyncHistoricalDataForSymbolUseCase.sync_historical_data(1, "BTCUSDT", "1m", DateTime.utc_now(), DateTime.add(DateTime.utc_now(),  -3 * 60, :second))
      {:ok, 720}

      iex> BeamBot.Exchanges.UseCases.SyncHistoricalDataForSymbolUseCase.sync_historical_data(1, "BTCUSDT", "1h", DateTime.utc_now(), DateTime.add(DateTime.utc_now(), -30 * 24 * 60 * 60, :second))
      {:ok, 720}
  """
  def sync_historical_data(exchange_id, symbol, interval, to, from) do
    # Convert to Unix timestamps in milliseconds for Binance API

    {from, to} =
      case @sync_history_repository.get_most_recent(exchange_id, symbol, interval) do
        {:ok, sync_history} ->
          {sync_history.last_point_date, to}

        {:error, :not_found} ->
          {from, to}
      end

    start_timestamp = DateTime.to_unix(from, :millisecond)
    end_timestamp = DateTime.to_unix(to, :millisecond)

    {:ok, res} =
      @binance_req_adapter.get_klines(symbol, interval, nil, start_timestamp, end_timestamp)

    Logger.debug("Fetched #{length(res)} klines for #{symbol} in #{interval} interval")

    case res do
      [] ->
        {:ok, 0}

      res ->
        [_, _, _, _, _, _, last_point_date, _, _, _, _, _] = List.last(res)
        [first_point_date, _, _, _, _, _, _, _, _, _, _, _] = List.first(res)

        {:ok, _sync_history} =
          @sync_history_repository.upsert(%{
            exchange_id: exchange_id,
            symbol: symbol,
            interval: interval,
            from: from,
            to: to,
            first_point_date: first_point_date |> DateTime.from_unix!(:millisecond),
            last_point_date: last_point_date |> DateTime.from_unix!(:millisecond)
          })

        @klines_tuples_adapter.save_klines_tuples(symbol, interval, res)
    end
  end
end
