defmodule BeamBot.Exchanges.Infrastructure.Workers.SmallInvestorStrategyWorker do
  @moduledoc """
  A worker that periodically executes the small investor strategy.
  This worker runs as a GenServer and executes the strategy on a defined interval.
  It can also handle notifications when trading signals are generated.
  """

  use GenServer
  require Logger

  alias BeamBot.Strategies.Domain.SmallInvestorStrategy
  alias BeamBot.Strategies.Domain.StrategyRunner

  # Default interval is 30 minutes
  @check_interval :timer.minutes(30)

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Starts tracking and executing a strategy with the given parameters.

  ## Parameters
    - trading_pair: The trading pair to trade (e.g., "BTCUSDT")
    - investment_amount: The total amount to invest
    - options: Additional options for the strategy
  """
  def start_strategy(trading_pair, investment_amount, options \\ []) do
    GenServer.cast(__MODULE__, {:start_strategy, trading_pair, investment_amount, options})
  end

  @doc """
  Stops executing the current strategy.
  """
  def stop_strategy do
    GenServer.cast(__MODULE__, :stop_strategy)
  end

  @doc """
  Gets the current strategy status.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @doc """
  Runs the strategy immediately, instead of waiting for the next scheduled execution.
  """
  def run_now do
    GenServer.cast(__MODULE__, :run_now)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    check_interval = Keyword.get(opts, :check_interval, @check_interval)

    state = %{
      strategy: nil,
      check_interval: check_interval,
      timer_ref: nil,
      last_check: nil,
      last_result: nil,
      status: :idle
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:start_strategy, trading_pair, investment_amount, options}, state) do
    # Cancel existing timer if there is one
    if state.timer_ref, do: Process.cancel_timer(state.timer_ref)

    # Create new strategy
    strategy = SmallInvestorStrategy.new(trading_pair, investment_amount, options)

    # Schedule first execution
    # First run after 5 seconds
    timer_ref = Process.send_after(self(), :execute_strategy, 5_000)

    Logger.info(
      "Started small investor strategy for #{trading_pair} with amount #{investment_amount}"
    )

    new_state = %{
      state
      | strategy: strategy,
        timer_ref: timer_ref,
        status: :running
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:stop_strategy, state) do
    # Cancel the timer
    if state.timer_ref, do: Process.cancel_timer(state.timer_ref)

    Logger.info("Stopped small investor strategy")

    new_state = %{
      state
      | strategy: nil,
        timer_ref: nil,
        status: :idle
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:run_now, state) do
    if state.strategy do
      # Send the message immediately
      send(self(), :execute_strategy)
      {:noreply, state}
    else
      Logger.warning("Cannot run strategy now: no strategy is configured")
      {:noreply, state}
    end
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status_info = %{
      status: state.status,
      strategy: state.strategy && Map.from_struct(state.strategy),
      last_check: state.last_check,
      last_result: state.last_result
    }

    {:reply, status_info, state}
  end

  @impl true
  def handle_info(:execute_strategy, state) do
    if state.strategy do
      # Execute the strategy
      {result, new_state} = execute_strategy(state)

      # Handle results (e.g., send notifications)
      handle_strategy_result(result)

      # Schedule next execution
      timer_ref = Process.send_after(self(), :execute_strategy, state.check_interval)

      {:noreply, %{new_state | timer_ref: timer_ref}}
    else
      {:noreply, state}
    end
  end

  # Private functions

  defp execute_strategy(state) do
    now = DateTime.utc_now()

    case StrategyRunner.run_once(state.strategy) do
      {:ok, result} ->
        new_state = %{
          state
          | last_check: now,
            last_result: result
        }

        {result, new_state}

      {:error, reason} ->
        Logger.error("Strategy execution failed: #{inspect(reason)}")

        error_result = %{
          timestamp: now,
          error: reason,
          trading_pair: state.strategy.trading_pair
        }

        new_state = %{
          state
          | last_check: now,
            last_result: error_result
        }

        {error_result, new_state}
    end
  end

  defp handle_strategy_result(result) do
    case result do
      %{signal: :buy} ->
        Logger.info("BUY signal generated for #{result.trading_pair} at price #{result.price}")

      # Here you would implement buy order execution or notifications
      # For demo purposes, we're just logging

      %{signal: :sell} ->
        Logger.info("SELL signal generated for #{result.trading_pair} at price #{result.price}")

      # Here you would implement sell order execution or notifications

      %{signal: :hold} ->
        Logger.debug("HOLD signal for #{result.trading_pair} at price #{result.price}")

      %{error: _} ->
        # Error was already logged in execute_strategy
        :ok
    end
  end
end
