defmodule BeamBot.Exchanges.Infrastructure.Adapters.Exchanges.BinanceReqAdapter do
  @moduledoc """
  An adapter for interacting with the Binance API using Req.
  """

  @behaviour BeamBot.Exchanges.Domain.Ports.ExchangePort

  require Logger

  alias BeamBot.Exchanges.Domain.PlatformCredentials
  alias BeamBot.Exchanges.Infrastructure.Workers.BinanceMultiRateLimiter
  alias Decimal

  @base_url Application.compile_env(:beam_bot, :binance_base_url, "https://api.binance.com")

  @i_1m_interval_ms 1 * 60 * 1000
  @i_3m_interval_ms 3 * 60 * 1000
  @i_5m_interval_ms 5 * 60 * 1000
  @i_15m_interval_ms 15 * 60 * 1000
  @i_30m_interval_ms 30 * 60 * 1000
  @i_1h_interval_ms 1 * 60 * 60 * 1000
  @i_2h_interval_ms 2 * 60 * 60 * 1000
  @i_4h_interval_ms 4 * 60 * 60 * 1000
  @i_6h_interval_ms 6 * 60 * 60 * 1000
  @i_8h_interval_ms 8 * 60 * 60 * 1000
  @i_12h_interval_ms 12 * 60 * 60 * 1000
  @i_1d_interval_ms 1 * 24 * 60 * 60 * 1000
  @i_3d_interval_ms 3 * 24 * 60 * 60 * 1000
  @i_1w_interval_ms 7 * 24 * 60 * 60 * 1000
  # Using 30 days for a month approximation
  @i_1month_interval_ms 30 * 24 * 60 * 60 * 1000

  @doc """
  Creates a new BinanceReqAdapter struct.

  Fetches the current exchange information from Binance.
  ## Examples

      iex> BeamBot.Infrastructure.Adapters.BinanceReqAdapter.get_exchange_info()
      {:ok, %{symbols: [%{baseAsset: "BTC", quoteAsset: "USDC", symbol: "BTCUSDT", baseAssetPrecision: 8, quotePrecision: 8, orderTypes: ["LIMIT", "MARKET"]}}
  """
  def get_exchange_info do
    request("/api/v3/exchangeInfo", %{}, %{weight: 20})
  end

  @doc """
  Fetches the wallet balance for a specific wallet type.
  ## Examples

      iex> {:ok, platform_credentials} = BeamBot.Exchanges.Infrastructure.Adapters.Ecto.PlatformCredentialsRepositoryEcto.get_by_user_id_and_exchange_id(1, 1)
      iex> BeamBot.Exchanges.Infrastructure.Adapters.Exchanges.BinanceReqAdapter.get_assets(platform_credentials)
  """
  def get_assets(%PlatformCredentials{api_key: api_key, api_secret: api_secret}) do
    headers = [{"X-MBX-APIKEY", api_key}]

    signed_params =
      sign_params(%{timestamp: :os.system_time(:millisecond), api_secret: api_secret})

    Req.post!("#{@base_url}/sapi/v3/asset/getUserAsset",
      params: signed_params,
      headers: headers
    )
    |> case do
      %{status: 200, body: body} -> {:ok, body}
      %{status: status, body: body} -> {:error, %{status: status, body: body}}
    end
  end

  @doc """
  Fetches the wallet balance for a specific wallet type.
  ## Examples

      iex> {:ok, platform_credentials} = BeamBot.Exchanges.Infrastructure.Adapters.Ecto.PlatformCredentialsRepositoryEcto.get_by_user_id_and_exchange_id(1, 1)
      iex> BeamBot.Exchanges.Infrastructure.Adapters.Exchanges.BinanceReqAdapter.get_transactions(platform_credentials, %{start_time: DateTime.utc_now() |> DateTime.add(-120, :day), end_time: DateTime.utc_now() |> DateTime.add(-90, :day)})
  """
  def get_transactions(%PlatformCredentials{api_key: api_key, api_secret: api_secret}, %{
        start_time: start_time,
        end_time: end_time
      }) do
    now = :os.system_time(:millisecond)

    params = [
      timestamp: now,
      startTime: start_time |> DateTime.to_unix(:millisecond),
      endTime: end_time |> DateTime.to_unix(:millisecond),
      recvWindow: 5000,
      api_secret: api_secret
    ]

    signed_params = sign_params(params)

    request("/sapi/v1/pay/transactions", signed_params, %{api_key: api_key, weight: 1})
  end

  @doc """
  Fetches the wallet balance for a specific wallet type.
  ## Examples

      iex> {:ok, platform_credentials} = BeamBot.Exchanges.Infrastructure.Adapters.Ecto.PlatformCredentialsRepositoryEcto.get_by_user_id_and_exchange_id(1, 1)
      iex> BeamBot.Exchanges.Infrastructure.Adapters.Exchanges.BinanceReqAdapter.get_wallet(platform_credentials)
      {:ok,
        [
          %{"activate" => true, "balance" => "0.00068037", "walletName" => "Spot"},
          %{"activate" => true, "balance" => "0", "walletName" => "Funding"},
          %{"activate" => true, "balance" => "0", "walletName" => "Cross Margin"},
          %{"activate" => true, "balance" => "0", "walletName" => "Isolated Margin"},
          %{"activate" => false, "balance" => "0", "walletName" => "USDⓈ-M Futures"},
          %{"activate" => false, "balance" => "0", "walletName" => "COIN-M Futures"},
          %{"activate" => true, "balance" => "0", "walletName" => "Earn"},
          %{"activate" => false, "balance" => "0", "walletName" => "Options"},
          %{"activate" => false, "balance" => "0", "walletName" => "Trading Bots"},
          %{"activate" => true, "balance" => "0", "walletName" => "Copy Trading"},
          %{"activate" => true, "balance" => "0", "walletName" => "Loan"}
        ]}
  """
  def get_wallet(%PlatformCredentials{api_key: api_key, api_secret: api_secret}) do
    headers = [{"X-MBX-APIKEY", api_key}]

    signed_params =
      sign_params(%{timestamp: :os.system_time(:millisecond), api_secret: api_secret})

    Req.get!("#{@base_url}/sapi/v1/asset/wallet/balance",
      params: signed_params,
      headers: headers
    )
    |> case do
      %{status: 200, body: body} -> {:ok, body}
      %{status: status, body: body} -> {:error, %{status: status, body: body}}
    end
  end

  @doc """
  Fetches ticker information for a specific symbol.

  ## Examples

      iex> BeamBot.Infrastructure.Adapters.BinanceReqAdapter.get_ticker_price("BTCUSDT")
      {:ok, %{symbol: "BTCUSDT", price: "42000.00"}}
  """
  def get_ticker_price(symbol) do
    params = %{symbol: symbol}

    request("/api/v3/ticker/price", params, %{weight: 2})
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

    request("/api/v3/account", signed_params, %{api_key: api_key, weight: 20})
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
  def get_klines(symbol, interval, limit \\ nil, start_time \\ nil, end_time \\ nil) do
    {:ok, limit} =
      case %{limit: limit, start_time: start_time, end_time: end_time} do
        %{limit: limit} when not is_nil(limit) ->
          {:ok, limit}

        %{start_time: start_time, end_time: end_time}
        when not is_nil(start_time) and not is_nil(end_time) ->
          compute_klines_limits(interval, start_time, end_time)

        %{limit: limit} when is_nil(limit) ->
          {:ok, 500}
      end

    params =
      %{
        symbol: symbol,
        interval: interval,
        limit: limit
      }
      |> maybe_add_time_range(start_time, end_time)

    weight = BinanceMultiRateLimiter.compute_klines_weight_from_limit(limit)

    request("/api/v3/klines", params, %{weight: weight})
  end

  @doc """
  Fetches the rate limits for the exchange.

  ## Examples

      iex> BeamBot.Exchanges.Infrastructure.Adapters.Exchanges.BinanceReqAdapter.get_rate_limits()
      {:ok, %{rateLimits: [%{rateLimitType: "REQUEST_WEIGHT", interval: "MINUTE", limit: 6000, current: 0, consumed: 0, remaining: 6000, updateTime: 1717776000000}]}}
  """
  def get_rate_limits do
    request("/api/v3/ping", %{}, %{is_rate_limit_check: true, weight: 1})
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
    request("/api/v3/order", signed_params, %{api_key: api_key})
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

  defp request(endpoint, params, options) do
    url = @base_url <> endpoint

    is_rate_limit_check = Map.get(options, :is_rate_limit_check, false)
    weight = Map.get(options, :weight)

    headers =
      if Map.has_key?(options, :api_key) do
        ["X-MBX-APIKEY": options.api_key]
      else
        []
      end

    case {BinanceMultiRateLimiter.check_weight_limit(weight), is_rate_limit_check} do
      {_, true} ->
        Req.get!(url, params: params, headers: headers)
        |> handle_response(true)

      {{:error, wait_time}, _} ->
        Logger.info("Rate limit exceeded. Sleeping for #{wait_time}ms")
        Process.sleep(wait_time)
        request(endpoint, params, options)

      {:ok, _} ->
        Req.get!(url, params: params, headers: headers)
        |> handle_response(false)
    end
  end

  defp handle_response(
         %Req.Response{status: _status, body: _body, headers: headers},
         true
       ) do
    {:ok,
     headers
     |> Enum.filter(fn {key, _} -> key |> String.starts_with?("x-mbx-") end)}
  end

  defp handle_response(%Req.Response{status: status, body: body}, false)
       when status in 200..299 do
    {:ok, body}
  end

  defp handle_response(%Req.Response{status: status, body: body}, false) do
    Logger.error("Request failed with status #{status}: #{inspect(body)}")
    {:error, %{status: status, body: body}}
  end

  @doc """
  Computes the approximate number of klines for a given interval between two timestamps.

  Note: This calculation provides the number of kline intervals starting between
  `from` and `to` (inclusive). Timestamps are expected in milliseconds.

  ## Examples

      iex> from = 1_678_886_400_000 # 2023-03-15 12:00:00 UTC
      iex> to = 1_678_890_000_000   # 2023-03-15 13:00:00 UTC
      iex> BeamBot.Exchanges.Infrastructure.Adapters.Exchanges.BinanceReqAdapter.compute_klines_limits("1h", from, to)
      2

      iex> from = 1_678_886_400_000 # 2023-03-15 12:00:00 UTC
      iex> to = 1_678_886_400_000   # 2023-03-15 12:00:00 UTC
      iex> BeamBot.Exchanges.Infrastructure.Adapters.Exchanges.BinanceReqAdapter.compute_klines_limits("1h", from, to)
      1

      iex> from = 1_678_886_400_000 # 2023-03-15 12:00:00 UTC
      iex> to = 1_678_886_399_999   # One millisecond before 12:00:00 UTC
      iex> BeamBot.Exchanges.Infrastructure.Adapters.Exchanges.BinanceReqAdapter.compute_klines_limits("1h", from, to)
      0
  """

  def compute_klines_limits("1m", from, to),
    do: compute_klines_limits_from_interval_in_ms(@i_1m_interval_ms, from, to)

  def compute_klines_limits("3m", from, to),
    do: compute_klines_limits_from_interval_in_ms(@i_3m_interval_ms, from, to)

  def compute_klines_limits("5m", from, to),
    do: compute_klines_limits_from_interval_in_ms(@i_5m_interval_ms, from, to)

  def compute_klines_limits("15m", from, to),
    do: compute_klines_limits_from_interval_in_ms(@i_15m_interval_ms, from, to)

  def compute_klines_limits("30m", from, to),
    do: compute_klines_limits_from_interval_in_ms(@i_30m_interval_ms, from, to)

  # Hourly intervals
  def compute_klines_limits("1h", from, to),
    do: compute_klines_limits_from_interval_in_ms(@i_1h_interval_ms, from, to)

  def compute_klines_limits("2h", from, to),
    do: compute_klines_limits_from_interval_in_ms(@i_2h_interval_ms, from, to)

  def compute_klines_limits("4h", from, to),
    do: compute_klines_limits_from_interval_in_ms(@i_4h_interval_ms, from, to)

  def compute_klines_limits("6h", from, to),
    do: compute_klines_limits_from_interval_in_ms(@i_6h_interval_ms, from, to)

  def compute_klines_limits("8h", from, to),
    do: compute_klines_limits_from_interval_in_ms(@i_8h_interval_ms, from, to)

  def compute_klines_limits("12h", from, to),
    do: compute_klines_limits_from_interval_in_ms(@i_12h_interval_ms, from, to)

  # Daily, weekly, monthly intervals
  def compute_klines_limits("1d", from, to),
    do: compute_klines_limits_from_interval_in_ms(@i_1d_interval_ms, from, to)

  def compute_klines_limits("3d", from, to),
    do: compute_klines_limits_from_interval_in_ms(@i_3d_interval_ms, from, to)

  def compute_klines_limits("1w", from, to),
    do: compute_klines_limits_from_interval_in_ms(@i_1w_interval_ms, from, to)

  def compute_klines_limits("1M", from, to),
    do: compute_klines_limits_from_interval_in_ms(@i_1month_interval_ms, from, to)

  defp compute_klines_limits_from_interval_in_ms(interval_ms, from, to) do
    diff_ms = to - from
    limit = div(diff_ms, interval_ms) + 1

    if limit > 5000 do
      {:error, "Limit is greater than 5000"}
    else
      {:ok, limit}
    end
  end

  defp sign_params(params) when is_list(params) do
    {api_secret, params_wo} = Keyword.pop(params, :api_secret)

    # Build query string preserving order & proper encoding per Binance expectations
    query_string = URI.encode_query(params_wo)

    signature =
      :crypto.mac(:hmac, :sha256, api_secret, query_string) |> Base.encode16(case: :lower)

    params_wo ++ [signature: signature]
  end

  defp sign_params(params) when is_map(params) do
    # Fallback for existing map usage (order not guaranteed). Prefer passing a keyword list.
    api_secret = Map.fetch!(params, :api_secret)
    params_wo = Map.delete(params, :api_secret)
    query_string = URI.encode_query(params_wo)

    signature =
      :crypto.mac(:hmac, :sha256, api_secret, query_string) |> Base.encode16(case: :lower)

    Map.put(params_wo, :signature, signature)
  end
end
