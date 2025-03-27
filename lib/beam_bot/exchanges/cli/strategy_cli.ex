defmodule BeamBot.Exchanges.CLI.StrategyCLI do
  @moduledoc """
  Command-line interface for interacting with trading strategies.
  This module provides functions that can be called from the Elixir console
  to start, stop, and check the status of trading strategies.
  """

  alias BeamBot.Exchanges.Domain.Strategies.SmallInvestorStrategy
  alias BeamBot.Exchanges.Domain.Strategies.StrategyRunner
  alias BeamBot.Exchanges.Workers.SmallInvestorStrategyWorker

  @doc """
  Starts a small investor strategy for a given trading pair.

  ## Parameters
    - trading_pair: The trading pair to trade (e.g., "BTCUSDT")
    - investment_amount: The total amount to invest as a string (e.g., "500")
    - options: A keyword list of strategy options

  ## Options
    - max_risk_percentage: Maximum percentage of capital at risk (default: 2)
    - rsi_oversold_threshold: RSI threshold for oversold condition (default: 30)
    - rsi_overbought_threshold: RSI threshold for overbought condition (default: 70)
    - timeframe: Candle timeframe (default: "1h")

  ## Examples
      iex> BeamBot.Exchanges.CLI.StrategyCLI.start_strategy("BTCUSDT", "500")
      :ok

      iex> BeamBot.Exchanges.CLI.StrategyCLI.start_strategy("ETHUSDT", "300", max_risk_percentage: 1.5)
      :ok
  """
  def start_strategy(trading_pair, investment_amount, options \\ []) do
    # Convert string amount to Decimal
    decimal_amount = Decimal.new(investment_amount)

    # Start the worker with the strategy
    SmallInvestorStrategyWorker.start_strategy(trading_pair, decimal_amount, options)

    IO.puts(
      "Started small investor strategy for #{trading_pair} with investment amount #{investment_amount} USDT"
    )

    :ok
  end

  @doc """
  Stops the currently running strategy.

  ## Examples
      iex> BeamBot.Exchanges.CLI.StrategyCLI.stop_strategy()
      :ok
  """
  def stop_strategy do
    SmallInvestorStrategyWorker.stop_strategy()

    IO.puts("Stopped strategy")
    :ok
  end

  @doc """
  Shows the current status of the strategy.

  ## Examples
      iex> BeamBot.Exchanges.CLI.StrategyCLI.status()
      Status: running
      Trading pair: BTCUSDT
      Investment amount: 500 USDT
      Last check: 2023-07-15 12:34:56
      Last signal: buy
      :ok
  """
  def status do
    status = SmallInvestorStrategyWorker.get_status()

    IO.puts("Status: #{status.status}")

    if status.strategy do
      print_strategy_info(status.strategy)
      print_last_check_info(status.last_check)
      print_last_result_info(status.last_result)
    end

    :ok
  end

  # Private functions

  defp print_strategy_info(strategy) do
    IO.puts("Trading pair: #{strategy.trading_pair}")
    IO.puts("Investment amount: #{strategy.investment_amount} USDT")

    IO.puts(
      "RSI thresholds: #{strategy.rsi_oversold_threshold}/#{strategy.rsi_overbought_threshold}"
    )

    IO.puts("Timeframe: #{strategy.timeframe}")
  end

  defp print_last_check_info(last_check) do
    if last_check do
      formatted_time = Calendar.strftime(last_check, "%Y-%m-%d %H:%M:%S")
      IO.puts("Last check: #{formatted_time}")
    end
  end

  defp print_last_result_info(nil), do: nil

  defp print_last_result_info(%{signal: signal, price: price} = last_result) do
    IO.puts("Last signal: #{signal}")
    IO.puts("Price: #{price}")

    if Map.get(last_result, :reasons) do
      IO.puts("Reasons: #{Enum.join(last_result.reasons, ", ")}")
    end
  end

  defp print_last_result_info(%{error: error}) do
    IO.puts("Last execution failed: #{inspect(error)}")
  end

  @doc """
  Runs a simulation of the strategy on historical data.

  ## Parameters
    - trading_pair: The trading pair to simulate (e.g., "BTCUSDT")
    - investment_amount: The total amount to invest as a string (e.g., "500")
    - days_ago: Start the simulation this many days ago (default: 30)
    - options: A keyword list of strategy options

  ## Examples
      iex> BeamBot.Exchanges.CLI.StrategyCLI.simulate("BTCUSDT", "500", 90)
      === Simulation Results ===
      Trading pair: BTCUSDT
      Initial investment: 500 USDT
      Final value: 550 USDT
      ROI: 10%
      Number of trades: 5
      :ok
  """
  def simulate(trading_pair, investment_amount, days_ago \\ 30, options \\ []) do
    # Convert string amount to Decimal
    decimal_amount = Decimal.new(investment_amount)

    # Create strategy
    strategy = SmallInvestorStrategy.new(trading_pair, decimal_amount, options)

    # Calculate start and end dates
    end_date = DateTime.utc_now()
    start_date = DateTime.add(end_date, -days_ago * 24 * 60 * 60, :second)

    IO.puts(
      "Starting simulation for #{trading_pair} from #{Calendar.strftime(start_date, "%Y-%m-%d")} to #{Calendar.strftime(end_date, "%Y-%m-%d")}"
    )

    # Run simulation
    case StrategyRunner.run_simulation(strategy, start_date, end_date) do
      {:ok, results} ->
        print_simulation_results(results)
        :ok

      {:error, reason} ->
        IO.puts("Simulation failed: #{inspect(reason)}")
        :error
    end
  end

  @doc """
  Manually executes the strategy once and prints the results.

  ## Examples
      iex> BeamBot.Exchanges.CLI.StrategyCLI.run_now()
      Running strategy...
      Signal: buy
      Price: 42000.0
      Reasons: RSI: 29.5, MA crossover
      :ok
  """
  def run_now do
    IO.puts("Running strategy...")
    SmallInvestorStrategyWorker.run_now()

    # Wait a moment for the strategy to execute
    Process.sleep(2000)

    # Show updated status
    status()
  end

  @doc """
  Creates a DCA plan based on the strategy.

  ## Parameters
    - trading_pair: The trading pair to trade (e.g., "BTCUSDT")
    - investment_amount: The total amount to invest as a string (e.g., "500")
    - frequency_days: How often to make a purchase in days (default: 7)
    - duration_days: How long to run the DCA plan in days (default: 90)

  ## Examples
      iex> BeamBot.Exchanges.CLI.StrategyCLI.setup_dca("BTCUSDT", "500", 7, 90)
      === DCA Plan ===
      Trading pair: BTCUSDT
      Total investment: 500 USDT
      Investment per period: 125 USDT
      Frequency: Every 7 days
      Duration: 90 days
      :ok
  """
  def setup_dca(trading_pair, investment_amount, frequency_days \\ 7, duration_days \\ 90) do
    # Convert string amount to Decimal
    decimal_amount = Decimal.new(investment_amount)

    # Create strategy
    strategy = SmallInvestorStrategy.new(trading_pair, decimal_amount)

    # Set up DCA plan
    case StrategyRunner.setup_dca_plan(strategy, frequency_days, duration_days) do
      {:ok, dca_plan} ->
        IO.puts("=== DCA Plan ===")
        IO.puts("Trading pair: #{dca_plan.trading_pair}")
        IO.puts("Total investment: #{dca_plan.total_investment} USDT")
        IO.puts("Investment per period: #{dca_plan.part_amount} USDT")
        IO.puts("Frequency: Every #{dca_plan.frequency_days} days")
        IO.puts("Duration: #{dca_plan.duration_days} days")
        IO.puts("Start date: #{Calendar.strftime(dca_plan.start_date, "%Y-%m-%d")}")
        IO.puts("End date: #{Calendar.strftime(dca_plan.end_date, "%Y-%m-%d")}")
        :ok

      {:error, reason} ->
        IO.puts("Failed to set up DCA plan: #{inspect(reason)}")
        :error
    end
  end

  defp print_simulation_results(results) do
    IO.puts("=== Simulation Results ===")
    IO.puts("Trading pair: #{results.trading_pair}")
    IO.puts("Initial investment: #{results.initial_investment} USDT")
    IO.puts("Final value: #{results.final_value} USDT")

    # Calculate ROI percentage
    roi_percentage = Decimal.to_float(results.roi_percentage)
    IO.puts("ROI: #{roi_percentage}%")

    IO.puts("Number of trades: #{length(results.trades)}")

    if length(results.trades) > 0 do
      IO.puts("\nTrade history:")

      Enum.each(results.trades, fn trade ->
        date = Calendar.strftime(trade.date, "%Y-%m-%d %H:%M:%S")
        IO.puts("#{date} - #{String.upcase(to_string(trade.type))} at #{trade.price} USDT")
      end)
    end
  end
end
