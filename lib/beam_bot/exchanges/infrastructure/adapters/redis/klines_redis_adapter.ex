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

        # Store each value as a separate time series
        with {:ok, _} <- @redis_client.ts_add("#{key}:open", timestamp, open),
             {:ok, _} <- @redis_client.ts_add("#{key}:high", timestamp, high),
             {:ok, _} <- @redis_client.ts_add("#{key}:low", timestamp, low),
             {:ok, _} <- @redis_client.ts_add("#{key}:close", timestamp, close),
             {:ok, _} <- @redis_client.ts_add("#{key}:volume", timestamp, volume) do
          {:ok, key}
        else
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
      {:ok, keys} -> process_keys(keys, symbol, interval, limit, start_time, end_time)
      {:error, error} -> handle_error(error)
      error -> handle_error(error)
    end
  rescue
    error -> handle_error(error)
  end

  defp process_keys(keys, symbol, interval, limit, start_time, end_time) do
    timestamps = extract_timestamps(keys, start_time, end_time, limit)
    klines = fetch_klines(timestamps, symbol, interval)
    {:ok, klines}
  end

  defp extract_timestamps(keys, start_time, end_time, limit) do
    keys
    |> Enum.map(&extract_timestamp/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
    |> filter_by_time_range(start_time, end_time)
    |> Enum.take(limit)
  end

  defp extract_timestamp(key) do
    case Regex.run(~r/klines:.*?:.*?:(\d+):/, key) do
      [_, timestamp] -> String.to_integer(timestamp)
      _ -> nil
    end
  end

  defp fetch_klines(timestamps, symbol, interval) do
    timestamps
    |> Enum.map(fn timestamp -> fetch_kline(timestamp, symbol, interval) end)
    |> Enum.reject(&is_nil/1)
  end

  defp fetch_kline(timestamp, symbol, interval) do
    key_prefix = "klines:#{symbol}:#{interval}:#{timestamp}"

    with {:ok, {_, open}} <- @redis_client.ts_get("#{key_prefix}:open"),
         {:ok, {_, high}} <- @redis_client.ts_get("#{key_prefix}:high"),
         {:ok, {_, low}} <- @redis_client.ts_get("#{key_prefix}:low"),
         {:ok, {_, close}} <- @redis_client.ts_get("#{key_prefix}:close"),
         {:ok, {_, volume}} <- @redis_client.ts_get("#{key_prefix}:volume") do
      [timestamp, open, high, low, close, volume]
    else
      _ -> nil
    end
  end

  defp handle_error(error) do
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
