defmodule BeamBot.Exchanges.Infrastructure.Adapters.Pg.KlinesTuplesRepositoryPg do
  @moduledoc """
  Repository for storing and retrieving klines data as tuples using raw PostgreSQL queries with TimescaleDB.
  This implementation aims to provide better performance than the Ecto version by using direct SQL queries and tuples.
  """

  @behaviour BeamBot.Exchanges.Domain.Ports.KlinesTuplesRepository

  require Logger
  alias BeamBot.Repo

  @doc """
  Stores a list of kline tuples in the database using a raw SQL query for better performance.
  """
  def store_klines_tuples([]), do: {:ok, 0}

  def store_klines_tuples(klines) when is_list(klines) do
    case validate_klines_tuples(klines) do
      :ok ->
        values =
          Enum.with_index(klines)
          |> Enum.map_join(",", fn {kline, index} ->
            {
              symbol,
              platform,
              interval,
              timestamp,
              open,
              high,
              low,
              close,
              volume,
              quote_volume,
              trades_count,
              taker_buy_base_volume,
              taker_buy_quote_volume,
              ignore
            } = kline

            "('#{symbol}', '#{platform}', '#{interval}', $#{index + 1}, #{open}, #{high}, #{low}, #{close}, #{volume}, #{quote_volume}, #{trades_count}, #{taker_buy_base_volume}, #{taker_buy_quote_volume}, #{ignore})"
          end)

        query = """
        INSERT INTO klines (symbol, platform, interval, timestamp, open, high, low, close, volume, quote_volume, trades_count, taker_buy_base_volume, taker_buy_quote_volume, ignore)
        VALUES #{values}
        ON CONFLICT (symbol, platform, interval, timestamp) DO NOTHING
        """

        timestamps =
          Enum.map(klines, fn {_, _, _, timestamp, _, _, _, _, _, _, _, _, _, _} -> timestamp end)

        case Repo.query(query, timestamps) do
          {:ok, %{num_rows: n}} -> {:ok, n}
          {:error, error} -> {:error, "Failed to store klines: #{inspect(error)}"}
        end

      {:error, reason} ->
        {:error, "Invalid kline data: #{reason}"}
    end
  end

  def store_klines_tuples(_), do: {:error, "Invalid input: expected a list of klines"}

  @doc """
  Retrieves kline tuples for a given symbol and interval using a raw SQL query.
  """
  def get_klines_tuples(symbol, interval, limit \\ 500, start_time \\ nil, end_time \\ nil) do
    time_conditions = build_time_conditions(start_time, end_time)

    query = """
    SELECT symbol, platform, interval, timestamp, open, high, low, close, volume, quote_volume, trades_count, taker_buy_base_volume, taker_buy_quote_volume, ignore
    FROM klines
    WHERE symbol = $1 AND interval = $2 #{time_conditions}
    ORDER BY timestamp DESC
    LIMIT $3
    """

    params = [symbol, interval, limit]
    params = if start_time, do: params ++ [start_time], else: params
    params = if end_time, do: params ++ [end_time], else: params

    case Repo.query(query, params) do
      {:ok, %{rows: rows}} ->
        tuples =
          Enum.map(rows, fn row ->
            {
              Enum.at(row, 0),
              Enum.at(row, 1),
              Enum.at(row, 2),
              Enum.at(row, 3),
              Enum.at(row, 4),
              Enum.at(row, 5),
              Enum.at(row, 6),
              Enum.at(row, 7),
              Enum.at(row, 8),
              Enum.at(row, 9),
              Enum.at(row, 10),
              Enum.at(row, 11),
              Enum.at(row, 12),
              Enum.at(row, 13)
            }
          end)

        {:ok, tuples}

      {:error, error} ->
        {:error, "Failed to retrieve klines: #{inspect(error)}"}
    end
  end

  @doc """
  Retrieves the latest kline tuple for a given symbol and interval using a raw SQL query.
  """
  def get_latest_kline_tuple(symbol, interval) do
    query = """
    SELECT symbol, platform, interval, timestamp, open, high, low, close, volume, quote_volume, trades_count, taker_buy_base_volume, taker_buy_quote_volume, ignore
    FROM klines
    WHERE symbol = $1 AND interval = $2
    ORDER BY timestamp DESC
    LIMIT 1
    """

    case Repo.query(query, [symbol, interval]) do
      {:ok, %{rows: [row | _]}} ->
        tuple = {
          Enum.at(row, 0),
          Enum.at(row, 1),
          Enum.at(row, 2),
          Enum.at(row, 3),
          Enum.at(row, 4),
          Enum.at(row, 5),
          Enum.at(row, 6),
          Enum.at(row, 7),
          Enum.at(row, 8),
          Enum.at(row, 9),
          Enum.at(row, 10),
          Enum.at(row, 11),
          Enum.at(row, 12),
          Enum.at(row, 13)
        }

        {:ok, tuple}

      {:ok, %{rows: []}} ->
        {:ok, nil}

      {:error, error} ->
        {:error, "Failed to retrieve latest kline: #{inspect(error)}"}
    end
  end

  @doc """
  Deletes kline tuples for a given symbol and interval within a time range using a raw SQL query.
  """
  def delete_klines_tuples(symbol, interval, start_time, end_time) do
    query = """
    DELETE FROM klines
    WHERE symbol = $1 AND interval = $2 AND timestamp >= $3 AND timestamp <= $4
    """

    case Repo.query(query, [symbol, interval, start_time, end_time]) do
      {:ok, %{num_rows: n}} -> {:ok, n}
      {:error, error} -> {:error, "Failed to delete klines: #{inspect(error)}"}
    end
  end

  # Private functions

  defp validate_klines_tuples(klines) do
    Enum.reduce_while(klines, :ok, fn kline, acc ->
      case validate_kline_tuple(kline) do
        :ok -> {:cont, acc}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_kline_tuple({
         symbol,
         platform,
         interval,
         _timestamp,
         open,
         high,
         low,
         close,
         volume,
         _quote_volume,
         trades_count,
         _taker_buy_base_volume,
         _taker_buy_quote_volume,
         _ignore
       }) do
    with :ok <- validate_required_string_fields(symbol, platform, interval),
         :ok <- validate_required_decimal_fields(open, high, low, close, volume) do
      validate_required_integer_fields(trades_count)
    end
  end

  defp validate_kline_tuple(_), do: {:error, "invalid kline tuple"}

  defp validate_required_string_fields(symbol, platform, interval) do
    string_fields = [
      {:symbol, symbol},
      {:platform, platform},
      {:interval, interval}
    ]

    Enum.reduce_while(string_fields, :ok, fn {field, value}, acc ->
      if is_nil(value) or value == "" do
        {:halt, {:error, "#{field} is required"}}
      else
        {:cont, acc}
      end
    end)
  end

  defp validate_required_decimal_fields(open, high, low, close, volume) do
    decimal_fields = [
      {:open, open},
      {:high, high},
      {:low, low},
      {:close, close},
      {:volume, volume}
    ]

    Enum.reduce_while(decimal_fields, :ok, fn {field, value}, acc ->
      if is_nil(value) do
        {:halt, {:error, "#{field} is required"}}
      else
        {:cont, acc}
      end
    end)
  end

  defp validate_required_integer_fields(trades_count) do
    if is_nil(trades_count) do
      {:error, "trades_count is required"}
    else
      :ok
    end
  end

  defp build_time_conditions(nil, nil), do: ""
  defp build_time_conditions(_start_time, nil), do: "AND timestamp >= $4"
  defp build_time_conditions(nil, _end_time), do: "AND timestamp <= $4"

  defp build_time_conditions(_start_time, _end_time),
    do: "AND timestamp >= $4 AND timestamp <= $5"
end
