defmodule BeamBot.Exchanges.Infrastructure.Adapters.Ecto.ExchangesRepositoryEctoTest do
  @moduledoc """
  This module is responsible for managing the exchanges.
  """

  use BeamBot.DataCase

  alias BeamBot.Exchanges.Infrastructure.Adapters.Ecto.ExchangesRepositoryEcto

  import BeamBot.ExchangesFixtures

  describe "get_by_identifier/1" do
    test "returns exchange when it exists" do
      exchange = exchange_fixture(%{identifier: "binance"})
      assert {:ok, found_exchange} = ExchangesRepositoryEcto.get_by_identifier("binance")
      assert found_exchange.id == exchange.id
      assert found_exchange.name == exchange.name
      assert found_exchange.identifier == "binance"
    end

    test "returns error when exchange does not exist" do
      assert {:error, :exchange_not_found} =
               ExchangesRepositoryEcto.get_by_identifier("nonexistent")
    end

    test "is case sensitive" do
      exchange_fixture(%{identifier: "binance"})
      assert {:error, :exchange_not_found} = ExchangesRepositoryEcto.get_by_identifier("BINANCE")
    end
  end
end
