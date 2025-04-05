defmodule BeamBot.Exchanges.UseCases.SyncTradingPairsUseCase do
  @moduledoc """
  This module is responsible for managing the sync trading pairs use case.
  """
  alias BeamBot.Exchanges.Domain.TradingPair
  alias BeamBot.Repo

  @trading_pairs_repository Application.compile_env(:beam_bot, :trading_pairs_repository)
  @binance_req_adapter Application.compile_env(:beam_bot, :binance_req_adapter)

  @doc """
  Fetches trading pairs from Binance and stores them in the database.

  Returns {:ok, trading_pairs} on success or {:error, reason} on failure.

  ## Examples

      iex> BeamBot.Exchanges.UseCases.SyncTradingPairsUseCase.sync_trading_pairs()
      {:ok, trading_pairs}
  """
  def sync_trading_pairs do
    with {:ok, %{"symbols" => symbols}} <- @binance_req_adapter.get_exchange_info(),
         {:ok, exchange} <- get_or_create_binance_exchange(),
         trading_pairs <- Enum.map(symbols, &create_trading_pair(&1, exchange.id)) do
      @trading_pairs_repository.upsert_trading_pairs(trading_pairs)
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, "Failed to sync trading pairs: #{inspect(error)}"}
    end
  end

  defp get_or_create_binance_exchange do
    case Repo.get_by(BeamBot.Exchanges.Domain.Exchange, identifier: "binance") do
      nil ->
        %BeamBot.Exchanges.Domain.Exchange{}
        |> Ecto.Changeset.change(%{
          identifier: "binance",
          name: "Binance",
          is_active: true
        })
        |> Repo.insert()

      exchange ->
        {:ok, exchange}
    end
  end

  defp create_trading_pair(symbol_data, exchange_id) do
    price_filter =
      Enum.find(symbol_data["filters"], fn filter -> filter["filterType"] == "PRICE_FILTER" end)

    qty_filter =
      Enum.find(symbol_data["filters"], fn filter -> filter["filterType"] == "LOT_SIZE" end)

    notional_filter =
      Enum.find(symbol_data["filters"], fn filter -> filter["filterType"] == "NOTIONAL" end)

    %TradingPair{
      exchange_id: exchange_id,
      symbol: symbol_data["symbol"],
      base_asset: symbol_data["baseAsset"],
      quote_asset: symbol_data["quoteAsset"],
      min_price: parse_decimal(price_filter["minPrice"]),
      max_price: parse_decimal(price_filter["maxPrice"]),
      tick_size: parse_decimal(price_filter["tickSize"]),
      min_qty: parse_decimal(qty_filter["minQty"]),
      max_qty: parse_decimal(qty_filter["maxQty"]),
      step_size: parse_decimal(qty_filter["stepSize"]),
      min_notional: parse_decimal(notional_filter["minNotional"]),
      is_active: symbol_data["status"] == "TRADING"
    }
  end

  defp parse_decimal(nil), do: nil
  defp parse_decimal(value) when is_binary(value), do: Decimal.new(value)
  defp parse_decimal(value), do: Decimal.new(to_string(value))
end
