defmodule BeamBot.Strategies.Infrastructure.Supervisors.StrategySupervisor do
  @moduledoc """
  Dynamic supervisor for managing strategy processes.
  """
  use DynamicSupervisor
  require Logger

  alias BeamBot.Strategies.Domain.SmallInvestorStrategy
  alias BeamBot.Strategies.Infrastructure.Workers.SmallInvestorStrategyRunner

  @strategy_repository Application.compile_env!(:beam_bot, :strategy_repository)

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    # Start the supervisor with one_for_one strategy
    DynamicSupervisor.init(strategy: :one_for_one)
    |> load_active_strategies()
  end

  def start_child(spec) do
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def terminate_child(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  # Private functions

  defp load_active_strategies(supervisor_state) do
    case @strategy_repository.get_active_strategies() do
      {:ok, strategies} ->
        Logger.debug("Loading #{length(strategies)} active strategies from database")
        # Start strategies in a separate process to avoid blocking supervisor initialization
        _ = Task.start(fn -> start_strategies(strategies) end)
        supervisor_state
    end
  end

  defp start_strategies(strategies) do
    Enum.each(strategies, &start_single_strategy/1)
  end

  defp start_single_strategy(strategy) do
    child_spec = create_strategy_from_db(strategy)
    start_and_register_strategy(strategy, child_spec)
  end

  defp start_and_register_strategy(strategy, child_spec) do
    case SmallInvestorStrategyRunner.start_link(child_spec.start) do
      {:ok, pid} -> register_strategy_with_supervisor(strategy, child_spec, pid)
      {:error, reason} -> log_strategy_error(strategy, "Failed to start strategy", reason)
    end
  end

  defp register_strategy_with_supervisor(strategy, child_spec, pid) do
    Logger.debug("Started strategy #{strategy.id} with pid #{inspect(pid)}")

    DynamicSupervisor.start_child(__MODULE__, %{
      child_spec
      | start: {__MODULE__, :start_child, [pid]}
    })
  end

  defp log_strategy_error(strategy, message, reason) do
    Logger.error("#{message} #{strategy.id}: #{inspect(reason)}")
  end

  defp create_strategy_from_db(strategy) do
    # Extract strategy parameters from the stored params
    params = strategy.params

    # Create a new SmallInvestorStrategy instance
    strategy_instance =
      SmallInvestorStrategy.new(
        params["trading_pair"],
        params["investment_amount"],
        max_risk_percentage: params["max_risk_percentage"],
        rsi_oversold_threshold: params["rsi_oversold_threshold"],
        rsi_overbought_threshold: params["rsi_overbought_threshold"],
        ma_short_period: params["ma_short_period"],
        ma_long_period: params["ma_long_period"],
        timeframe: params["timeframe"],
        maker_fee: params["maker_fee"],
        taker_fee: params["taker_fee"],
        user_id: params["user_id"]
      )

    # Create a child spec for the strategy runner
    %{
      id: "strategy_#{strategy.id}",
      start: {SmallInvestorStrategyRunner, :start_link, [strategy_instance]},
      type: :worker
    }
  end
end
