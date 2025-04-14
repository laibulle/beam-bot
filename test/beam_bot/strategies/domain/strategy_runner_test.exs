defmodule BeamBot.Strategies.Infrastructure.Workers.SmallInvestorStrategyRunnerTest do
  use ExUnit.Case
  use BeamBot.DataCase

  import Mox

  alias BeamBot.Accounts
  alias BeamBot.Exchanges.Infrastructure.Adapters.Ecto.ExchangesRepositoryMock
  alias BeamBot.Exchanges.Infrastructure.Adapters.Ecto.PlatformCredentialsRepositoryMock
  alias BeamBot.Exchanges.Infrastructure.Adapters.Exchanges.BinanceReqAdapterMock
  alias BeamBot.Exchanges.Infrastructure.Adapters.QuestDB.KlinesTuplesRepositoryMock
  alias BeamBot.Strategies.Domain.SmallInvestorStrategy
  alias BeamBot.Strategies.Infrastructure.Workers.SmallInvestorStrategyRunner
  alias BeamBotWeb.KlinesData
  alias BeamBotWeb.KlinesData.InputSettings
  alias Ecto.Adapters.SQL.Sandbox

  setup :set_mox_global

  setup do
    # Start the Ecto sandbox
    :ok = Sandbox.checkout(BeamBot.Repo)

    # Create a test user
    {:ok, user} =
      Accounts.register_user(%{
        email: Faker.Internet.email(),
        password: "@dmin@admin@admin"
      })

    # Generate enough klines data for indicator calculation (ma_long_period * 3 = 60)
    klines_data =
      KlinesData.generate_klines_data(%InputSettings{
        interval: "1h",
        start_time: DateTime.utc_now() |> DateTime.add(-3600 * 60, :second),
        end_time: DateTime.utc_now()
      })

    # Create a test strategy
    strategy = %SmallInvestorStrategy{
      trading_pair: "BTCUSDT",
      timeframe: "1h",
      ma_long_period: 20,
      ma_short_period: 5,
      investment_amount: Decimal.new("1000"),
      taker_fee: Decimal.new("0.1"),
      max_risk_percentage: Decimal.new("2"),
      user_id: user.id
    }

    # Set up global mock stubs
    Mox.stub(ExchangesRepositoryMock, :get_by_identifier, fn
      "binance" -> {:ok, %{id: 1, name: "Binance", identifier: "binance"}}
      :binance -> {:ok, %{id: 1, name: "Binance", identifier: "binance"}}
    end)

    Mox.stub(PlatformCredentialsRepositoryMock, :get_by_user_id_and_exchange_id, fn _user_id,
                                                                                    _platform_id ->
      {:ok, %{api_key: "test_api_key", api_secret: "test_api_secret"}}
    end)

    # Set up mock expectations for KlinesTuplesRepositoryMock
    expect(KlinesTuplesRepositoryMock, :get_klines_tuples, fn _symbol, _interval, _limit ->
      {:ok, klines_data}
    end)

    # Set up mock expectations for BinanceReqAdapterMock
    expect(BinanceReqAdapterMock, :place_order, fn params, credentials ->
      assert params.symbol == "BTCUSDT"
      assert params.side in ["BUY", "SELL"]
      assert params.type == "MARKET"
      assert is_struct(params.quantity, Decimal)
      assert credentials.api_key == "test_api_key"
      assert credentials.api_secret == "test_api_secret"
      {:ok, %{"orderId" => "test_order_id", "status" => "NEW"}}
    end)

    # Start the SmallInvestorStrategyRunner process and allow it to use the sandbox
    {:ok, pid} = SmallInvestorStrategyRunner.start_link(strategy)
    Sandbox.allow(BeamBot.Repo, self(), pid)

    # Allow the GenServer process to use the mocks
    allow(KlinesTuplesRepositoryMock, self(), pid)
    allow(BinanceReqAdapterMock, self(), pid)

    {:ok, strategy: strategy, pid: pid, user: user}
  end

  # describe "run_once/1" do
  #   test "successfully runs strategy and returns execution result", %{
  #     strategy: _strategy,
  #     pid: pid
  #   } do
  #     assert {:ok, result} = SmallInvestorStrategyRunner.run_once(pid)

  #     assert result.timestamp
  #     assert result.strategy_name == "SmallInvestorStrategy"
  #     assert result.trading_pair == "BTCUSDT"
  #     assert result.price
  #     assert result.position_size
  #     assert result.reason
  #     assert result.signal in [:buy, :sell, :hold]
  #   end

  #   test "handles strategy execution failure", %{strategy: strategy} do
  #     # Modify the strategy to cause a failure by setting max_risk_percentage to nil
  #     invalid_strategy = %{strategy | max_risk_percentage: nil}
  #     {:ok, invalid_pid} = SmallInvestorStrategyRunner.start_link(invalid_strategy)

  #     # Allow the new process to use the mocks
  #     Sandbox.allow(BeamBot.Repo, self(), invalid_pid)
  #     allow(KlinesTuplesRepositoryMock, self(), invalid_pid)

  #     assert {:error, _reason} = SmallInvestorStrategyRunner.run_once(invalid_pid)
  #   end
  # end

  describe "run_simulation/3" do
    test "successfully runs simulation and returns results", %{strategy: strategy} do
      end_date = DateTime.utc_now()
      start_date = DateTime.add(end_date, -3600, :second)

      # Generate enough klines data for simulation
      simulation_klines =
        KlinesData.generate_klines_data(%InputSettings{
          interval: "1h",
          start_time: DateTime.utc_now() |> DateTime.add(-3600 * 60, :second),
          end_time: DateTime.utc_now()
        })

      # Override the mock for simulation with 5 arguments
      expect(KlinesTuplesRepositoryMock, :get_klines_tuples, fn _trading_pair,
                                                                _timeframe,
                                                                _limit,
                                                                _start_date,
                                                                _end_date ->
        {:ok, simulation_klines}
      end)

      assert {:ok, results} =
               SmallInvestorStrategyRunner.run_simulation(strategy, start_date, end_date)

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
      expect(KlinesTuplesRepositoryMock, :get_klines_tuples, fn _trading_pair,
                                                                _timeframe,
                                                                _limit,
                                                                _start_date,
                                                                _end_time ->
        {:ok, []}
      end)

      assert {:ok, results} =
               SmallInvestorStrategyRunner.run_simulation(strategy, start_date, end_date)

      assert results.start_date
      assert results.end_date
      assert results.trading_pair == "BTCUSDT"
      assert results.initial_investment == Decimal.new("1000")
      assert Decimal.equal?(results.final_value, Decimal.new("1000"))
      assert Decimal.equal?(results.roi_percentage, Decimal.new("0"))
      assert results.trades == []
    end
  end

  @moduletag :aaa
  describe "setup_dca_plan/2" do
    test "successfully creates DCA plan with default parameters", %{strategy: _strategy, pid: pid} do
      assert {:ok, plan} = SmallInvestorStrategyRunner.setup_dca_plan(pid)

      assert plan.trading_pair == "BTCUSDT"
      assert plan.total_investment == Decimal.new("1000")
      assert plan.frequency_days == 7
      assert plan.duration_days == 90
      assert plan.status == :active
      assert plan.start_date
      assert plan.end_date
    end

    test "successfully creates DCA plan with custom parameters", %{strategy: _strategy, pid: pid} do
      assert {:ok, plan} = SmallInvestorStrategyRunner.setup_dca_plan(pid, 14, 180)

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
