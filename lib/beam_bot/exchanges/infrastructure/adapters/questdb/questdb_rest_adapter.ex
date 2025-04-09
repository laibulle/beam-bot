defmodule BeamBot.Exchanges.Infrastructure.Adapters.QuestDB.QuestDBRestAdapter do
  @moduledoc """
  Adapter for QuestDB using REST API.
  """
  require Logger

  @behaviour BeamBot.Exchanges.Domain.Ports.KlinesTuplesRepository

  @doc """
  Fetches kline data from QuestDB for a given symbol and interval.

  ## Parameters
    - symbol: The trading pair symbol (e.g., "BTCUSDT")
    - interval: The interval between candlesticks (e.g., "1h", "4h", "1d")
    - limit: Number of candlesticks to fetch (default: 500)
    - start_time: Start time in milliseconds (optional)
    - end_time: End time in milliseconds (optional)

  ## Examples
      iex> BeamBot.Exchanges.Infrastructure.Adapters.QuestDB.QuestDBRestAdapter.get_klines_tuples("BTCUSDT", "1h")
      {:ok, [["BTCUSDT", "1h", "binance", 102642.0, 103800.0, 102504.0, 102777.99, 2215.49639, 228556325.2789463, 1214.18516, 125284750.5204112, 531227.0]]}
  """
  @impl true
  def get_klines_tuples(symbol, interval, limit \\ 500, start_time \\ nil, end_time \\ nil) do
    query = build_query(symbol, interval, limit, start_time, end_time)

    case BeamBot.QuestDB.query(query) do
      {:ok, %{"query" => _, "columns" => _columns, "dataset" => dataset}} ->
        {:ok, dataset}

      {:error, reason} ->
        Logger.error("Failed to fetch klines: #{inspect(reason)}")
        {:error, "Failed to fetch klines: #{inspect(reason)}"}
    end
  end

  def drop_tuples(symbol, interval) do
    table_name = "klines_#{String.downcase(symbol)}_#{String.downcase(interval)}"
    query = "DROP TABLE #{table_name}"

    case BeamBot.QuestDB.query(query) do
      {:ok, %{"ddl" => "OK"}} ->
        :ok

      {:error, reason} ->
        {:error, "Failed to drop tuples: #{inspect(reason)}"}
    end
  end

  defp build_query(symbol, interval, limit, start_time, end_time) do
    time_conditions = build_time_conditions(start_time, end_time)
    table_name = "klines_#{String.downcase(symbol)}_#{String.downcase(interval)}"

    """
    SELECT open, high, low, close, volume, close_time, quote_asset_volume, number_of_trades, taker_buy_base_asset_volume, taker_buy_quote_asset_volume,  timestamp
    FROM #{table_name} #{if time_conditions != "", do: "WHERE #{time_conditions}"}
    ORDER BY timestamp DESC LIMIT #{limit}
    """
  end

  defp build_time_conditions(nil, nil), do: ""
  defp build_time_conditions(start_time, nil), do: "timestamp >= #{start_time}"
  defp build_time_conditions(nil, end_time), do: "timestamp <= #{end_time}"

  defp build_time_conditions(start_time, end_time),
    do: "timestamp >= #{start_time} AND timestamp <= #{end_time}"

  @doc """
  Saves kline tuples to QuestDB using the REST API.

  ## Parameters
    - symbol: The trading pair symbol (e.g., "BTCUSDT")
    - interval: The interval between candlesticks (e.g., "1h", "4h", "1d")
    - klines: A list of kline tuples

  ## Examples
      iex>
      lines = [[
      1_499_040_000_000,
      "0.01634790",
      "0.80000000",
      "0.01575800",
      "0.01577100",
      "148976.11427815",
      1_499_644_799_999,
      "2434.19055334",
      308,
      "1756.87402397",
      "28.46694368",
      "17928899.62484339"
    ]]
    BeamBot.Exchanges.Infrastructure.Adapters.QuestDB.QuestDBRestAdapter.save_klines_tuples("BTCUSDT", "1h", lines)
    {:ok, "1}
  """
  @impl true
  def save_klines_tuples(symbol, interval, klines) do
    table_name = "klines_#{String.downcase(symbol)}_#{String.downcase(interval)}"

    klines
    |> Enum.map_join("\n", fn [
                                open_time,
                                open,
                                high,
                                low,
                                close,
                                volume,
                                close_time,
                                quote_volume,
                                trades,
                                taker_buy_base,
                                taker_buy_quote,
                                ignore
                              ] ->
      "#{table_name} open=#{open},high=#{high},low=#{low},close=#{close},volume=#{volume},quote_asset_volume=#{quote_volume},taker_buy_base_asset_volume=#{taker_buy_base},taker_buy_quote_asset_volume=#{taker_buy_quote},number_of_trades=#{trades},close_time=#{close_time},ignore=#{ignore} #{open_time}000000"
    end)
    |> BeamBot.InfluxTCPClient.send_line()
    |> case do
      :ok ->
        {:ok, length(klines)}

      {:error, reason} ->
        {:error, "Failed to save klines: #{inspect(reason)}"}
    end
  end
end
