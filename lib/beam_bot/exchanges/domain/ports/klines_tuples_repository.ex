defmodule BeamBot.Exchanges.Domain.Ports.KlinesTuplesRepository do
  @moduledoc """
  Defines the behavior for repositories that store and retrieve klines data as tuples.
  This is a more memory-efficient alternative to the standard KlinesRepository.
  """

  @type kline_tuple :: {
          String.t(),
          String.t(),
          String.t(),
          DateTime.t(),
          Decimal.t(),
          Decimal.t(),
          Decimal.t(),
          Decimal.t(),
          Decimal.t(),
          Decimal.t() | nil,
          integer() | nil,
          Decimal.t() | nil,
          Decimal.t() | nil,
          Decimal.t() | nil
        }

  @doc """
  Stores a list of kline tuples in the database.
  Returns {:ok, count} on success or {:error, reason} on failure.
  """
  @callback store_klines_tuples([kline_tuple()]) :: {:ok, integer()} | {:error, String.t()}

  @doc """
  Retrieves kline tuples for a given symbol and interval.
  Optionally filters by time range and limits the number of results.
  """
  @callback get_klines_tuples(
              symbol :: String.t(),
              interval :: String.t(),
              limit :: integer(),
              start_time :: DateTime.t() | nil,
              end_time :: DateTime.t() | nil
            ) :: {:ok, [kline_tuple()]} | {:error, String.t()}

  @doc """
  Retrieves the latest kline tuple for a given symbol and interval.
  """
  @callback get_latest_kline_tuple(
              symbol :: String.t(),
              interval :: String.t()
            ) :: {:ok, kline_tuple() | nil} | {:error, String.t()}

  @doc """
  Deletes kline tuples for a given symbol and interval within a time range.
  """
  @callback delete_klines_tuples(
              symbol :: String.t(),
              interval :: String.t(),
              start_time :: DateTime.t(),
              end_time :: DateTime.t()
            ) :: {:ok, integer()} | {:error, String.t()}
end
