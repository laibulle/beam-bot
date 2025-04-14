defmodule BeamBot.Strategies.Infrastructure.Workers.SmallInvestorStrategyRunner do
  @moduledoc """
  A runner for trading strategies that handles execution, tracking, and reporting.
  """

  use GenServer
  require Logger

  alias BeamBot.Strategies.Domain.SmallInvestorStrategy

  @klines_tuples_repository Application.compile_env!(:beam_bot, :klines_tuples_repository)
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
    %SmallInvestorStrategy{} = strategy
    run_simulation_internal(strategy, start_date, end_date)
  end

  def setup_dca_plan(pid, frequency \\ 7, duration \\ 90) do
    GenServer.call(pid, {:setup_dca_plan, frequency, duration})
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
  def handle_call({:setup_dca_plan, frequency, duration}, _from, state) do
    result = setup_dca_plan_internal(state.strategy, frequency, duration)
    {:reply, result, state}
  end

  @impl true
  def handle_info(kline, state)
      when is_map(kline) and is_struct(kline, BeamBot.Exchanges.Domain.Kline) do
    # Only process klines for our trading pair and timeframe
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
    %SmallInvestorStrategy{} = strategy

    with {:ok, saved_strategy} <- save_strategy(strategy),
         {:ok, result} <- SmallInvestorStrategy.analyze_market(strategy),
         {:ok, order_id} <- place_order(result, strategy, exchange_credentials) do
      execution_result = %{
        timestamp: DateTime.utc_now(),
        strategy_name: "SmallInvestorStrategy",
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

  defp place_order(result, strategy, exchange_credentials) do
    case result.signal do
      :buy ->
        # For buy signals, calculate position size based on risk management
        position_size = calculate_position_size(result, strategy)

        # Place a market buy order
        params = %{
          symbol: strategy.trading_pair,
          side: "BUY",
          type: "MARKET",
          quantity: position_size
        }

        case @binance_req_adapter.place_order(params, exchange_credentials) do
          {:ok, order} -> {:ok, order["orderId"]}
          {:error, reason} -> {:error, "Failed to place buy order: #{inspect(reason)}"}
        end

      :sell ->
        # For sell signals, we need to get current holdings
        # This is a simplified version - in production you'd want to track actual holdings
        position_size = calculate_position_size(result, strategy)

        # Place a market sell order
        params = %{
          symbol: strategy.trading_pair,
          side: "SELL",
          type: "MARKET",
          quantity: position_size
        }

        case @binance_req_adapter.place_order(params, exchange_credentials) do
          {:ok, order} -> {:ok, order["orderId"]}
          {:error, reason} -> {:error, "Failed to place sell order: #{inspect(reason)}"}
        end

      :hold ->
        {:ok, nil}
    end
  end

  defp save_strategy(strategy) do
    strategy_attrs = %{
      name: "SmallInvestorStrategy",
      status: "active",
      activated_at: DateTime.utc_now(),
      user_id: strategy.user_id,
      params: %{
        trading_pair: strategy.trading_pair,
        timeframe: strategy.timeframe,
        investment_amount: strategy.investment_amount,
        max_risk_percentage: strategy.max_risk_percentage,
        rsi_oversold_threshold: strategy.rsi_oversold_threshold,
        rsi_overbought_threshold: strategy.rsi_overbought_threshold,
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
      :buy -> "RSI oversold + favorable MA crossover"
      :sell -> "RSI overbought + unfavorable MA crossover"
      :hold -> "No clear buy/sell signal"
    end
  end

  defp setup_dca_plan_internal(strategy, frequency, duration) do
    start_date = DateTime.utc_now()
    end_date = DateTime.add(start_date, duration * 24 * 60 * 60, :second)

    {:ok,
     %{
       trading_pair: strategy.trading_pair,
       total_investment: strategy.investment_amount,
       frequency_days: frequency,
       duration_days: duration,
       status: :active,
       start_date: start_date,
       end_date: end_date
     }}
  end

  # Private functions for simulation

  defp fetch_historical_klines(strategy, start_date, end_date) do
    # Convert dates to Unix timestamps in milliseconds for Binance API
    start_time = DateTime.to_unix(start_date, :millisecond)
    end_time = DateTime.to_unix(end_date, :millisecond)

    # Convert Unix timestamps to DateTime for database query
    start_datetime = DateTime.from_unix!(start_time, :millisecond)
    end_datetime = DateTime.from_unix!(end_time, :millisecond)

    # Fetch historical data for the simulation period
    # Use a larger limit to ensure we have enough data for the simulation period
    @klines_tuples_repository.get_klines_tuples(
      strategy.trading_pair,
      strategy.timeframe,
      1000,
      start_datetime,
      end_datetime
    )
  end

  defp run_simulation_internal(strategy, start_date, end_date) do
    %SmallInvestorStrategy{} = strategy

    with {:ok, klines} <- fetch_historical_klines(strategy, start_date, end_date),
         {:ok, final_state} <- run_simulation_with_klines(strategy, klines),
         {:ok, results} <- build_simulation_results(strategy, final_state, klines) do
      save_simulation_results(results, strategy.user_id)
    end
  end

  defp run_simulation_with_klines(strategy, klines) do
    # Initialize simulation state
    initial_state = %{
      cash: strategy.investment_amount,
      holdings: Decimal.new("0"),
      trades: [],
      current_position: :none,
      klines: []
    }

    # Run simulation through each kline
    final_state =
      Enum.reduce(klines, initial_state, fn kline, state ->
        [_open, _high, _low, current_price, _, open_time | _rest] = kline
        klines_for_analysis = state.klines ++ [kline]

        klines_for_analysis =
          if length(klines_for_analysis) > strategy.ma_long_period * 3 do
            Enum.drop(klines, -1)
          else
            klines
          end

        # Analyze market at this point
        case SmallInvestorStrategy.analyze_market_with_data(klines_for_analysis, strategy) do
          {:ok, analysis} ->
            execute_simulation_trade(state, analysis, current_price, open_time, strategy)

          {:error, _reason} ->
            state |> Map.put(:klines, klines_for_analysis)
        end
      end)

    {:ok, final_state}
  end

  defp build_simulation_results(strategy, final_state, []) do
    {:ok,
     %{
       start_date: DateTime.utc_now(),
       end_date: DateTime.utc_now(),
       trading_pair: strategy.trading_pair,
       initial_investment: strategy.investment_amount,
       final_value: final_state.cash,
       roi_percentage: Decimal.new("0"),
       trades: []
     }}
  end

  defp build_simulation_results(strategy, final_state, klines) do
    # Calculate final portfolio value and ROI
    final_value =
      Decimal.add(
        final_state.cash,
        Decimal.mult(final_state.holdings, get_last_price(klines))
      )

    roi_percentage = calculate_roi_percentage(strategy.investment_amount, final_value)

    # Get first and last klines for date range
    first_kline = List.first(klines)
    last_kline = List.last(klines)

    {:ok,
     %{
       start_date: first_kline.timestamp,
       end_date: last_kline.timestamp,
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
    # Calculate fees (using taker fee for market orders)
    fee =
      Decimal.mult(
        Decimal.mult(state.holdings, current_price),
        Decimal.div(strategy.taker_fee, Decimal.new("100"))
      )

    %{
      state
      | cash:
          Decimal.add(
            state.cash,
            Decimal.sub(Decimal.mult(state.holdings, current_price), fee)
          ),
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
    List.last(klines).close
  end

  defp calculate_roi_percentage(initial_investment, final_value) do
    Decimal.mult(
      Decimal.div(
        Decimal.sub(final_value, initial_investment),
        initial_investment
      ),
      Decimal.new("100")
    )
  end

  defp save_simulation_results(results, user_id) do
    # Convert atom keys to strings for trades
    trades =
      Enum.map(results.trades, fn trade ->
        trade
        |> Map.update!(:type, &Atom.to_string/1)
        |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
      end)

    # Prepare simulation attributes with string keys
    simulation_attrs = %{
      "trading_pair" => results.trading_pair,
      "initial_investment" => results.initial_investment,
      "final_value" => results.final_value,
      "roi_percentage" => results.roi_percentage,
      "start_date" => results.start_date,
      "end_date" => results.end_date,
      "user_id" => user_id,
      "trades" => trades
    }

    @simulation_results_repository.save_simulation_result(simulation_attrs)
  end
end
