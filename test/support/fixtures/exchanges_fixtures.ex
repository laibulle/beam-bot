defmodule BeamBot.ExchangesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BeamBot.Exchanges` context.
  """

  alias BeamBot.Exchanges.Domain.Exchange
  alias BeamBot.Exchanges.Domain.PlatformCredentials
  alias BeamBot.Repo

  def exchange_fixture(attrs \\ %{}) do
    {:ok, exchange} =
      %Exchange{}
      |> Exchange.changeset(
        Enum.into(attrs, %{
          name: "Test Exchange",
          identifier: "test_exchange_#{System.unique_integer()}",
          is_active: true
        })
      )
      |> Repo.insert()

    exchange
  end

  def platform_credentials_fixture(attrs \\ %{}) do
    exchange = Map.get(attrs, :exchange) || exchange_fixture()
    user = Map.get(attrs, :user) || BeamBot.AccountsFixtures.user_fixture()

    {:ok, credentials} =
      %PlatformCredentials{}
      |> PlatformCredentials.changeset(
        Enum.into(attrs, %{
          api_key: "test_key_#{System.unique_integer()}",
          api_secret: "test_secret_#{System.unique_integer()}",
          exchange_id: exchange.id,
          user_id: user.id,
          is_active: true
        })
      )
      |> Repo.insert()

    credentials
  end
end
