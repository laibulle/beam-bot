defmodule BeamBot.Exchanges.Infrastructure.Adapters.Exchanges.BinanceReqAdapter do
  @moduledoc """
  An adapter for interacting with the Binance API using Req.
  """

  @behaviour BeamBot.Exchanges.Domain.Ports.ExchangePort

  require Logger

  alias BeamBot.Exchanges.Domain.PlatformCredentials
  alias Decimal

  @base_url Application.compile_env(:beam_bot, :binance_base_url, "https://api.binance.com")

  @doc """
  Creates a new BinanceReqAdapter struct.

  Fetches the current exchange information from Binance.
  ## Examples

      iex> BeamBot.Infrastructure.Adapters.BinanceReqAdapter.get_exchange_info()
      {:ok, %{symbols: [%{baseAsset: "BTC", quoteAsset: "USDT", symbol: "BTCUSDT", baseAssetPrecision: 8, quotePrecision: 8, orderTypes: ["LIMIT", "MARKET"]}}
  """
  def get_exchange_info do
    request("/api/v3/exchangeInfo")
  end

  @doc """
  Fetches ticker information for a specific symbol.

  ## Examples

      iex> BeamBot.Infrastructure.Adapters.BinanceReqAdapter.get_ticker_price("BTCUSDT")
      {:ok, %{symbol: "BTCUSDT", price: "42000.00"}}
  """
  def get_ticker_price(symbol) do
    params = %{symbol: symbol}

    request("/api/v3/ticker/price", params)
  end

  @doc """
  Fetches account information. Requires API key and signature.

  ## Examples

      iex> {:ok, platform_credentials} = BeamBot.Exchanges.Infrastructure.Adapters.Ecto.PlatformCredentialsRepositoryEcto.get_by_user_id_and_exchange_id(1, 1)
      iex> BeamBot.Exchanges.Infrastructure.Adapters.Exchanges.BinanceReqAdapter.get_account_info(platform_credentials)
      {:ok, account_info}
  """
  def get_account_info(%PlatformCredentials{api_key: api_key, api_secret: api_secret}) do
    signed_params =
      sign_params(%{timestamp: :os.system_time(:millisecond), api_secret: api_secret})

    request("/api/v3/account", signed_params, api_key)
  end

  @doc """
  Fetches historical klines/candlestick data for a symbol.

  ## Parameters
    - symbol: The trading pair symbol (e.g., "BTCUSDT")
    - interval: The interval between candlesticks (e.g., "1h", "4h", "1d")
    - limit: Number of candlesticks to fetch (default: 500, max: 1000)
    - start_time: Start time in milliseconds (optional)
    - end_time: End time in milliseconds (optional)

  ## Examples

      iex> BeamBot.Infrastructure.Adapters.BinanceReqAdapter.get_klines("BTCUSDT", "1h")
      {:ok, [[timestamp, open, high, low, close, volume, ...], ...]}
  """
  def get_klines(symbol, interval, limit \\ 500, start_time \\ nil, end_time \\ nil) do
    params =
      %{
        symbol: symbol,
        interval: interval,
        limit: limit
      }
      |> maybe_add_time_range(start_time, end_time)

    request("/api/v3/klines", params)
  end

  @doc """
  Places a new order on Binance.

  ## Parameters
    * params - Map containing order parameters:
      * symbol - The trading pair symbol (e.g., "BTCUSDT")
      * side - The order side ("BUY" or "SELL")
      * type - The order type ("LIMIT" or "MARKET")
      * quantity - The quantity to trade (as Decimal)
      * price - The price per unit as Decimal (required for LIMIT orders)
      * time_in_force - Time in force type (required for LIMIT orders, e.g., "GTC", "IOC", "FOK")

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
      ...> }
      iex> BeamBot.Infrastructure.Adapters.BinanceReqAdapter.place_order(params)
      {:ok, %{orderId: 123456, status: "NEW", ...}}

      iex> market_params = %{
      ...>   symbol: "BTCUSDT",
      ...>   side: "SELL",
      ...>   type: "MARKET",
      ...>   quantity: Decimal.new("0.001")
      ...> }
      iex> BeamBot.Infrastructure.Adapters.BinanceReqAdapter.place_order(market_params)
      {:ok, %{orderId: 123457, status: "FILLED", ...}}
  """
  def place_order(
        %{
          symbol: symbol,
          side: side,
          type: type,
          quantity: quantity
        } = params,
        %PlatformCredentials{api_key: api_key, api_secret: api_secret}
      ) do
    timestamp = :os.system_time(:millisecond)

    base_params = %{
      symbol: symbol,
      side: side,
      type: type,
      quantity: Decimal.to_string(quantity),
      timestamp: timestamp
    }

    params =
      base_params
      |> maybe_add_limit_params(type, Map.get(params, :price))
      |> Map.put(:api_secret, api_secret)

    signed_params = sign_params(params)
    request("/api/v3/order", signed_params, api_key)
  end

  defp maybe_add_limit_params(params, "LIMIT", price) when not is_nil(price) do
    params
    |> Map.put(:price, Decimal.to_string(price))
    |> Map.put(:timeInForce, Map.get(params, :time_in_force))
  end

  defp maybe_add_limit_params(params, "MARKET", _price), do: params

  defp maybe_add_time_range(params, nil, nil), do: params
  defp maybe_add_time_range(params, start_time, nil), do: Map.put(params, :startTime, start_time)
  defp maybe_add_time_range(params, nil, end_time), do: Map.put(params, :endTime, end_time)

  defp maybe_add_time_range(params, start_time, end_time) do
    params
    |> Map.put(:startTime, start_time)
    |> Map.put(:endTime, end_time)
  end

  defp request(endpoint, params \\ %{}, api_key \\ nil) do
    url = @base_url <> endpoint

    headers =
      if api_key do
        ["X-MBX-APIKEY": api_key]
      else
        []
      end

    Req.get!(url, params: params, headers: headers)
    |> handle_response()
  end

  defp handle_response(%Req.Response{status: status, body: body}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_response(%Req.Response{status: status, body: body}) do
    Logger.error("Request failed with status #{status}: #{inspect(body)}")
    {:error, %{status: status, body: body}}
  end

  defp sign_params(params) do
    # Remove api_secret from params before generating query string
    params_without_secret = Map.delete(params, :api_secret)

    # Sort parameters alphabetically and generate query string
    query_string =
      params_without_secret
      |> Enum.sort_by(fn {key, _} -> key end)
      |> Enum.map_join("&", fn {key, value} -> "#{key}=#{value}" end)

    # Generate signature using the query string
    signature =
      :crypto.mac(:hmac, :sha256, params.api_secret, query_string) |> Base.encode16(case: :lower)

    # Add signature to params and remove api_secret
    params_without_secret
    |> Map.put(:signature, signature)
  end
end
