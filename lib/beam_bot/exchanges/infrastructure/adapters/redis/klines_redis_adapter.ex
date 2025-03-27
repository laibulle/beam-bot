defmodule BeamBot.Exchanges.Infrastructure.Adapters.Redis.KlinesRedisAdapter do
  @moduledoc """
  Redis TimeSeries adapter for storing and retrieving klines (candlestick) data.
  Uses Redis TimeSeries to efficiently store and query historical price data.
  """

  require Logger

  @redis_client Application.compile_env(:beam_bot, :redis_client)

  @doc """
  Stores klines data in Redis TimeSeries.
  Each kline is stored as a separate time series with the following format:
  - Key: klines:{symbol}:{interval}:{timestamp}
  - Value: [open, high, low, close, volume, ...] as a JSON string

  ## Parameters
    - symbol: The trading pair symbol (e.g., "BTCUSDT")
    - interval: The interval between candlesticks (e.g., "1h", "4h", "1d")
    - klines: List of kline data in Binance format

  ## Returns
    - {:ok, :stored} on success
    - {:error, reason} on failure

  ## Examples
  iex > BeamBot.Exchanges.Infrastructure.Adapters.Redis.KlinesRedisAdapter.store_klines("BTCUSDT", "1h", [[1716864000000, 20000, 20000, 20000, 20000, 10000]])
  """
  def store_klines(symbol, interval, klines) when is_list(klines) do
    results =
      Enum.map(klines, fn [timestamp, open, high, low, close, volume | rest] ->
        key = "klines:#{symbol}:#{interval}:#{timestamp}"
        value = Jason.encode!([open, high, low, close, volume | rest])

        case @redis_client.ts_add(key, timestamp, value) do
          {:ok, _} -> {:ok, key}
          {:error, error} -> {:error, error}
          error -> {:error, error}
        end
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      {:error, error} ->
        Logger.error("Failed to store klines: #{inspect(error)}")
        {:error, "Failed to store klines: #{inspect(error)}"}

      nil ->
        {:ok, :stored}
    end
  rescue
    error ->
      Logger.error("Failed to store klines: #{inspect(error)}")
      {:error, "Failed to store klines: #{inspect(error)}"}
  end

  @doc """
  Retrieves klines data from Redis TimeSeries.
  Returns data in the same format as Binance's get_klines endpoint.

  ## Parameters
    - symbol: The trading pair symbol (e.g., "BTCUSDT")
    - interval: The interval between candlesticks (e.g., "1h", "4h", "1d")
    - start_time: Start time in milliseconds (optional)
    - end_time: End time in milliseconds (optional)
    - limit: Maximum number of klines to return (default: 500)

  ## Returns
    - {:ok, klines} on success, where klines is a list of kline data
    - {:error, reason} on failure

  ## Examples
  iex > BeamBot.Exchanges.Infrastructure.Adapters.Redis.KlinesRedisAdapter.get_klines("BTCUSDT", "1h")
  """
  def get_klines(symbol, interval, limit \\ 500, start_time \\ nil, end_time \\ nil) do
    pattern = "klines:#{symbol}:#{interval}:*"

    case @redis_client.keys(pattern) do
      {:ok, keys} ->
        klines =
          keys
          |> Enum.map(fn key ->
            @redis_client.ts_get(key) |> decode_values()
          end)
          |> Enum.reject(&is_nil/1)
          |> Enum.sort_by(&List.first/1)
          |> filter_by_time_range(start_time, end_time)
          |> Enum.take(limit)

        {:ok, klines}

      {:error, error} ->
        Logger.error("Failed to retrieve klines: #{inspect(error)}")
        {:error, "Failed to retrieve klines: #{inspect(error)}"}

      error ->
        Logger.error("Failed to retrieve klines: #{inspect(error)}")
        {:error, "Failed to retrieve klines: #{inspect(error)}"}
    end
  rescue
    error ->
      Logger.error("Failed to retrieve klines: #{inspect(error)}")
      {:error, "Failed to retrieve klines: #{inspect(error)}"}
  end

  defp decode_values({:ok, {timestamp, value}}) do
    case Jason.decode!(value) do
      [open, high, low, close, volume | rest] ->
        [timestamp, open, high, low, close, volume | rest]
    end
  end

  defp decode_values(_) do
    nil
  end

  defp filter_by_time_range(klines, nil, nil), do: klines

  defp filter_by_time_range(klines, start_time, nil) do
    Enum.filter(klines, fn [timestamp | _] -> timestamp >= start_time end)
  end

  defp filter_by_time_range(klines, nil, end_time) do
    Enum.filter(klines, fn [timestamp | _] -> timestamp <= end_time end)
  end

  defp filter_by_time_range(klines, start_time, end_time) do
    Enum.filter(klines, fn [timestamp | _] ->
      timestamp >= start_time and timestamp <= end_time
    end)
  end
end
