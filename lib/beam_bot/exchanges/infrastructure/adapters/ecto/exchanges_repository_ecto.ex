defmodule BeamBot.Exchanges.Infrastructure.Adapters.Ecto.ExchangesRepositoryEcto do
  @moduledoc """
  This module is responsible for managing the exchanges.
  """

  alias BeamBot.Exchanges.Domain.Exchange
  alias BeamBot.Repo

  @behaviour BeamBot.Exchanges.Domain.Ports.ExchangesRepository

  @impl true
  @doc """
  Get an exchange by its identifier.
  iex> BeamBot.Exchanges.Infrastructure.Adapters.Ecto.ExchangesRepositoryEcto.get_by_identifier("binance")
  {:ok, %BeamBot.Exchanges.Domain.Exchange{id: 1, name: "Binance", identifier: "binance"}}
  """
  def get_by_identifier(identifier) do
    case Repo.get_by(Exchange, identifier: identifier) do
      nil -> {:error, :exchange_not_found}
      exchange -> {:ok, exchange}
    end
  end
end
