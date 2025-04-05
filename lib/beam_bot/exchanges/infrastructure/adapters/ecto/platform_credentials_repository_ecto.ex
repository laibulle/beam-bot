defmodule BeamBot.Exchanges.Infrastructure.Adapters.Ecto.PlatformCredentialsRepositoryEcto do
  @moduledoc """
  This module is responsible for managing platform credentials using Ecto.
  """
  alias BeamBot.Exchanges.Domain.PlatformCredentials
  alias BeamBot.Repo

  @behaviour BeamBot.Exchanges.Domain.Ports.PlatformCredentialsRepository

  @impl true
  def create(attrs) do
    %PlatformCredentials{}
    |> PlatformCredentials.changeset(attrs)
    |> Repo.insert()
  end

  @impl true
  def update(platform_credentials, attrs) do
    platform_credentials
    |> PlatformCredentials.changeset(attrs)
    |> Repo.update()
  end

  @impl true
  def delete(platform_credentials) do
    Repo.delete(platform_credentials)
  end

  @impl true
  def get_by_user_id_and_exchange_id(user_id, platform_id) do
    case Repo.get_by(PlatformCredentials, user_id: user_id, exchange_id: platform_id) do
      nil -> {:error, "Platform credentials not found"}
      credentials -> {:ok, credentials}
    end
  end
end
