defmodule BeamBot.Infrastructure.Adapters.BinanceReqAdapter do
  @moduledoc """
  An adapter for interacting with the Binance API using Req.
  """

  require Logger

  @base_url "https://api.binance.com"

  defstruct [:api_key, :secret_key]

  @doc """
  Creates a new BinanceAdapter struct.

  ## Examples

      iex> BinanceAdapter.new("api_key", "secret_key")
      %BinanceAdapter{api_key: "api_key", secret_key: "secret_key"}
  """
  def new(api_key, secret_key) do
    %__MODULE__{
      api_key: api_key,
      secret_key: secret_key
    }
  end

  @doc """
  Fetches the current exchange information from Binance.
  """
  def get_exchange_info() do
    request("/api/v3/exchangeInfo")
  end

  @doc """
  Fetches ticker information for a specific symbol.

  ## Examples

      iex> BinanceAdapter.get_ticker_price("BTCUSDT")
      {:ok, %{symbol: "BTCUSDT", price: "42000.00"}}
  """
  def get_ticker_price(symbol) do
    params = %{symbol: symbol}

    request("/api/v3/ticker/price", params)
  end

  @doc """
  Fetches account information. Requires API key and signature.

  ## Examples

      iex> BinanceAdapter.get_account_info(adapter)
      {:ok, account_info}
  """
  def get_account_info(%__MODULE__{} = adapter) do
    timestamp = :os.system_time(:millisecond)
    params = %{timestamp: timestamp}
    signed_params = sign_params(adapter.secret_key, params)

    request("/api/v3/account", signed_params, adapter.api_key)
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

  defp sign_params(secret_key, params) do
    query_string = URI.encode_query(params)
    signature = :crypto.hmac(:sha256, secret_key, query_string) |> Base.encode16(case: :lower)
    Map.put(params, :signature, signature)
  end
end
