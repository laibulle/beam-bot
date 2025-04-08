defmodule BeamBot.Exchanges.Domain.Ports.KlinesTuplesRepository do
  @moduledoc """
  Defines the behavior for repositories that store and retrieve klines data as tuples.
  This is a more memory-efficient alternative to the standard KlinesRepository.
  """

  @type kline_tuple :: list()

  @callback get_klines_tuples(
              symbol :: String.t(),
              interval :: String.t(),
              limit :: integer()
            ) :: {:ok, [kline_tuple()]} | {:error, String.t()}
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

  @callback save_klines_tuples(
              symbol :: String.t(),
              interval :: String.t(),
              klines :: [kline_tuple()]
            ) :: {:ok, [kline_tuple()]} | {:error, String.t()}
end
