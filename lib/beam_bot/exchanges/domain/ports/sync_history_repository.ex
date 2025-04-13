defmodule BeamBot.Exchanges.Domain.Ports.SyncHistoryRepository do
  @moduledoc """
  Defines the contract for interacting with sync history data.
  """
  alias BeamBot.Exchanges.Domain.SyncHistory

  @doc """
  Fetches the most recent sync history record for a given exchange, symbol, and interval.
  """
  @callback get_most_recent(
              exchange_id :: number(),
              symbol :: String.t(),
              interval :: String.t()
            ) ::
              {:ok, SyncHistory.t()} | {:error, :not_found}

  @doc """
  Inserts a new sync history record.
  """
  @callback insert(attrs :: map()) :: {:ok, SyncHistory.t()} | {:error, Ecto.Changeset.t()}

  @callback upsert(attrs :: map()) :: {:ok, SyncHistory.t()} | {:error, Ecto.Changeset.t()}
end
