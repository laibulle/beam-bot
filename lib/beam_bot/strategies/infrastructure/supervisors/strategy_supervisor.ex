defmodule BeamBot.Strategies.Infrastructure.Supervisors.StrategySupervisor do
  @moduledoc """
  Dynamic supervisor for managing strategy processes.
  """
  use DynamicSupervisor
  require Logger

  alias BeamBot.Strategies.Domain.{SmallInvestorStrategy, StrategyRunner}

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
        Logger.info("Loading #{length(strategies)} active strategies from database")
        start_strategies(strategies)
        supervisor_state

      {:error, reason} ->
        Logger.error("Failed to load active strategies: #{inspect(reason)}")
        supervisor_state
    end
  end

  defp start_strategies(strategies) do
    Enum.each(strategies, fn strategy ->
      case create_strategy_from_db(strategy) do
        {:ok, child_spec} ->
          start_child(child_spec)

        {:error, reason} ->
          Logger.error("Failed to create strategy from DB: #{inspect(reason)}")
      end
    end)
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
        taker_fee: params["taker_fee"]
      )

    # Create a child spec for the strategy runner
    {:ok,
     %{
       id: "strategy_#{strategy.id}",
       start: {StrategyRunner, :start_link, [strategy_instance]},
       type: :worker
     }}
  end
end
