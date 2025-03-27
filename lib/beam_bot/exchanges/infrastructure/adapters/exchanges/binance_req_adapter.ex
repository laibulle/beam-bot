defmodule BeamBot.Exchanges.Infrastructure.Adapters.BinanceReqAdapter do
  @moduledoc """
  An adapter for interacting with the Binance API using Req.
  """

  require Logger

  @api_key Application.compile_env(:beam_bot, :binance_api_key)
  @api_secret_key Application.compile_env(:beam_bot, :binance_api_secret_key)
  @base_url Application.compile_env(:beam_bot, :binance_base_url, "https://api.binance.com")

  @doc """
  Creates a new BinanceReqAdapter struct.

  Fetches the current exchange information from Binance.
  ## Examples

      iex> BeamBot.Infrastructure.Adapters.BinanceReqAdapter.get_exchange_info()
      {:ok, %{symbols: [%{baseAsset: "BTC", quoteAsset: "USDT", symbol: "BTCUSDT", baseAssetPrecision: 8, quotePrecision: 8, orderTypes: ["LIMIT", "MARKET"]}}
  """
  def get_exchange_info() do
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

      iex> BeamBot.Infrastructure.Adapters.BinanceReqAdapter.get_account_info()
      {:ok, account_info}
  """
  def get_account_info() do
    timestamp = :os.system_time(:millisecond)
    params = %{timestamp: timestamp}
    signed_params = sign_params(params)

    request("/api/v3/account", signed_params, @api_key)
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
    query_string = URI.encode_query(params)

    signature =
      :crypto.mac(:hmac, :sha256, @api_secret_key, query_string) |> Base.encode16(case: :lower)

    Map.put(params, :signature, signature)
  end
end
