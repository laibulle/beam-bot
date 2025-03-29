defmodule BeamBot.Exchanges.Infrastructure.Adapters.Ecto.TradingPairsRepositoryEcto do
  @moduledoc """
  This module is responsible for managing the trading pairs.
  """
  @behaviour BeamBot.Exchanges.Domain.Ports.TradingPairsRepository
  alias BeamBot.Repo

  @impl true
  def get_trading_pairs(exchange_identifier) do
    case Repo.get_by(BeamBot.Exchanges.Domain.Exchange, identifier: exchange_identifier) do
      nil -> {:error, "Exchange not found"}
      exchange -> {:ok, exchange.trading_pairs}
    end
  end

  @impl true
  def list_trading_pairs do
    Repo.all(BeamBot.Exchanges.Domain.TradingPair)
  end

  @impl true
  def upsert_trading_pairs(trading_pairs) do
    res =
      Repo.transaction(fn ->
        Enum.each(trading_pairs, fn trading_pair ->
          Repo.insert!(
            trading_pair,
            on_conflict: {:replace_all_except, [:id, :inserted_at]},
            conflict_target: [:symbol, :exchange_id]
          )
        end)
      end)

    case res do
      {:ok, :ok} -> {:ok, trading_pairs}
      error -> {:error, "Failed to upsert trading pairs: #{inspect(error)}"}
    end
  end

  @impl true
  def get_trading_pair_by_symbol(symbol) do
    case Repo.get_by(BeamBot.Exchanges.Domain.TradingPair, symbol: symbol) do
      nil -> {:error, "Trading pair not found"}
      trading_pair -> {:ok, trading_pair}
    end
  end
end
