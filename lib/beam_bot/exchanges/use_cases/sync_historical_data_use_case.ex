defmodule BeamBot.Exchanges.UseCases.SyncHistoricalDataUseCase do
  @moduledoc """
  This module is responsible for syncing historical market data from Binance to Redis.
  It handles fetching klines data for different timeframes and storing them efficiently.
  """

  require Logger

  @binance_req_adapter Application.compile_env(:beam_bot, :binance_req_adapter)
  @klines_adapter Application.compile_env(:beam_bot, :klines_repository)

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

    {:ok, res} =
      @binance_req_adapter.get_klines(symbol, interval, 1000, start_timestamp, end_timestamp)

    klines =
      Enum.map(res, fn [
                         timestamp,
                         open,
                         high,
                         low,
                         close,
                         volume,
                         _close_time,
                         quote_volume,
                         trades_count,
                         taker_buy_base_volume,
                         taker_buy_quote_volume,
                         ignored
                       ] ->
        datetime = DateTime.from_unix!(div(timestamp, 1000), :second)

        %BeamBot.Exchanges.Domain.Kline{
          symbol: symbol,
          platform: "binance",
          interval: interval,
          timestamp: datetime,
          open: Decimal.new(open),
          high: Decimal.new(high),
          low: Decimal.new(low),
          close: Decimal.new(close),
          volume: Decimal.new(volume),
          quote_volume: Decimal.new(quote_volume),
          trades_count: trades_count,
          taker_buy_base_volume: Decimal.new(taker_buy_base_volume),
          taker_buy_quote_volume: Decimal.new(taker_buy_quote_volume),
          ignore: Decimal.new(ignored)
        }
      end)

    @klines_adapter.store_klines(klines)
  end
end
