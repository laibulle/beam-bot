defmodule BeamBot.Exchanges.Infrastructure.Adapters.Ecto.PlatformCredentialsRepositoryEctoTest do
  use BeamBot.DataCase

  alias BeamBot.Exchanges.Domain.PlatformCredentials
  alias BeamBot.Exchanges.Infrastructure.Adapters.Ecto.PlatformCredentialsRepositoryEcto

  import BeamBot.ExchangesFixtures
  import BeamBot.AccountsFixtures

  describe "create/1" do
    test "creates platform credentials with valid data" do
      exchange = exchange_fixture()
      user = user_fixture()

      attrs = %{
        api_key: "test_key",
        api_secret: "test_secret",
        exchange_id: exchange.id,
        user_id: user.id
      }

      assert {:ok, %PlatformCredentials{} = credentials} =
               PlatformCredentialsRepositoryEcto.create(attrs)

      assert credentials.api_key == "test_key"
      assert credentials.api_secret == "test_secret"
      assert credentials.exchange_id == exchange.id
      assert credentials.user_id == user.id
    end

    test "returns error with invalid data" do
      assert {:error, _changeset} = PlatformCredentialsRepositoryEcto.create(%{})
    end
  end

  describe "update/2" do
    test "updates platform credentials with valid data" do
      exchange = exchange_fixture()
      user = user_fixture()
      credentials = platform_credentials_fixture(%{exchange: exchange, user: user})

      update_attrs = %{
        api_key: "updated_key",
        api_secret: "updated_secret"
      }

      assert {:ok, %PlatformCredentials{} = updated_credentials} =
               PlatformCredentialsRepositoryEcto.update(credentials, update_attrs)

      assert updated_credentials.api_key == "updated_key"
      assert updated_credentials.api_secret == "updated_secret"
    end

    test "returns error with invalid data" do
      exchange = exchange_fixture()
      user = user_fixture()
      credentials = platform_credentials_fixture(%{exchange: exchange, user: user})

      assert {:error, _changeset} =
               PlatformCredentialsRepositoryEcto.update(credentials, %{api_key: nil})
    end
  end

  describe "delete/1" do
    test "deletes platform credentials" do
      exchange = exchange_fixture()
      user = user_fixture()
      credentials = platform_credentials_fixture(%{exchange: exchange, user: user})

      assert {:ok, %PlatformCredentials{}} = PlatformCredentialsRepositoryEcto.delete(credentials)

      assert {:error, "Platform credentials not found"} =
               PlatformCredentialsRepositoryEcto.get_by_user_id_and_exchange_id(
                 user.id,
                 exchange.id
               )
    end
  end

  describe "get_by_user_id_and_exchange_id/2" do
    test "returns platform credentials when they exist" do
      exchange = exchange_fixture()
      user = user_fixture()
      credentials = platform_credentials_fixture(%{exchange: exchange, user: user})

      assert {:ok, %PlatformCredentials{} = found_credentials} =
               PlatformCredentialsRepositoryEcto.get_by_user_id_and_exchange_id(
                 user.id,
                 exchange.id
               )

      assert found_credentials.id == credentials.id
    end

    test "returns error when platform credentials do not exist" do
      assert {:error, "Platform credentials not found"} =
               PlatformCredentialsRepositoryEcto.get_by_user_id_and_exchange_id(123, 456)
    end
  end
end
