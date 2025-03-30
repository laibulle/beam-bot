defmodule BeamBot.Socials.Infrastructure.Adapters.Socials.SocialAdapterCryptoPanic do
  @moduledoc """
  This module is responsible for managing the CryptoPanic API integration.
  It fetches crypto news and posts from various sources through CryptoPanic's aggregation service.
  """
  require Logger

  @base_url "https://cryptopanic.com/api/v1"

  @doc """
  Fetches posts from CryptoPanic API.

  ## Parameters
    - limit: The number of posts to fetch (default: 200)
    - page: The page number for pagination (default: 1)
    - filter: Optional filter for posts (e.g., "rising", "hot", "bullish", "bearish")
    - currencies: Optional list of currency codes to filter by

  ## Example
    iex> {:ok, posts} = BeamBot.Socials.Infrastructure.Adapters.Socials.SocialAdapterCryptoPanic.fetch_posts()
  """
  def fetch_posts(opts \\ []) do
    limit = Keyword.get(opts, :limit, 200)
    filter = Keyword.get(opts, :filter)
    currencies = Keyword.get(opts, :currencies)

    params =
      %{
        public: true,
        limit: limit
      }
      |> maybe_add_param(:filter, filter)
      |> maybe_add_param(:currencies, currencies)

    case Req.get("#{@base_url}/posts/", params: params) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        process_posts(body)

      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to fetch CryptoPanic posts: #{inspect(body)}")
        {:error, "Failed to fetch posts with status #{status}"}

      {:error, error} ->
        Logger.error("Error fetching CryptoPanic posts: #{inspect(error)}")
        {:error, "Failed to fetch posts: #{inspect(error)}"}
    end
  end

  @doc """
  Fetches posts filtered by specific cryptocurrencies.

  ## Example
    iex> {:ok, posts} = BeamBot.Socials.Infrastructure.Adapters.Socials.SocialAdapterCryptoPanic.fetch_currency_posts(["BTC", "ETH"])
  """
  def fetch_currency_posts(currencies) when is_list(currencies) do
    fetch_posts(currencies: Enum.join(currencies, ","))
  end

  defp process_posts(%{"results" => posts}) do
    processed_posts =
      Enum.map(posts, fn post ->
        %{
          id: post["id"],
          title: post["title"],
          published_at: post["published_at"],
          url: post["url"],
          domain: post["domain"],
          kind: post["kind"],
          source: get_in(post, ["source", "title"]),
          currencies: extract_currencies(post["currencies"]),
          votes: post["votes"]
        }
      end)

    {:ok, processed_posts}
  end

  defp process_posts(body) do
    Logger.error("Unexpected CryptoPanic API response: #{inspect(body)}")
    {:error, "Unexpected API response format"}
  end

  defp extract_currencies(nil), do: []

  defp extract_currencies(currencies) when is_list(currencies) do
    Enum.map(currencies, fn currency ->
      %{
        code: currency["code"],
        title: currency["title"],
        slug: currency["slug"]
      }
    end)
  end

  defp maybe_add_param(params, _key, nil), do: params
  defp maybe_add_param(params, key, value), do: Map.put(params, key, value)
end
