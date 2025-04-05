defmodule BeamBot.Exchanges.Domain.Ports.ExchangePort do
  @moduledoc """
  Behaviour specification for exchange implementations.
  Defines the contract for interacting with cryptocurrency exchanges.
  """

  alias BeamBot.Exchanges.Domain.PlatformCredentials

  @type order_params :: %{
          symbol: String.t(),
          side: String.t(),
          type: String.t(),
          quantity: Decimal.t(),
          price: Decimal.t() | nil,
          time_in_force: String.t() | nil
        }

  @doc """
  Fetches exchange information including available trading pairs and their specifications.

  ## Returns
    * `{:ok, exchange_info}` - On successful retrieval
    * `{:error, reason}` - On failure
  """
  @callback get_exchange_info() :: {:ok, map()} | {:error, String.t()}

  @doc """
  Fetches current price for a trading pair.

  ## Parameters
    * symbol - The trading pair symbol (e.g., "BTCUSDT")

  ## Returns
    * `{:ok, price_info}` - On successful retrieval
    * `{:error, reason}` - On failure
  """
  @callback get_ticker_price(symbol :: String.t()) :: {:ok, map()} | {:error, String.t()}

  @doc """
  Fetches account information. Requires API key and signature.

  ## Parameters
    * credentials - Map containing authentication parameters:
      * api_key - The API key for authentication
      * api_secret - The API secret for signing requests

  ## Returns
    * `{:ok, account_info}` - On successful retrieval
    * `{:error, reason}` - On failure
  """
  @callback get_account_info(credentials :: PlatformCredentials.t()) ::
              {:ok, map()} | {:error, String.t()}

  @doc """
  Fetches historical klines/candlestick data for a symbol.

  ## Parameters
    * symbol - The trading pair symbol (e.g., "BTCUSDT")
    * interval - The interval between candlesticks (e.g., "1h", "4h", "1d")
    * limit - Number of candlesticks to fetch (default: 500, max: 1000)
    * start_time - Start time in milliseconds (optional)
    * end_time - End time in milliseconds (optional)

  ## Returns
    * `{:ok, klines_data}` - On successful retrieval
    * `{:error, reason}` - On failure
  """
  @callback get_klines(
              symbol :: String.t(),
              interval :: String.t(),
              limit :: non_neg_integer(),
              start_time :: integer() | nil,
              end_time :: integer() | nil
            ) :: {:ok, list()} | {:error, String.t()}

  @doc """
  Places a new order on the exchange.

  ## Parameters
    * params - Map containing order parameters:
      * symbol - The trading pair symbol (e.g., "BTCUSDT")
      * side - The order side ("BUY" or "SELL")
      * type - The order type ("LIMIT" or "MARKET")
      * quantity - The quantity to trade (as Decimal)
      * price - The price per unit as Decimal (required for LIMIT orders)
      * time_in_force - Time in force type (required for LIMIT orders, e.g., "GTC", "IOC", "FOK")
    * credentials - Map containing authentication parameters:
      * api_key - The API key for authentication
      * api_secret - The API secret for signing requests

  ## Returns
    * `{:ok, order_info}` - On successful order placement
    * `{:error, reason}` - On failure

  ## Examples
      iex> params = %{
      ...>   symbol: "BTCUSDT",
      ...>   side: "BUY",
      ...>   type: "LIMIT",
      ...>   quantity: Decimal.new("0.001"),
      ...>   price: Decimal.new("50000"),
      ...>   time_in_force: "GTC"
      ...> }
      iex> credentials = %{api_key: "your_api_key", api_secret: "your_api_secret"}
      iex> place_order(params, credentials)
      {:ok, %{orderId: 123456, status: "NEW", ...}}
  """
  @callback place_order(
              params :: order_params(),
              credentials :: PlatformCredentials.t()
            ) :: {:ok, map()} | {:error, String.t()}
end
