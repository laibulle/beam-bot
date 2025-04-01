defmodule BeamBot.Strategies.Domain.StrategyRunnerTest do
  use ExUnit.Case

  import Mox

  alias BeamBot.Exchanges.Infrastructure.Adapters.Ecto.KlinesRepositoryMock
  alias BeamBot.Strategies.Domain.{SmallInvestorStrategy, StrategyRunner}

  setup do
    # Generate enough klines data for indicator calculation (ma_long_period * 3 = 60)
    klines_data =
      Enum.map(1..60, fn i ->
        timestamp = DateTime.utc_now() |> DateTime.add(-i * 3600, :second)
        base_price = Decimal.new("50000.0")
        price_variation = Decimal.new(i) |> Decimal.div(Decimal.new("1000"))

        %{
          timestamp: timestamp,
          open: Decimal.add(base_price, price_variation),
          high: Decimal.add(base_price, Decimal.add(price_variation, Decimal.new("1000"))),
          low: Decimal.sub(base_price, Decimal.add(price_variation, Decimal.new("1000"))),
          close: Decimal.add(base_price, price_variation),
          volume: Decimal.new("100.0"),
          quote_volume: Decimal.new("5050000.0"),
          trades_count: 1000,
          taker_buy_base_volume: Decimal.new("50.0"),
          taker_buy_quote_volume: Decimal.new("2525000.0"),
          ignore: Decimal.new("0")
        }
      end)

    # Set up mock expectations for KlinesRepositoryMock
    expect(KlinesRepositoryMock, :get_klines, fn _trading_pair, _timeframe, _limit ->
      {:ok, klines_data}
    end)

    # Create a test strategy
    strategy = %SmallInvestorStrategy{
      trading_pair: "BTCUSDT",
      timeframe: "1h",
      ma_long_period: 20,
      ma_short_period: 5,
      investment_amount: Decimal.new("1000"),
      taker_fee: Decimal.new("0.1"),
      max_risk_percentage: Decimal.new("2")
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
      # Modify the strategy to cause a failure by setting max_risk_percentage to nil
      invalid_strategy = %{strategy | max_risk_percentage: nil}

      assert {:error, _reason} = StrategyRunner.run_once(invalid_strategy)
    end
  end

  describe "run_simulation/3" do
    test "successfully runs simulation and returns results", %{strategy: strategy} do
      end_date = DateTime.utc_now()
      start_date = DateTime.add(end_date, -3600, :second)

      # Generate enough klines data for simulation
      simulation_klines =
        Enum.map(1..60, fn i ->
          timestamp = DateTime.add(start_date, i * 3600, :second)
          base_price = Decimal.new("50000.0")
          price_variation = Decimal.new(i) |> Decimal.div(Decimal.new("1000"))

          %{
            timestamp: timestamp,
            open: Decimal.add(base_price, price_variation),
            high: Decimal.add(base_price, Decimal.add(price_variation, Decimal.new("1000"))),
            low: Decimal.sub(base_price, Decimal.add(price_variation, Decimal.new("1000"))),
            close: Decimal.add(base_price, price_variation),
            volume: Decimal.new("100.0"),
            quote_volume: Decimal.new("5050000.0"),
            trades_count: 1000,
            taker_buy_base_volume: Decimal.new("50.0"),
            taker_buy_quote_volume: Decimal.new("2525000.0"),
            ignore: Decimal.new("0")
          }
        end)

      # Override the mock for simulation with 5 arguments
      expect(KlinesRepositoryMock, :get_klines, fn _trading_pair,
                                                   _timeframe,
                                                   _limit,
                                                   _start_date,
                                                   _end_date ->
        {:ok, simulation_klines}
      end)

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
      expect(KlinesRepositoryMock, :get_klines, fn _trading_pair,
                                                   _timeframe,
                                                   _limit,
                                                   _start_date,
                                                   _end_date ->
        {:ok, []}
      end)

      assert {:ok, results} = StrategyRunner.run_simulation(strategy, start_date, end_date)

      assert results.start_date
      assert results.end_date
      assert results.trading_pair == "BTCUSDT"
      assert results.initial_investment == Decimal.new("1000")
      assert Decimal.equal?(results.final_value, Decimal.new("1000"))
      assert Decimal.equal?(results.roi_percentage, Decimal.new("0"))
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
