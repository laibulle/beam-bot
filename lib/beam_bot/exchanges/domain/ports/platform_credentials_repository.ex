defmodule BeamBot.Exchanges.Domain.Ports.PlatformCredentialsRepository do
  @moduledoc """
  This module defines the port for platform credentials repository.
  """

  @callback create(attrs :: map()) ::
              {:ok, BeamBot.Exchanges.Domain.PlatformCredentials.t()} | {:error, any()}
  @callback update(
              platform_credentials :: BeamBot.Exchanges.Domain.PlatformCredentials.t(),
              attrs :: map()
            ) :: {:ok, BeamBot.Exchanges.Domain.PlatformCredentials.t()} | {:error, any()}
  @callback delete(platform_credentials :: BeamBot.Exchanges.Domain.PlatformCredentials.t()) ::
              {:ok, BeamBot.Exchanges.Domain.PlatformCredentials.t()} | {:error, any()}
  @callback get_by_user_id_and_exchange_id(user_id :: integer(), platform_id :: integer()) ::
              {:ok, BeamBot.Exchanges.Domain.PlatformCredentials.t()} | {:error, any()}
end
