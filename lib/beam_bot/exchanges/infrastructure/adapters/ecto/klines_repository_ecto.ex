defmodule BeamBot.Exchanges.Infrastructure.Ecto.KlinesRepositoryEcto do
  @moduledoc """
  Repository for storing and retrieving klines data using TimescaleDB.
  """

  import Ecto.Query
  alias BeamBot.Exchanges.Domain.Models.Kline
  alias BeamBot.Repo

  @doc """
  Stores a list of klines in the database.
  """
  def store_klines(klines) when is_list(klines) do
    {n, _} = Repo.insert_all(Kline, klines, on_conflict: :replace_all)
    {:ok, n}
  rescue
    error ->
      {:error, "Failed to store klines: #{inspect(error)}"}
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
