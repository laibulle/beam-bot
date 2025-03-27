defmodule BeamBotWeb.TradingPairLive do
  use BeamBotWeb, :live_view

  @binance_req_adapter Application.compile_env(:beam_bot, :binance_req_adapter)
  @trading_pairs_repository Application.compile_env(:beam_bot, :trading_pairs_repository)
  # Define refresh interval in milliseconds
  @refresh_interval 10_000

  alias BeamBot.Exchanges.Domain.Strategies.SmallInvestorStrategy
  alias BeamBot.Exchanges.Domain.Strategies.StrategyRunner
  alias BeamBot.Exchanges.Workers.SmallInvestorStrategyWorker

  @impl true
  def mount(%{"symbol" => symbol}, _session, socket) do
    if connected?(socket) do
      # Schedule periodic refresh of strategy status
      Process.send_after(self(), :refresh_status, @refresh_interval)
    end

    {:ok, trading_pair} = @trading_pairs_repository.get_trading_pair_by_symbol(symbol)
    {:ok, data} = @binance_req_adapter.get_klines(symbol, "1h")

    # Get strategy status if it exists
    strategy_status = SmallInvestorStrategyWorker.get_status()

    {:ok,
     socket
     |> assign(data: data)
     |> assign(trading_pair: trading_pair)
     |> assign(simulation_results: nil)
     |> assign(strategy_status: strategy_status)
     |> assign(strategy_message: nil)}
  end

  @impl true
  def handle_info(:refresh_status, socket) do
    # Schedule next refresh
    Process.send_after(self(), :refresh_status, @refresh_interval)

    # Get updated status
    strategy_status = SmallInvestorStrategyWorker.get_status()

    {:noreply, assign(socket, strategy_status: strategy_status)}
  end

  @impl true
  def handle_event(
        "test_strategy",
        %{
          "timeframe" => timeframe,
          "fast_period" => fast_period,
          "slow_period" => slow_period,
          "min_profit" => min_profit,
          "max_loss" => max_loss,
          "days" => days
        } = params,
        socket
      ) do
    trading_pair = socket.assigns.trading_pair

    # Default investment amount for simulation
    investment_amount = Decimal.new("500")

    # Convert string parameters to appropriate types
    days_ago = String.to_integer(days)

    # Create strategy with options
    options = [
      timeframe: timeframe,
      fast_period: String.to_integer(fast_period),
      slow_period: String.to_integer(slow_period),
      min_profit_percentage: String.to_float(min_profit),
      max_loss_percentage: String.to_float(max_loss)
    ]

    strategy = SmallInvestorStrategy.new(trading_pair.symbol, investment_amount, options)

    # Calculate start and end dates for simulation
    end_date = DateTime.utc_now()
    start_date = DateTime.add(end_date, -days_ago * 24 * 60 * 60, :second)

    # Run simulation
    simulation_results =
      case StrategyRunner.run_simulation(strategy, start_date, end_date) do
        {:ok, results} -> results
        {:error, reason} -> %{error: reason}
      end

    {:noreply, assign(socket, simulation_results: simulation_results)}
  end

  @impl true
  def handle_event(
        "start_strategy",
        %{"investment_amount" => investment_amount, "max_risk_percentage" => max_risk_percentage} =
          params,
        socket
      ) do
    trading_pair = socket.assigns.trading_pair

    # Convert string amount to Decimal
    decimal_amount = Decimal.new(investment_amount)

    # Prepare options
    options = [
      max_risk_percentage: String.to_float(max_risk_percentage)
    ]

    # Start the strategy worker
    result =
      SmallInvestorStrategyWorker.start_strategy(trading_pair.symbol, decimal_amount, options)

    # Get updated status
    strategy_status = SmallInvestorStrategyWorker.get_status()

    message =
      case result do
        :ok ->
          "Started strategy for #{trading_pair.symbol} with investment amount #{investment_amount} USDT"

        {:error, reason} ->
          "Failed to start strategy: #{inspect(reason)}"
      end

    {:noreply,
     socket
     |> assign(strategy_status: strategy_status)
     |> assign(strategy_message: message)}
  end

  @impl true
  def handle_event("stop_strategy", _params, socket) do
    # Stop the strategy
    SmallInvestorStrategyWorker.stop_strategy()

    # Get updated status
    strategy_status = SmallInvestorStrategyWorker.get_status()

    {:noreply,
     socket
     |> assign(strategy_status: strategy_status)
     |> assign(strategy_message: "Strategy stopped")}
  end

  @impl true
  def handle_event("run_now", _params, socket) do
    # Manually run the strategy once
    SmallInvestorStrategyWorker.run_now()

    # Wait a moment for the strategy to execute
    Process.sleep(1000)

    # Get updated status
    strategy_status = SmallInvestorStrategyWorker.get_status()

    {:noreply,
     socket
     |> assign(strategy_status: strategy_status)
     |> assign(strategy_message: "Strategy executed manually")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={BeamBotWeb.Layouts.DashboardComponent}
      id="dashboard"
      current_user={%{email: "fake"}}
    >
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h6 class="text-lg font-semibold mb-3">Basic Information</h6>
          <div class="space-y-2">
            <div class="flex items-center space-x-2">
              <span class="font-medium text-gray-600">Status:</span>
              <span class={"px-2 py-1 rounded-full text-xs font-medium #{if @trading_pair.is_active, do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800"}"}>
                {if @trading_pair.is_active, do: "ACTIVE", else: "INACTIVE"}
              </span>
            </div>
            <div>
              <span class="font-medium text-gray-600">Base Asset:</span>
              <span class="ml-2">{@trading_pair.base_asset}</span>
            </div>
            <div>
              <span class="font-medium text-gray-600">Quote Asset:</span>
              <span class="ml-2">{@trading_pair.quote_asset}</span>
            </div>
          </div>
        </div>
        <div>
          <h6 class="text-lg font-semibold mb-3">Trading Rules</h6>
          <div class="space-y-4">
            <div class="bg-gray-50 p-3 rounded-lg">
              <div class="font-medium text-gray-700 mb-2">Price Limits</div>
              <div class="space-y-1">
                <div class="text-sm text-gray-600">
                  <span class="font-medium">Min Price:</span> {@trading_pair.min_price}
                </div>
                <div class="text-sm text-gray-600">
                  <span class="font-medium">Max Price:</span> {@trading_pair.max_price}
                </div>
                <div class="text-sm text-gray-600">
                  <span class="font-medium">Tick Size:</span> {@trading_pair.tick_size}
                </div>
              </div>
            </div>
            <div class="bg-gray-50 p-3 rounded-lg">
              <div class="font-medium text-gray-700 mb-2">Quantity Limits</div>
              <div class="space-y-1">
                <div class="text-sm text-gray-600">
                  <span class="font-medium">Min Quantity:</span> {@trading_pair.min_qty}
                </div>
                <div class="text-sm text-gray-600">
                  <span class="font-medium">Max Quantity:</span> {@trading_pair.max_qty}
                </div>
                <div class="text-sm text-gray-600">
                  <span class="font-medium">Step Size:</span> {@trading_pair.step_size}
                </div>
              </div>
            </div>
            <div class="bg-gray-50 p-3 rounded-lg">
              <div class="font-medium text-gray-700 mb-2">Other Rules</div>
              <div class="space-y-1">
                <div class="text-sm text-gray-600">
                  <span class="font-medium">Min Notional:</span> {@trading_pair.min_notional}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="mt-8">
        <h6 class="text-lg font-semibold mb-4">Price Chart</h6>
        <div class="bg-white rounded-lg shadow p-6">
          <canvas id="priceChart" phx-hook="PriceChart" data-chart-data={Jason.encode!(@data)}>
          </canvas>
        </div>
      </div>

      <%= if @strategy_message do %>
        <div class="mt-4 p-4 rounded-lg bg-blue-50 text-blue-700">
          {@strategy_message}
        </div>
      <% end %>

      <%= if @strategy_status && @strategy_status.status == :running do %>
        <div class="mt-8">
          <h6 class="text-lg font-semibold mb-4">Active Strategy</h6>
          <div class="bg-white rounded-lg shadow p-6">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <h7 class="text-md font-medium mb-3 block">Strategy Information</h7>
                <div class="space-y-2">
                  <div>
                    <span class="font-medium text-gray-600">Status:</span>
                    <span class="ml-2 px-2 py-1 bg-green-100 text-green-800 rounded-full text-xs font-medium">
                      RUNNING
                    </span>
                  </div>
                  <div>
                    <span class="font-medium text-gray-600">Trading Pair:</span>
                    <span class="ml-2">{@strategy_status.strategy.trading_pair}</span>
                  </div>
                  <div>
                    <span class="font-medium text-gray-600">Investment Amount:</span>
                    <span class="ml-2">{@strategy_status.strategy.investment_amount} USDT</span>
                  </div>
                  <div>
                    <span class="font-medium text-gray-600">Timeframe:</span>
                    <span class="ml-2">{@strategy_status.strategy.timeframe}</span>
                  </div>
                  <div>
                    <span class="font-medium text-gray-600">RSI Thresholds:</span>
                    <span class="ml-2">
                      {@strategy_status.strategy.rsi_oversold_threshold}/{@strategy_status.strategy.rsi_overbought_threshold}
                    </span>
                  </div>
                </div>
              </div>
              <div>
                <h7 class="text-md font-medium mb-3 block">Last Check</h7>
                <%= if @strategy_status.last_check do %>
                  <div>
                    <span class="font-medium text-gray-600">Date:</span>
                    <span class="ml-2">
                      {Calendar.strftime(@strategy_status.last_check, "%Y-%m-%d %H:%M:%S")}
                    </span>
                  </div>
                <% end %>

                <%= if @strategy_status.last_result do %>
                  <%= if Map.has_key?(@strategy_status.last_result, :signal) do %>
                    <div class="mt-2">
                      <span class="font-medium text-gray-600">Signal:</span>
                      <span class="ml-2 capitalize">{@strategy_status.last_result.signal}</span>
                    </div>
                    <div>
                      <span class="font-medium text-gray-600">Price:</span>
                      <span class="ml-2">{@strategy_status.last_result.price} USDT</span>
                    </div>
                    <%= if Map.get(@strategy_status.last_result, :reasons) do %>
                      <div>
                        <span class="font-medium text-gray-600">Reasons:</span>
                        <span class="ml-2">
                          {Enum.join(@strategy_status.last_result.reasons, ", ")}
                        </span>
                      </div>
                    <% end %>
                  <% else %>
                    <div class="mt-2 text-red-600">
                      <span class="font-medium">Error:</span>
                      <span class="ml-2">{inspect(@strategy_status.last_result.error)}</span>
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>

            <div class="mt-6 flex space-x-4">
              <button
                phx-click="run_now"
                class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 cursor-pointer"
              >
                Run Now
              </button>
              <button
                phx-click="stop_strategy"
                class="bg-red-600 text-white px-4 py-2 rounded-md hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2 cursor-pointer"
              >
                Stop Strategy
              </button>
            </div>
          </div>
        </div>
      <% end %>

      <div class="mt-8">
        <h6 class="text-lg font-semibold mb-4">Strategy Analysis</h6>
        <div class="bg-white rounded-lg shadow p-6">
          <div class="mb-6">
            <h7 class="text-md font-medium mb-3">MA Crossover Strategy Parameters</h7>
            <form phx-submit="test_strategy" class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Timeframe</label>
                <select
                  name="timeframe"
                  class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                >
                  <option value="1m">1 minute</option>
                  <option value="5m">5 minutes</option>
                  <option value="15m">15 minutes</option>
                  <option value="1h" selected>1 hour</option>
                  <option value="4h">4 hours</option>
                  <option value="1d">1 day</option>
                </select>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Fast Period</label>
                <input
                  type="number"
                  name="fast_period"
                  value="9"
                  min="1"
                  max="50"
                  class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Slow Period</label>
                <input
                  type="number"
                  name="slow_period"
                  value="21"
                  min="1"
                  max="100"
                  class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Min Profit (%)</label>
                <input
                  type="number"
                  name="min_profit"
                  value="0.5"
                  step="0.1"
                  min="0"
                  max="10"
                  class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Max Loss (%)</label>
                <input
                  type="number"
                  name="max_loss"
                  value="-0.5"
                  step="0.1"
                  min="-10"
                  max="0"
                  class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Backtest Days</label>
                <input
                  type="number"
                  name="days"
                  value="30"
                  min="1"
                  max="365"
                  class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                />
              </div>
              <div class="md:col-span-3">
                <button
                  type="submit"
                  class="w-full bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 cursor-pointer"
                >
                  Test Strategy
                </button>
              </div>
            </form>
          </div>

          <%= if @simulation_results do %>
            <div class="mt-6 p-4 bg-gray-50 rounded-lg">
              <h7 class="text-md font-medium mb-4 block">Simulation Results</h7>
              <%= if Map.has_key?(@simulation_results, :error) do %>
                <div class="p-4 bg-red-100 text-red-800 rounded">
                  <p class="font-medium">Simulation failed:</p>
                  <p>{inspect(@simulation_results.error)}</p>
                </div>
              <% else %>
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                  <div class="bg-white p-3 rounded-lg shadow">
                    <div class="text-sm text-gray-600">Initial Investment</div>
                    <div class="text-lg font-medium">
                      {@simulation_results.initial_investment} USDT
                    </div>
                  </div>
                  <div class="bg-white p-3 rounded-lg shadow">
                    <div class="text-sm text-gray-600">Final Value</div>
                    <div class="text-lg font-medium">{@simulation_results.final_value} USDT</div>
                  </div>
                  <div class={"bg-white p-3 rounded-lg shadow #{if Decimal.to_float(@simulation_results.roi_percentage) > 0, do: "text-green-600", else: "text-red-600"}"}>
                    <div class="text-sm text-gray-600">ROI</div>
                    <div class="text-lg font-medium">
                      {Decimal.to_float(@simulation_results.roi_percentage)}%
                    </div>
                  </div>
                </div>

                <div class="bg-white p-4 rounded-lg shadow">
                  <div class="font-medium text-gray-700 mb-2">
                    Trade History ({length(@simulation_results.trades)} trades)
                  </div>

                  <div class="overflow-x-auto">
                    <table class="min-w-full text-sm divide-y divide-gray-200">
                      <thead>
                        <tr>
                          <th class="px-4 py-2 text-left font-medium text-gray-500">Date</th>
                          <th class="px-4 py-2 text-left font-medium text-gray-500">Type</th>
                          <th class="px-4 py-2 text-left font-medium text-gray-500">Price</th>
                        </tr>
                      </thead>
                      <tbody class="divide-y divide-gray-200">
                        <%= for trade <- @simulation_results.trades do %>
                          <tr class="hover:bg-gray-50">
                            <td class="px-4 py-2">
                              {Calendar.strftime(trade.date, "%Y-%m-%d %H:%M:%S")}
                            </td>
                            <td class="px-4 py-2 capitalize">{trade.type}</td>
                            <td class="px-4 py-2">{trade.price} USDT</td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <%= if !@strategy_status || @strategy_status.status != :running do %>
        <div class="mt-8">
          <h6 class="text-lg font-semibold mb-4">Start Trading</h6>
          <div class="bg-white rounded-lg shadow p-6">
            <form phx-submit="start_strategy" class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Investment Amount (USDT)
                </label>
                <input
                  type="number"
                  name="investment_amount"
                  value="500"
                  min="10"
                  step="10"
                  class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Max Risk Percentage
                </label>
                <input
                  type="number"
                  name="max_risk_percentage"
                  value="2"
                  min="0.5"
                  max="10"
                  step="0.5"
                  class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                />
              </div>
              <div class="md:col-span-2">
                <button
                  type="submit"
                  class="w-full bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2 cursor-pointer"
                >
                  Start Strategy
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </.live_component>
    """
  end
end
