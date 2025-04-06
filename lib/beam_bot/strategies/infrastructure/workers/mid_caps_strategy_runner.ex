defmodule BeamBot.Strategies.Infrastructure.Workers.MidCapsStrategyRunner do
  @moduledoc """
  A runner for the Mid-caps trading strategy that handles execution, tracking, and reporting.
  """

  use GenServer
  require Logger

  alias BeamBot.Strategies.Domain.MidCapsStrategy

  @klines_repository Application.compile_env!(:beam_bot, :klines_repository)
  @strategy_repository Application.compile_env!(:beam_bot, :strategy_repository)
  @binance_req_adapter Application.compile_env!(:beam_bot, :binance_req_adapter)
  @exchanges_repository Application.compile_env!(:beam_bot, :exchanges_repository)
  @platform_credentials_repository Application.compile_env!(
                                     :beam_bot,
                                     :platform_credentials_repository
                                   )
  @simulation_results_repository Application.compile_env!(
                                   :beam_bot,
                                   :simulation_results_repository
                                 )

  @type execution_result :: %{
          timestamp: DateTime.t(),
          strategy_name: String.t(),
          signal: :buy | :sell | :hold,
          trading_pair: String.t(),
          price: float(),
          position_size: Decimal.t() | nil,
          reason: String.t(),
          order_id: String.t() | nil
        }

  # Client API

  def start_link(strategy) do
    GenServer.start_link(__MODULE__, strategy)
  end

  def run_once(pid) do
    GenServer.call(pid, :run_once)
  end

  def run_simulation(strategy, start_date, end_date) do
    %MidCapsStrategy{} = strategy
    run_simulation_internal(strategy, start_date, end_date)
  end

  # Server callbacks

  @impl true
  def init(strategy) do
    with :ok <-
           Phoenix.PubSub.subscribe(BeamBot.PubSub, "binance:kline:#{strategy.trading_pair}"),
         # Schedule first execution
         _timer_ref <- Process.send_after(self(), :execute_strategy, 5_000),
         {:ok, exchange} <- @exchanges_repository.get_by_identifier("binance"),
         {:ok, exchange_credentials} <-
           @platform_credentials_repository.get_by_user_id_and_exchange_id(
             strategy.user_id,
             exchange.id
           ) do
      {:ok,
       %{
         strategy: strategy,
         last_execution: nil,
         last_result: nil,
         exchange: exchange,
         exchange_credentials: exchange_credentials
       }}
    else
      {:error, :exchange_not_found} ->
        Logger.error(
          "Failed to find Binance exchange or credentials for user #{strategy.user_id}"
        )

        {:stop, :exchange_not_found}

      {:error, reason} ->
        Logger.error("Failed to initialize strategy runner: #{inspect(reason)}")
        {:stop, reason}
    end
  rescue
    e ->
      Logger.error("Crashed while initializing strategy runner: #{inspect(e)}")

      {:stop, "Crashed while initializing strategy runner: #{inspect(e)}"}
  end

  @impl true
  def handle_call(:run_once, _from, state) do
    result = execute_strategy(state.strategy, state.exchange_credentials)
    {:reply, result, %{state | last_execution: DateTime.utc_now(), last_result: result}}
  end

  @impl true
  def handle_call({:run_simulation, start_date, end_date}, _from, state) do
    result = run_simulation_internal(state.strategy, start_date, end_date)
    {:reply, result, state}
  end

  @impl true
  def handle_info(kline, state)
      when is_map(kline) and is_struct(kline, BeamBot.Exchanges.Domain.Kline) do
    if kline.symbol == state.strategy.trading_pair and kline.interval == state.strategy.timeframe do
      # Execute strategy when we receive a new kline
      result = execute_strategy(state.strategy, state.exchange_credentials)
      {:noreply, %{state | last_execution: DateTime.utc_now(), last_result: result}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:execute_strategy, state) do
    # Execute the strategy
    result = execute_strategy(state.strategy, state.exchange_credentials)

    # Schedule next execution (every 30 minutes)
    Process.send_after(self(), :execute_strategy, :timer.minutes(30))

    {:noreply, %{state | last_execution: DateTime.utc_now(), last_result: result}}
  end

  # Private functions

  defp execute_strategy(strategy, exchange_credentials) do
    %MidCapsStrategy{} = strategy

    with {:ok, saved_strategy} <- save_strategy(strategy),
         {:ok, result} <- MidCapsStrategy.analyze_market(strategy),
         {:ok, order_id} <- place_order(result, strategy, exchange_credentials) do
      execution_result = %{
        timestamp: DateTime.utc_now(),
        strategy_name: "MidCapsStrategy",
        signal: result.signal,
        trading_pair: strategy.trading_pair,
        price: result.price,
        position_size: calculate_position_size(result, strategy),
        reason: get_signal_reason(result),
        order_id: order_id
      }

      # Update last execution time
      @strategy_repository.update_last_execution(saved_strategy.id, execution_result.timestamp)

      Logger.debug("Strategy execution result: #{inspect(execution_result)}")
      {:ok, execution_result}
    end
  end

  defp save_strategy(strategy) do
    strategy_attrs = %{
      name: "MidCapsStrategy",
      status: "active",
      activated_at: DateTime.utc_now(),
      user_id: strategy.user_id,
      params: %{
        trading_pair: strategy.trading_pair,
        timeframe: strategy.timeframe,
        investment_amount: strategy.investment_amount,
        max_risk_percentage: strategy.max_risk_percentage,
        volume_threshold: strategy.volume_threshold,
        volatility_threshold: strategy.volatility_threshold,
        ma_short_period: strategy.ma_short_period,
        ma_long_period: strategy.ma_long_period,
        maker_fee: strategy.maker_fee,
        taker_fee: strategy.taker_fee
      }
    }

    @strategy_repository.save_strategy(strategy_attrs)
  end

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
      :buy -> "Volume and volatility above thresholds"
      :sell -> "Volume and volatility below thresholds"
      :hold -> "No clear buy/sell signal"
    end
  end

  defp run_simulation_internal(strategy, start_date, end_date) do
    # Implementation for simulation would go here
    # This would involve fetching historical data and running the strategy
    # over that period to evaluate performance
    {:ok, %{simulation_result: "Not implemented yet"}}
  end

  defp place_order(result, strategy, exchange_credentials) do
    # Implementation for placing orders would go here
    # This would involve using the exchange API to place orders
    # based on the strategy signals
    {:ok, "order_123"}
  end
end
