defmodule BeamBot.Exchanges.Infrastructure.Adapters.QuestDB.QuestDBRestAdapter do
  @moduledoc """
  Adapter for QuestDB using REST API.
  """
  require Logger

  @doc """
  Fetches kline data from QuestDB for a given symbol and interval.

  ## Parameters
    - symbol: The trading pair symbol (e.g., "BTCUSDT")
    - interval: The interval between candlesticks (e.g., "1h", "4h", "1d")
    - limit: Number of candlesticks to fetch (default: 500)
    - start_time: Start time in milliseconds (optional)
    - end_time: End time in milliseconds (optional)

  ## Examples
      iex> BeamBot.Exchanges.Infrastructure.Adapters.QuestDB.QuestDBRestAdapter.get_klines("BTCUSDT", "1h")
      {:ok, [["BTCUSDT", "1h", "binance", 102642.0, 103800.0, 102504.0, 102777.99, 2215.49639, 228556325.2789463, 1214.18516, 125284750.5204112, 531227.0]]}
  """
  def get_klines(symbol, interval, limit \\ 500, start_time \\ nil, end_time \\ nil) do
    query = build_query(symbol, interval, limit, start_time, end_time)

    case BeamBot.QuestDB.query(query) do
      {:ok, %{"query" => _, "columns" => columns, "dataset" => dataset}} ->
        klines = parse_klines(dataset, columns, interval)
        {:ok, klines}

      {:error, reason} ->
        Logger.error("Failed to fetch klines: #{inspect(reason)}")
        {:error, "Failed to fetch klines: #{inspect(reason)}"}
    end
  end

  defp build_query(symbol, interval, limit, start_time, end_time) do
    time_conditions = build_time_conditions(start_time, end_time)
    table_name = "klines_#{String.downcase(symbol)}_#{String.downcase(interval)}"

    """
    SELECT symbol, open, high, low, close, volume, quote_asset_volume,
           taker_buy_base_asset_volume, taker_buy_quote_asset_volume, number_of_trades
    FROM #{table_name}
    WHERE symbol = '#{symbol}' #{time_conditions}
    ORDER BY timestamp DESC
    LIMIT #{limit}
    """
  end

  defp build_time_conditions(nil, nil), do: ""
  defp build_time_conditions(start_time, nil), do: "AND timestamp >= #{start_time}"
  defp build_time_conditions(nil, end_time), do: "AND timestamp <= #{end_time}"

  defp build_time_conditions(start_time, end_time),
    do: "AND timestamp >= #{start_time} AND timestamp <= #{end_time}"

  defp parse_klines(dataset, _columns, interval) do
    Enum.map(dataset, fn [
                           symbol,
                           open,
                           high,
                           low,
                           close,
                           volume,
                           quote_volume,
                           taker_buy_base,
                           taker_buy_quote,
                           trades
                         ] ->
      [
        symbol,
        interval,
        "binance",
        open,
        high,
        low,
        close,
        volume,
        quote_volume,
        taker_buy_base,
        taker_buy_quote,
        trades
      ]
    end)
  end
end
