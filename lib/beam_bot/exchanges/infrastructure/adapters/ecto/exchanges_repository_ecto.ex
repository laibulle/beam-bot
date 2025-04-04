defmodule BeamBot.Exchanges.Infrastructure.Adapters.Ecto.ExchangesRepositoryEcto do
  @moduledoc """
  This module is responsible for managing the exchanges.
  """

  alias BeamBot.Exchanges.Domain.Exchange
  alias BeamBot.Repo

  @behaviour BeamBot.Exchanges.Domain.Ports.ExchangesRepository

  @impl true
  def get_by_identifier(identifier) do
    case Repo.get_by(Exchange, identifier: identifier) do
      nil -> {:error, "Exchange not found"}
      exchange -> {:ok, exchange}
    end
  end
end
