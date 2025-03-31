defmodule BeamBot.Strategies.Domain.StrategyRunnerTest do
  use ExUnit.Case
  alias BeamBot.Exchanges.Infrastructure.Adapters.Ecto.TradingPairsRepositoryMock
  alias BeamBot.Repositories.KlinesRepository
  alias BeamBot.Strategies.Domain.{SmallInvestorStrategy, StrategyRunner}

  # Mock the KlinesRepository for testing
  defmodule MockKlinesRepository do
    def get_klines(trading_pair, timeframe, limit, start_date, end_date) do
      # Return mock klines data for testing
      {:ok,
       [
         %{
           timestamp: DateTime.utc_now() |> DateTime.add(-3600, :second),
           open: "50000.0",
           high: "51000.0",
           low: "49000.0",
           close: "50500.0",
           volume: "100.0"
         },
         %{
           timestamp: DateTime.utc_now(),
           open: "50500.0",
           high: "51500.0",
           low: "49500.0",
           close: "51000.0",
           volume: "100.0"
         }
       ]}
    end
  end

  setup do
    # Configure the application to use our mock repository
    Application.put_env(:beam_bot, :klines_repository, MockKlinesRepository)

    # Create a test strategy
    strategy = %SmallInvestorStrategy{
      trading_pair: "BTCUSDT",
      timeframe: "1h",
      ma_long_period: 20,
      ma_short_period: 5,
      investment_amount: Decimal.new("1000"),
      taker_fee: Decimal.new("0.1")
    }

    {:ok, strategy: strategy}
  end

  describe "run_once/1" do
    test "successfully runs strategy and returns execution result", %{strategy: strategy} do
      assert {:ok, result} = StrategyRunner.run_once(strategy)

      assert result.timestamp
      assert result.strategy_name == "SmallInvestorStrategy"
      assert result.trading_pair == "BTCUSDT"
      assert result.price
      assert result.position_size
      assert result.reason
      assert result.signal in [:buy, :sell, :hold]
    end

    test "handles strategy execution failure", %{strategy: strategy} do
      # Modify the strategy to cause a failure
      invalid_strategy = %{strategy | ma_long_period: -1}

      assert {:error, _reason} = StrategyRunner.run_once(invalid_strategy)
    end
  end

  describe "run_simulation/3" do
    test "successfully runs simulation and returns results", %{strategy: strategy} do
      end_date = DateTime.utc_now()
      start_date = DateTime.add(end_date, -3600, :second)

      assert {:ok, results} = StrategyRunner.run_simulation(strategy, start_date, end_date)

      assert results.start_date
      assert results.end_date
      assert results.trading_pair == "BTCUSDT"
      assert results.initial_investment == Decimal.new("1000")
      assert results.final_value
      assert results.roi_percentage
      assert is_list(results.trades)
    end

    test "handles simulation with no klines data", %{strategy: strategy} do
      end_date = DateTime.utc_now()
      start_date = DateTime.add(end_date, -3600, :second)

      # Override the mock to return empty klines
      defmodule EmptyKlinesRepository do
        def get_klines(_trading_pair, _timeframe, _limit, _start_date, _end_date) do
          {:ok, []}
        end
      end

      Application.put_env(:beam_bot, :klines_repository, EmptyKlinesRepository)

      assert {:ok, results} = StrategyRunner.run_simulation(strategy, start_date, end_date)

      assert results.start_date
      assert results.end_date
      assert results.trading_pair == "BTCUSDT"
      assert results.initial_investment == Decimal.new("1000")
      assert results.final_value == Decimal.new("1000")
      assert results.roi_percentage == Decimal.new("0")
      assert results.trades == []
    end
  end

  describe "setup_dca_plan/2" do
    test "successfully creates DCA plan with default parameters", %{strategy: strategy} do
      assert {:ok, plan} = StrategyRunner.setup_dca_plan(strategy)

      assert plan.trading_pair == "BTCUSDT"
      assert plan.total_investment == Decimal.new("1000")
      assert plan.frequency_days == 7
      assert plan.duration_days == 90
      assert plan.status == :active
      assert plan.start_date
      assert plan.end_date
    end

    test "successfully creates DCA plan with custom parameters", %{strategy: strategy} do
      assert {:ok, plan} = StrategyRunner.setup_dca_plan(strategy, 14, 180)

      assert plan.trading_pair == "BTCUSDT"
      assert plan.total_investment == Decimal.new("1000")
      assert plan.frequency_days == 14
      assert plan.duration_days == 180
      assert plan.status == :active
      assert plan.start_date
      assert plan.end_date
    end
  end
end
