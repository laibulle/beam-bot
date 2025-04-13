defmodule BeamBot.Exchanges.Infrastructure.Adapters.Ecto.SyncHistoryRepositoryEcto do
  @moduledoc """
  Ecto implementation of the SyncHistoryRepository port.
  """
  @behaviour BeamBot.Exchanges.Domain.Ports.SyncHistoryRepository

  import Ecto.Query, warn: false

  alias BeamBot.Exchanges.Domain.SyncHistory
  alias BeamBot.Repo

  @impl true
  def get_most_recent(exchange_id, symbol, interval) do
    query =
      from sh in SyncHistory,
        where:
          sh.exchange_id == ^exchange_id and sh.symbol == ^symbol and sh.interval == ^interval,
        order_by: [desc: sh.inserted_at],
        limit: 1

    case Repo.one(query) do
      nil -> {:error, :not_found}
      sync_history -> {:ok, sync_history}
    end
  end

  @impl true
  def insert(attrs) do
    %SyncHistory{}
    |> SyncHistory.changeset(attrs)
    |> Repo.insert()
  end

  @impl true
  def upsert(attrs) do
    get_most_recent(
      attrs.exchange_id,
      attrs.symbol,
      attrs.interval
    )
    |> case do
      {:ok, sync_history} ->
        changeset = SyncHistory.changeset(sync_history, attrs)
        Repo.update(changeset)

      {:error, :not_found} ->
        %SyncHistory{}
        |> SyncHistory.changeset(attrs)
        |> Repo.insert()
    end
  end
end
