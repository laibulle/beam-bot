defmodule BeamBot.Exchanges.Infrastructure.Ecto.KlinesRepositoryEcto do
  @moduledoc """
  Repository for storing and retrieving klines data using TimescaleDB.
  """

  import Ecto.Query
  alias BeamBot.Exchanges.Domain.Kline
  alias BeamBot.Repo

  @doc """
  Stores a list of klines in the database.

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

      iex> BeamBot.Exchanges.Infrastructure.Ecto.KlinesRepositoryEcto.store_klines(klines)
      {:ok, 10}

      iex> store_klines(klines)
      {:error, "Failed to store klines: reason"}
  """
  def store_klines(klines) when is_list(klines) do
    klines_maps =
      Enum.map(klines, fn kline ->
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
      end)

    {n, _} =
      Repo.insert_all(
        Kline,
        klines_maps,
        on_conflict: :nothing,
        conflict_target: [:symbol, :platform, :interval, :timestamp]
      )

    {:ok, n}
  rescue
    error ->
      {:error, "Failed to store klines: #{inspect(error)}"}
  end

  # Private function to convert string values to Decimal types
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

  @doc """
  Retrieves klines for a given symbol and interval.
  Optionally filters by time range and limits the number of results.
  """
  def get_klines(symbol, interval, limit \\ 500, start_time \\ nil, end_time \\ nil) do
    result =
      Kline
      |> where([k], k.symbol == ^symbol and k.interval == ^interval)
      |> filter_by_time_range(start_time, end_time)
      |> order_by([k], desc: k.timestamp)
      |> limit(^limit)
      |> Repo.all()

    {:ok, result}
  rescue
    error ->
      {:error, "Failed to retrieve klines: #{inspect(error)}"}
  end

  @doc """
  Retrieves the latest kline for a given symbol and interval.
  """
  def get_latest_kline(symbol, interval) do
    Kline
    |> where([k], k.symbol == ^symbol and k.interval == ^interval)
    |> order_by([k], desc: k.timestamp)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> {:ok, nil}
      kline -> {:ok, kline}
    end
  rescue
    error ->
      {:error, "Failed to retrieve latest kline: #{inspect(error)}"}
  end

  @doc """
  Deletes klines for a given symbol and interval within a time range.
  """
  def delete_klines(symbol, interval, start_time, end_time) do
    Kline
    |> where([k], k.symbol == ^symbol and k.interval == ^interval)
    |> filter_by_time_range(start_time, end_time)
    |> Repo.delete_all()
    |> case do
      {n, _} -> {:ok, n}
      error -> {:error, "Failed to delete klines: #{inspect(error)}"}
    end
  rescue
    error ->
      {:error, "Failed to delete klines: #{inspect(error)}"}
  end

  defp filter_by_time_range(query, nil, nil), do: query

  defp filter_by_time_range(query, start_time, nil),
    do: where(query, [k], k.timestamp >= ^start_time)

  defp filter_by_time_range(query, nil, end_time), do: where(query, [k], k.timestamp <= ^end_time)

  defp filter_by_time_range(query, start_time, end_time),
    do: where(query, [k], k.timestamp >= ^start_time and k.timestamp <= ^end_time)
end
