defmodule BeamBot.Strategies.Domain.StrategyRunner do
  @moduledoc """
  A runner for trading strategies that handles execution, tracking, and reporting.
  """

  require Logger
  alias BeamBot.Strategies.Domain.SmallInvestorStrategy

  @klines_repository Application.compile_env!(:beam_bot, :klines_repository)

  @type execution_result :: %{
          timestamp: DateTime.t(),
          strategy_name: String.t(),
          signal: :buy | :sell | :hold,
          trading_pair: String.t(),
          price: float(),
          position_size: Decimal.t() | nil,
          reason: String.t()
        }

  @doc """
  Runs a strategy once and returns the result.

  ## Parameters
    - strategy: The strategy struct to execute

  ## Returns
    - {:ok, execution_result} on success
    - {:error, reason} on failure

  ## Examples
      iex> BeamBot.Strategies.Domain.StrategyRunner.run_once(%BeamBot.Strategies.Domain.SmallInvestorStrategy{
        trading_pair: "BTCUSDT",
        timeframe: "1h",
        ma_long_period: 20,
        ma_short_period: 5
      })
  """
  def run_once(strategy) do
    %SmallInvestorStrategy{} = strategy

    case SmallInvestorStrategy.analyze_market(strategy) do
      {:ok, result} ->
        execution_result = %{
          timestamp: DateTime.utc_now(),
          strategy_name: "SmallInvestorStrategy",
          signal: result.signal,
          trading_pair: strategy.trading_pair,
          price: result.price,
          position_size: calculate_position_size(result, strategy),
          reason: get_signal_reason(result)
        }

        Logger.info("Strategy execution result: #{inspect(execution_result)}")
        {:ok, execution_result}

      {:error, reason} ->
        Logger.error("Strategy execution failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Runs a strategy in simulation mode across historical data.

  ## Parameters
    - strategy: The strategy struct to simulate
    - start_date: Starting date for the simulation
    - end_date: Ending date for the simulation

  ## Returns
    - {:ok, simulation_results} on success
    - {:error, reason} on failure

  ## Examples
      iex> BeamBot.Strategies.Domain.StrategyRunner.run_simulation(%BeamBot.Strategies.Domain.SmallInvestorStrategy{
        trading_pair: "BTCUSDT",
        timeframe: "1h",
        ma_long_period: 20,
        ma_short_period: 5
      }, DateTime.utc_now() |> DateTime.add(-30 * 24 * 60 * 60, :second), DateTime.utc_now())
  """
  def run_simulation(strategy, start_date, end_date) do
    %SmallInvestorStrategy{} = strategy

    with {:ok, klines} <- fetch_historical_klines(strategy, start_date, end_date),
         {:ok, final_state} <- run_simulation_with_klines(strategy, klines) do
      build_simulation_results(strategy, final_state, klines)
    end
  end

  @doc """
  Sets up a DCA (Dollar Cost Averaging) plan based on a strategy.

  ## Parameters
    - strategy: The strategy struct to use for DCA
    - frequency: How often to execute the DCA (in days)
    - duration: How long to run the DCA plan (in days)

  ## Returns
    - {:ok, dca_plan} on success
    - {:error, reason} on failure
  """
  def setup_dca_plan(strategy, frequency \\ 7, duration \\ 90) do
    %SmallInvestorStrategy{} = strategy

    {:ok, dca_result} = SmallInvestorStrategy.execute_dca(strategy)

    dca_plan = %{
      trading_pair: strategy.trading_pair,
      total_investment: strategy.investment_amount,
      part_amount: dca_result.dca_part_amount,
      frequency_days: frequency,
      duration_days: duration,
      start_date: DateTime.utc_now(),
      end_date: DateTime.utc_now() |> DateTime.add(duration * 24 * 60 * 60, :second),
      status: :active
    }

    Logger.info("DCA plan created: #{inspect(dca_plan)}")
    {:ok, dca_plan}
  end

  # Private functions

  defp calculate_position_size(result, strategy) do
    case result.signal do
      :buy ->
        # For buy signals, calculate position size based on risk management
        # We'll use a simple fixed percentage of the investment amount
        Decimal.mult(strategy.investment_amount, Decimal.new("0.2"))

      :sell ->
        # For sell signals, we'd ideally calculate based on current holdings
        # For simplicity, using a placeholder
        Decimal.new("0")

      :hold ->
        nil
    end
  end

  defp get_signal_reason(result) do
    case result.signal do
      :buy -> "RSI oversold + favorable MA crossover"
      :sell -> "RSI overbought + unfavorable MA crossover"
      :hold -> "No clear buy/sell signal"
    end
  end

  # Private functions for simulation

  defp fetch_historical_klines(strategy, start_date, end_date) do
    # Convert dates to Unix timestamps in milliseconds for Binance API
    start_time = DateTime.to_unix(start_date, :millisecond)
    end_time = DateTime.to_unix(end_date, :millisecond)

    # Fetch historical data for the simulation period
    # Use a larger limit to ensure we have enough data for the simulation period
    @klines_repository.get_klines(
      strategy.trading_pair,
      strategy.timeframe,
      1000,
      start_time,
      end_time
    )
  end

  defp run_simulation_with_klines(strategy, klines) do
    # Initialize simulation state
    initial_state = %{
      cash: strategy.investment_amount,
      holdings: Decimal.new("0"),
      trades: [],
      current_position: :none,
      previous_klines: []
    }

    # Run simulation through each kline
    final_state =
      Enum.reduce(klines, initial_state, fn kline, state ->
        process_kline(kline, state, strategy)
      end)

    {:ok, final_state}
  end

  defp process_kline(kline, state, strategy) do
    [timestamp, _open, _high, _low, close | _] = kline
    current_price = Decimal.new(close)

    # Keep a sliding window of previous klines for indicator calculation
    previous_klines =
      Enum.take([kline | state.previous_klines], max(strategy.ma_long_period * 3, 100))

    # Analyze market at this point
    case SmallInvestorStrategy.analyze_market_with_data(previous_klines, strategy) do
      {:ok, analysis} ->
        state
        |> execute_simulation_trade(analysis, current_price, timestamp, strategy)
        |> Map.put(:previous_klines, previous_klines)

      {:error, _reason} ->
        %{state | previous_klines: previous_klines}
    end
  end

  defp build_simulation_results(strategy, final_state, klines) do
    # Calculate final portfolio value and ROI
    final_value =
      Decimal.add(
        final_state.cash,
        Decimal.mult(final_state.holdings, get_last_price(klines))
      )

    roi_percentage = calculate_roi_percentage(strategy.investment_amount, final_value)

    {:ok,
     %{
       start_date: DateTime.from_unix!(List.first(klines) |> List.first(), :millisecond),
       end_date: DateTime.from_unix!(List.last(klines) |> List.first(), :millisecond),
       trading_pair: strategy.trading_pair,
       initial_investment: strategy.investment_amount,
       final_value: final_value,
       roi_percentage: roi_percentage,
       trades: Enum.reverse(final_state.trades)
     }}
  end

  defp execute_simulation_trade(state, analysis, current_price, timestamp, strategy) do
    case {analysis.signal, state.current_position} do
      {:buy, :none} ->
        execute_buy_trade(state, current_price, timestamp, strategy)

      {:sell, :long} ->
        execute_sell_trade(state, current_price, timestamp, strategy)

      {_signal, _position} ->
        # Hold or invalid state combination
        state
    end
  end

  defp execute_buy_trade(state, current_price, timestamp, strategy) do
    # Calculate position size (using all available cash for simplicity in simulation)
    position_size = Decimal.div(state.cash, current_price)
    cost = Decimal.mult(position_size, current_price)

    # Calculate fees (using taker fee for market orders)
    fee = Decimal.mult(cost, Decimal.div(strategy.taker_fee, Decimal.new("100")))
    total_cost = Decimal.add(cost, fee)

    %{
      state
      | cash: Decimal.sub(state.cash, total_cost),
        holdings: Decimal.add(state.holdings, position_size),
        current_position: :long,
        trades: [
          %{
            date: timestamp,
            type: :buy,
            price: current_price,
            amount: position_size,
            fee: fee
          }
          | state.trades
        ]
    }
  end

  defp execute_sell_trade(state, current_price, timestamp, strategy) do
    # Sell all holdings
    proceeds = Decimal.mult(state.holdings, current_price)

    # Calculate fees (using taker fee for market orders)
    fee = Decimal.mult(proceeds, Decimal.div(strategy.taker_fee, Decimal.new("100")))
    net_proceeds = Decimal.sub(proceeds, fee)

    %{
      state
      | cash: Decimal.add(state.cash, net_proceeds),
        holdings: Decimal.new("0"),
        current_position: :none,
        trades: [
          %{
            date: timestamp,
            type: :sell,
            price: current_price,
            amount: state.holdings,
            fee: fee
          }
          | state.trades
        ]
    }
  end

  defp get_last_price(klines) do
    [_timestamp, _open, _high, _low, close | _] = List.last(klines)
    Decimal.new(close)
  end

  defp calculate_roi_percentage(initial_investment, final_value) do
    profit = Decimal.sub(final_value, initial_investment)

    Decimal.mult(
      Decimal.div(profit, initial_investment),
      Decimal.new("100")
    )
  end
end
