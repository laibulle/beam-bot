defmodule BeamBot.Strategies.Infrastructure.Adapters.Ecto.StrategyRepositoryEctoTest do
  use BeamBot.DataCase

  alias BeamBot.Repo
  alias BeamBot.Strategies.Domain.Strategy
  alias BeamBot.Strategies.Infrastructure.Adapters.Ecto.StrategyRepositoryEcto

  setup do
    # Clean up the strategies table before each test
    Repo.delete_all(Strategy)
    :ok
  end

  describe "save_strategy/1" do
    test "successfully saves a new strategy" do
      strategy_params = %{
        "name" => "Test Strategy",
        "status" => "active",
        "activated_at" => DateTime.utc_now() |> DateTime.truncate(:second),
        "params" => %{
          "trading_pair" => "BTCUSDT",
          "timeframe" => "1h",
          "investment_amount" => "1000",
          "max_risk_percentage" => "2"
        }
      }

      assert {:ok, saved_strategy} = StrategyRepositoryEcto.save_strategy(strategy_params)
      assert saved_strategy.id
      assert saved_strategy.name == strategy_params["name"]
      assert saved_strategy.status == strategy_params["status"]
      assert DateTime.compare(saved_strategy.activated_at, strategy_params["activated_at"]) == :eq
      assert saved_strategy.params == strategy_params["params"]
    end

    test "returns error for invalid strategy data" do
      invalid_params = %{
        # Invalid empty name
        "name" => "",
        "status" => "active",
        "activated_at" => DateTime.utc_now() |> DateTime.truncate(:second),
        "params" => %{}
      }

      assert {:error, changeset} = StrategyRepositoryEcto.save_strategy(invalid_params)
      assert "can't be blank" in errors_on(changeset).name
    end

    test "returns error for invalid status" do
      invalid_params = %{
        "name" => "Test Strategy",
        # Invalid status
        "status" => "invalid_status",
        "activated_at" => DateTime.utc_now() |> DateTime.truncate(:second),
        "params" => %{}
      }

      assert {:error, changeset} = StrategyRepositoryEcto.save_strategy(invalid_params)
      assert "is invalid" in errors_on(changeset).status
    end
  end

  describe "get_active_strategies/0" do
    test "returns all active strategies" do
      # Create some test strategies
      active_strategy = %Strategy{
        name: "Active Strategy",
        status: "active",
        activated_at: DateTime.utc_now() |> DateTime.truncate(:second),
        params: %{
          "trading_pair" => "BTCUSDT",
          "timeframe" => "1h"
        }
      }

      inactive_strategy = %Strategy{
        name: "Inactive Strategy",
        status: "stopped",
        activated_at: DateTime.utc_now() |> DateTime.truncate(:second),
        params: %{
          "trading_pair" => "ETHUSDT",
          "timeframe" => "4h"
        }
      }

      {:ok, _} = Repo.insert(active_strategy)
      {:ok, _} = Repo.insert(inactive_strategy)

      assert {:ok, strategies} = StrategyRepositoryEcto.get_active_strategies()
      assert length(strategies) == 1
      assert List.first(strategies).name == "Active Strategy"
    end

    test "returns empty list when no active strategies exist" do
      assert {:ok, []} = StrategyRepositoryEcto.get_active_strategies()
    end
  end

  describe "get_strategy_by_id/1" do
    test "returns strategy when it exists" do
      strategy = %Strategy{
        name: "Test Strategy",
        status: "active",
        activated_at: DateTime.utc_now() |> DateTime.truncate(:second),
        params: %{
          "trading_pair" => "BTCUSDT",
          "timeframe" => "1h"
        }
      }

      {:ok, saved_strategy} = Repo.insert(strategy)

      assert {:ok, retrieved_strategy} =
               StrategyRepositoryEcto.get_strategy_by_id(saved_strategy.id)

      assert retrieved_strategy.id == saved_strategy.id
      assert retrieved_strategy.name == strategy.name
      assert retrieved_strategy.params == strategy.params
    end

    test "returns error when strategy does not exist" do
      assert {:error, "Strategy not found"} = StrategyRepositoryEcto.get_strategy_by_id(-1)
    end
  end

  describe "update_strategy_status/2" do
    test "successfully updates strategy status" do
      strategy = %Strategy{
        name: "Test Strategy",
        status: "active",
        activated_at: DateTime.utc_now() |> DateTime.truncate(:second),
        params: %{
          "trading_pair" => "BTCUSDT",
          "timeframe" => "1h"
        }
      }

      {:ok, saved_strategy} = Repo.insert(strategy)

      assert {:ok, updated_strategy} =
               StrategyRepositoryEcto.update_strategy_status(saved_strategy.id, "paused")

      assert updated_strategy.status == "paused"
    end

    test "returns error when strategy does not exist" do
      assert {:error, "Strategy not found"} =
               StrategyRepositoryEcto.update_strategy_status(-1, "paused")
    end

    test "returns error for invalid status" do
      strategy = %Strategy{
        name: "Test Strategy",
        status: "active",
        activated_at: DateTime.utc_now() |> DateTime.truncate(:second),
        params: %{
          "trading_pair" => "BTCUSDT",
          "timeframe" => "1h"
        }
      }

      {:ok, saved_strategy} = Repo.insert(strategy)

      assert {:error, changeset} =
               StrategyRepositoryEcto.update_strategy_status(saved_strategy.id, "invalid_status")

      assert "is invalid" in errors_on(changeset).status
    end
  end

  describe "update_last_execution/2" do
    test "successfully updates last execution timestamp" do
      strategy = %Strategy{
        name: "Test Strategy",
        status: "active",
        activated_at: DateTime.utc_now() |> DateTime.truncate(:second),
        params: %{
          "trading_pair" => "BTCUSDT",
          "timeframe" => "1h"
        }
      }

      {:ok, saved_strategy} = Repo.insert(strategy)
      new_timestamp = DateTime.utc_now() |> DateTime.truncate(:second)

      assert {:ok, updated_strategy} =
               StrategyRepositoryEcto.update_last_execution(saved_strategy.id, new_timestamp)

      assert DateTime.compare(updated_strategy.last_execution_at, new_timestamp) == :eq
    end

    test "returns error when strategy does not exist" do
      assert {:error, "Strategy not found"} =
               StrategyRepositoryEcto.update_last_execution(
                 -1,
                 DateTime.utc_now() |> DateTime.truncate(:second)
               )
    end
  end
end
