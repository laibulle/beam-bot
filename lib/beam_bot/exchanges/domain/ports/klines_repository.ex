defmodule BeamBot.Exchanges.Domain.Ports.KlinesRepository do
  @moduledoc """
  Behaviour specification for klines repository implementations.
  Defines the contract for storing and retrieving candlestick (klines) data.
  """

  @doc """
  Stores a list of klines in the repository.

  ## Parameters
    * klines - List of %BeamBot.Exchanges.Domain.Kline{} structs

  ## Returns
    * `{:ok, number_of_stored_klines}` - On successful storage
    * `{:error, reason}` - On failure
  """
  @callback store_klines(klines :: list()) :: {:ok, non_neg_integer()} | {:error, String.t()}

  @doc """
  Retrieves klines for a given symbol and interval.

  ## Parameters
    * symbol - The trading pair symbol (e.g., "BTCUSDT")
    * interval - The kline interval (e.g., "1m", "5m", "1h")
    * limit - Maximum number of klines to return (optional, defaults to 500)

  ## Returns
    * `{:ok, list_of_klines}` - On successful retrieval
    * `{:error, reason}` - On failure
  """
  @callback get_klines(
              symbol :: String.t(),
              interval :: String.t(),
              limit :: non_neg_integer() | nil
            ) :: {:ok, list()} | {:error, String.t()}

  @doc """
  Retrieves klines for a given symbol and interval.

  ## Parameters
    * symbol - The trading pair symbol (e.g., "BTCUSDT")
    * interval - The kline interval (e.g., "1m", "5m", "1h")
    * limit - Maximum number of klines to return (optional, defaults to 500)
    * start_time - Start time filter (optional)
    * end_time - End time filter (optional)

  ## Returns
    * `{:ok, list_of_klines}` - On successful retrieval
    * `{:error, reason}` - On failure
  """
  @callback get_klines(
              symbol :: String.t(),
              interval :: String.t(),
              limit :: non_neg_integer() | nil,
              start_time :: DateTime.t() | nil,
              end_time :: DateTime.t() | nil
            ) :: {:ok, list()} | {:error, String.t()}

  @doc """
  Retrieves the latest kline for a given symbol and interval.

  ## Parameters
    * symbol - The trading pair symbol (e.g., "BTCUSDT")
    * interval - The kline interval (e.g., "1m", "5m", "1h")

  ## Returns
    * `{:ok, kline}` - On successful retrieval
    * `{:ok, nil}` - When no kline is found
    * `{:error, reason}` - On failure
  """
  @callback get_latest_kline(symbol :: String.t(), interval :: String.t()) ::
              {:ok, struct() | nil} | {:error, String.t()}

  @doc """
  Deletes klines for a given symbol and interval within a time range.

  ## Parameters
    * symbol - The trading pair symbol (e.g., "BTCUSDT")
    * interval - The kline interval (e.g., "1m", "5m", "1h")
    * start_time - Start time of the range to delete
    * end_time - End time of the range to delete

  ## Returns
    * `{:ok, number_of_deleted_klines}` - On successful deletion
    * `{:error, reason}` - On failure
  """
  @callback delete_klines(
              symbol :: String.t(),
              interval :: String.t(),
              start_time :: DateTime.t(),
              end_time :: DateTime.t()
            ) :: {:ok, non_neg_integer()} | {:error, String.t()}
end
