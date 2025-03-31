defmodule BeamBot.Exchanges.Infrastructure.Adapters.Pg.KlinesRepositoryPg do
  @moduledoc """
  Repository for storing and retrieving klines data using raw PostgreSQL queries with TimescaleDB.
  This implementation aims to provide better performance than the Ecto version by using direct SQL queries.
  """

  @behaviour BeamBot.Exchanges.Domain.Ports.KlinesRepository

  require Logger
  alias BeamBot.Exchanges.Domain.Kline
  alias BeamBot.Repo

  @doc """
  Stores a list of klines in the database using a raw SQL query for better performance.

  ## Examples

      iex> klines = [
        %BeamBot.Exchanges.Domain.Kline{
          symbol: "BTCUSDT",
          platform: "binance",
          interval: "1m",
          timestamp: ~U[2021-01-01 00:00:00Z],
          open: Decimal.new("10000.0"),
          high: Decimal.new("10000.0"),
          low: Decimal.new("9000.0"),
          close: Decimal.new("10000.0"),
          volume: Decimal.new("1000.0"),
          quote_volume: Decimal.new("10000.0"),
          trades_count: 1000,
          taker_buy_base_volume: Decimal.new("1000.0"),
          taker_buy_quote_volume: Decimal.new("10000.0"),
          ignore: Decimal.new("17928899.62484339")
        }
      ]

      iex> BeamBot.Exchanges.Infrastructure.Adapters.Pg.KlinesRepositoryPg.store_klines(klines)
      {:ok, 10}

      iex> store_klines(klines)
      {:error, "Failed to store klines: reason"}
  """
  def store_klines([]), do: {:ok, 0}

  def store_klines(klines) when is_list(klines) do
    case validate_klines(klines) do
      :ok ->
        values =
          Enum.with_index(klines)
          |> Enum.map_join(",", fn {kline, index} ->
            kline_map =
              kline
              |> Map.from_struct()
              |> Map.take([
                :symbol,
                :platform,
                :interval,
                :timestamp,
                :open,
                :high,
                :low,
                :close,
                :volume,
                :quote_volume,
                :trades_count,
                :taker_buy_base_volume,
                :taker_buy_quote_volume,
                :ignore
              ])
              |> convert_string_to_decimal()

            "('#{kline_map.symbol}', '#{kline_map.platform}', '#{kline_map.interval}', $#{index + 1}, #{kline_map.open}, #{kline_map.high}, #{kline_map.low}, #{kline_map.close}, #{kline_map.volume}, #{kline_map.quote_volume}, #{kline_map.trades_count}, #{kline_map.taker_buy_base_volume}, #{kline_map.taker_buy_quote_volume}, #{kline_map.ignore})"
          end)

        query = """
        INSERT INTO klines (symbol, platform, interval, timestamp, open, high, low, close, volume, quote_volume, trades_count, taker_buy_base_volume, taker_buy_quote_volume, ignore)
        VALUES #{values}
        ON CONFLICT (symbol, platform, interval, timestamp) DO NOTHING
        """

        timestamps = Enum.map(klines, & &1.timestamp)

        case Repo.query(query, timestamps) do
          {:ok, %{num_rows: n}} -> {:ok, n}
          {:error, error} -> {:error, "Failed to store klines: #{inspect(error)}"}
        end

      {:error, reason} ->
        {:error, "Invalid kline data: #{reason}"}
    end
  end

  def store_klines(_), do: {:error, "Invalid input: expected a list of klines"}

  @doc """
  Retrieves klines for a given symbol and interval using a raw SQL query.
  Optionally filters by time range and limits the number of results.

  ## Parameters
    - symbol: The symbol to retrieve klines for
    - interval: The interval to retrieve klines for
    - limit: The maximum number of klines to retrieve
    - start_time: The start time to filter by
    - end_time: The end time to filter by

  ## Examples
      iex> BeamBot.Exchanges.Infrastructure.Adapters.Pg.KlinesRepositoryPg.get_klines("BTCUSDT", "1h")
      {:ok, [
        %BeamBot.Exchanges.Domain.Kline{
          symbol: "BTCUSDT",
          interval: "1h",
          timestamp: ~U[2021-01-01 00:00:00Z],
          open: Decimal.new("10000.0"),
          high: Decimal.new("10000.0"),
          low: Decimal.new("9000.0"),
          close: Decimal.new("10000.0"),
          volume: Decimal.new("1000.0"),
          quote_volume: Decimal.new("10000.0"),
          trades_count: 1000,
          taker_buy_base_volume: Decimal.new("1000.0"),
          taker_buy_quote_volume: Decimal.new("10000.0"),
          ignore: Decimal.new("17928899.62484339")
        }
      ]}
  """
  def get_klines(symbol, interval, limit \\ 500, start_time \\ nil, end_time \\ nil) do
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
      {:ok, %{rows: rows, columns: cols}} ->
        {:ok, Enum.map(rows, &Repo.load(Kline, {cols, &1}))}

      {:error, error} ->
        {:error, "Failed to retrieve klines: #{inspect(error)}"}
    end
  end

  @doc """
  Retrieves the latest kline for a given symbol and interval using a raw SQL query.
  """
  def get_latest_kline(symbol, interval) do
    query = """
    SELECT symbol, platform, interval, timestamp, open, high, low, close, volume, quote_volume, trades_count, taker_buy_base_volume, taker_buy_quote_volume, ignore
    FROM klines
    WHERE symbol = $1 AND interval = $2
    ORDER BY timestamp DESC
    LIMIT 1
    """

    case Repo.query(query, [symbol, interval]) do
      {:ok, %{rows: [row | _], columns: cols}} ->
        {:ok, Repo.load(Kline, {cols, row})}

      {:ok, %{rows: []}} ->
        {:ok, nil}

      {:error, error} ->
        {:error, "Failed to retrieve latest kline: #{inspect(error)}"}
    end
  end

  @doc """
  Deletes klines for a given symbol and interval within a time range using a raw SQL query.
  """
  def delete_klines(symbol, interval, start_time, end_time) do
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

  defp validate_klines(klines) do
    Enum.reduce_while(klines, :ok, fn kline, acc ->
      case validate_kline(kline) do
        :ok -> {:cont, acc}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_kline(%Kline{} = kline) do
    with :ok <- validate_required_string_fields(kline),
         :ok <- validate_required_decimal_fields(kline),
         :ok <- validate_required_integer_fields(kline) do
      validate_required_integer_fields(kline)
    end
  end

  defp validate_kline(_), do: {:error, "invalid kline struct"}

  defp validate_required_string_fields(%Kline{} = kline) do
    string_fields = [
      {:symbol, kline.symbol},
      {:platform, kline.platform},
      {:interval, kline.interval}
    ]

    Enum.reduce_while(string_fields, :ok, fn {field, value}, acc ->
      if is_nil(value) or value == "" do
        {:halt, {:error, "#{field} is required"}}
      else
        {:cont, acc}
      end
    end)
  end

  defp validate_required_decimal_fields(%Kline{} = kline) do
    decimal_fields = [
      {:open, kline.open},
      {:high, kline.high},
      {:low, kline.low},
      {:close, kline.close},
      {:volume, kline.volume},
      {:quote_volume, kline.quote_volume},
      {:taker_buy_base_volume, kline.taker_buy_base_volume},
      {:taker_buy_quote_volume, kline.taker_buy_quote_volume},
      {:ignore, kline.ignore}
    ]

    Enum.reduce_while(decimal_fields, :ok, fn {field, value}, acc ->
      if is_nil(value) do
        {:halt, {:error, "#{field} is required"}}
      else
        {:cont, acc}
      end
    end)
  end

  defp validate_required_integer_fields(%Kline{} = kline) do
    integer_fields = [
      {:trades_count, kline.trades_count}
    ]

    Enum.reduce_while(integer_fields, :ok, fn {field, value}, acc ->
      if is_nil(value) do
        {:halt, {:error, "#{field} is required"}}
      else
        {:cont, acc}
      end
    end)
  end

  defp convert_string_to_decimal(map) do
    decimal_fields = [
      :open,
      :high,
      :low,
      :close,
      :volume,
      :quote_volume,
      :taker_buy_base_volume,
      :taker_buy_quote_volume,
      :ignore
    ]

    Enum.reduce(decimal_fields, map, fn field, acc ->
      case Map.get(acc, field) do
        nil -> acc
        value when is_binary(value) -> Map.put(acc, field, Decimal.new(value))
        value when is_number(value) -> Map.put(acc, field, Decimal.new(to_string(value)))
        # Keep Decimal values as is
        value -> Map.put(acc, field, value)
      end
    end)
  end

  defp build_time_conditions(nil, nil), do: ""
  defp build_time_conditions(_start_time, nil), do: "AND timestamp >= $4"
  defp build_time_conditions(nil, _end_time), do: "AND timestamp <= $4"

  defp build_time_conditions(_start_time, _end_time),
    do: "AND timestamp >= $4 AND timestamp <= $5"
end
