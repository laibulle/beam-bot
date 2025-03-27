defmodule BeamBot.Exchanges.Infrastructure.Adapters.Ecto.TradingPairsRepositoryEcto do
  @moduledoc """
  This module is responsible for managing the trading pairs.
  """
  @behaviour BeamBot.Exchanges.UseCases.Ports.TradingPairsRepository
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
end
