defmodule BeamBot.Exchanges.Domain.Strategies.StrategyRunner do
  @moduledoc """
  A runner for trading strategies that handles execution, tracking, and reporting.
  """

  require Logger
  alias BeamBot.Exchanges.Domain.Strategies.SmallInvestorStrategy

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
  """
  def run_simulation(strategy, start_date, end_date) do
    %SmallInvestorStrategy{} = strategy

    # Simulation implementation would fetch historical data
    # and run the strategy for each time period

    # For now, we'll just return a placeholder result
    simulation_results = %{
      start_date: start_date,
      end_date: end_date,
      trading_pair: strategy.trading_pair,
      initial_investment: strategy.investment_amount,
      final_value: Decimal.new("0"),
      roi_percentage: Decimal.new("0"),
      trades: []
    }

    {:ok, simulation_results}
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
end
