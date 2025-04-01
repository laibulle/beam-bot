defmodule BeamBotWeb.TradingPairLive do
  use BeamBotWeb, :live_view

  @trading_pairs_repository Application.compile_env(:beam_bot, :trading_pairs_repository)
  @klines_repository Application.compile_env(:beam_bot, :klines_repository)

  # Define refresh interval in milliseconds
  @refresh_interval 10_000

  alias BeamBot.Strategies.Infrastructure.Workers.SmallInvestorStrategyWorker
  alias BeamBot.Strategies.Domain.{SmallInvestorStrategy, StrategyRunner}

  @impl true
  def mount(%{"symbol" => symbol}, _session, socket) do
    if connected?(socket) do
      # Schedule periodic refresh of strategy status
      Process.send_after(self(), :refresh_status, @refresh_interval)
    end

    {:ok, trading_pair} = @trading_pairs_repository.get_trading_pair_by_symbol(symbol)

    {:ok, data} = @klines_repository.get_klines(symbol, "1h")

    # Get strategy status if it exists
    strategy_status = SmallInvestorStrategyWorker.get_status()

    {:ok,
     socket
     |> assign(data: data)
     |> assign(trading_pair: trading_pair)
     |> assign(strategy_status: strategy_status)
     |> assign(strategy_message: nil)
     |> assign(simulation_results: nil)
     |> assign(simulating: false)}
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
  def handle_info({ref, {:simulation_complete, results}}, socket) when is_reference(ref) do
    # Demonitor the task to avoid memory leaks
    Process.demonitor(ref, [:flush])

    # Update socket with simulation results
    {:noreply, socket |> assign(simulation_results: results, simulating: false)}
  end

  @impl true
  def handle_info({ref, {:simulation_error, reason}}, socket) when is_reference(ref) do
    # Demonitor the task to avoid memory leaks
    Process.demonitor(ref, [:flush])

    # Update socket with error
    error_results = %{error: reason}
    {:noreply, socket |> assign(simulation_results: error_results, simulating: false)}
  end

  # Handle DOWN messages from the spawned task
  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "start_strategy",
        %{"investment_amount" => investment_amount, "max_risk_percentage" => max_risk_percentage} =
          _params,
        socket
      ) do
    trading_pair = socket.assigns.trading_pair

    # Convert string amount to Decimal
    decimal_amount = Decimal.new(investment_amount)

    # Convert and validate max_risk_percentage (use Decimal to avoid float conversion issues)
    decimal_max_risk =
      case max_risk_percentage do
        risk when is_binary(risk) -> Decimal.new(risk)
        risk when is_float(risk) -> Decimal.from_float(risk)
        risk when is_integer(risk) -> Decimal.new(risk)
      end

    # Prepare options
    options = [
      max_risk_percentage: decimal_max_risk
    ]

    # Start the strategy worker
    :ok = SmallInvestorStrategyWorker.start_strategy(trading_pair.symbol, decimal_amount, options)

    # Get updated status
    strategy_status = SmallInvestorStrategyWorker.get_status()

    message =
      "Started strategy for #{trading_pair.symbol} with investment amount #{investment_amount} USDT"

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
  def handle_event("simulate_strategy", params, socket) do
    %{
      "investment_amount" => investment_amount,
      "timeframe" => timeframe,
      "rsi_oversold" => rsi_oversold,
      "rsi_overbought" => rsi_overbought,
      "days" => days
    } = params

    trading_pair = socket.assigns.trading_pair

    # Set simulating status to show loading indicator
    socket = assign(socket, simulating: true, simulation_results: nil)

    # Convert params to appropriate types
    decimal_amount = Decimal.new(investment_amount)
    days_ago = String.to_integer(days)
    oversold = String.to_integer(rsi_oversold)
    overbought = String.to_integer(rsi_overbought)

    # Create options
    options = [
      timeframe: timeframe,
      rsi_oversold_threshold: oversold,
      rsi_overbought_threshold: overbought
    ]

    # Create strategy
    strategy = SmallInvestorStrategy.new(trading_pair.symbol, decimal_amount, options)

    # Calculate start and end dates
    end_date = DateTime.utc_now()
    start_date = DateTime.add(end_date, -days_ago * 24 * 60 * 60, :second)

    # Execute simulation in Task to avoid blocking the LiveView process
    Task.async(fn ->
      # Start the StrategyRunner GenServer
      {:ok, pid} = StrategyRunner.start_link(strategy)

      case StrategyRunner.run_simulation(pid, start_date, end_date) do
        {:ok, results} -> {:simulation_complete, results}
        {:error, reason} -> {:simulation_error, reason}
      end
    end)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={BeamBotWeb.Layouts.DashboardComponent}
      id="dashboard"
      current_user={@current_user}
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
                  <span class="font-medium">Min Price:</span> {:erlang.float_to_binary(
                    Decimal.to_float(@trading_pair.min_price),
                    decimals: 4
                  )}
                </div>
                <div class="text-sm text-gray-600">
                  <span class="font-medium">Max Price:</span> {:erlang.float_to_binary(
                    Decimal.to_float(@trading_pair.max_price),
                    decimals: 2
                  )}
                </div>
                <div class="text-sm text-gray-600">
                  <span class="font-medium">Tick Size:</span> {:erlang.float_to_binary(
                    Decimal.to_float(@trading_pair.tick_size),
                    decimals: 4
                  )}
                </div>
              </div>
            </div>
            <div class="bg-gray-50 p-3 rounded-lg">
              <div class="font-medium text-gray-700 mb-2">Quantity Limits</div>
              <div class="space-y-1">
                <div class="text-sm text-gray-600">
                  <span class="font-medium">Min Quantity:</span> {:erlang.float_to_binary(
                    Decimal.to_float(@trading_pair.min_qty),
                    decimals: 4
                  )}
                </div>
                <div class="text-sm text-gray-600">
                  <span class="font-medium">Max Quantity:</span> {:erlang.float_to_binary(
                    Decimal.to_float(@trading_pair.max_qty),
                    decimals: 2
                  )}
                </div>
                <div class="text-sm text-gray-600">
                  <span class="font-medium">Step Size:</span> {:erlang.float_to_binary(
                    Decimal.to_float(@trading_pair.step_size),
                    decimals: 4
                  )}
                </div>
              </div>
            </div>
            <div class="bg-gray-50 p-3 rounded-lg">
              <div class="font-medium text-gray-700 mb-2">Other Rules</div>
              <div class="space-y-1">
                <div class="text-sm text-gray-600">
                  <span class="font-medium">Min Notional:</span> {:erlang.float_to_binary(
                    Decimal.to_float(@trading_pair.min_notional),
                    decimals: 2
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="mt-8">
        <h6 class="text-lg font-semibold mb-4">Price Chart</h6>
        <div class="bg-white rounded-lg shadow p-6">
          <canvas
            id="priceChart"
            phx-hook="PriceChart"
            data-chart-data={Jason.encode!(transform_klines_for_chart(@data))}
          >
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
        <h6 class="text-lg font-semibold mb-4">Strategy Simulation</h6>
        <div class="bg-white rounded-lg shadow p-6">
          <form phx-submit="simulate_strategy" class="grid grid-cols-1 md:grid-cols-3 gap-4">
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
              <label class="block text-sm font-medium text-gray-700 mb-1">Days to Simulate</label>
              <input
                type="number"
                name="days"
                value="30"
                min="1"
                max="365"
                class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                RSI Oversold Threshold
              </label>
              <input
                type="number"
                name="rsi_oversold"
                value="30"
                min="1"
                max="49"
                class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                RSI Overbought Threshold
              </label>
              <input
                type="number"
                name="rsi_overbought"
                value="70"
                min="51"
                max="99"
                class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              />
            </div>
            <div class="self-end">
              <button
                type="submit"
                disabled={@simulating}
                class="w-full bg-indigo-600 text-white px-4 py-2 rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <%= if @simulating do %>
                  <span class="flex items-center justify-center">
                    <svg
                      class="animate-spin -ml-1 mr-3 h-5 w-5 text-white"
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <circle
                        class="opacity-25"
                        cx="12"
                        cy="12"
                        r="10"
                        stroke="currentColor"
                        stroke-width="4"
                      >
                      </circle>
                      <path
                        class="opacity-75"
                        fill="currentColor"
                        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                      >
                      </path>
                    </svg>
                    Simulating...
                  </span>
                <% else %>
                  Run Simulation
                <% end %>
              </button>
            </div>
          </form>

          <%= if @simulation_results do %>
            <div class="mt-6">
              <%= if Map.has_key?(@simulation_results, :error) do %>
                <div class="p-4 bg-red-100 text-red-800 rounded">
                  <p class="font-medium">Simulation failed:</p>
                  <p>{inspect(@simulation_results.error)}</p>
                </div>
              <% else %>
                <div class="mb-6">
                  <h7 class="text-md font-medium mb-4 block">Simulation Results</h7>
                  <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                    <div class="bg-gray-50 p-3 rounded-lg">
                      <div class="text-sm text-gray-600">Initial Investment</div>
                      <div class="text-lg font-medium">
                        {@simulation_results.initial_investment} USDT
                      </div>
                    </div>
                    <div class="bg-gray-50 p-3 rounded-lg">
                      <div class="text-sm text-gray-600">Final Value</div>
                      <div class="text-lg font-medium">
                        {:erlang.float_to_binary(Decimal.to_float(@simulation_results.final_value),
                          decimals: 2
                        )} USDT
                      </div>
                    </div>
                    <div class={"bg-gray-50 p-3 rounded-lg #{if Decimal.to_float(@simulation_results.roi_percentage) > 0, do: "text-green-600", else: "text-red-600"}"}>
                      <div class="text-sm text-gray-600">ROI</div>
                      <div class="text-lg font-medium">
                        {:erlang.float_to_binary(Decimal.to_float(@simulation_results.roi_percentage),
                          decimals: 2
                        )}%
                      </div>
                    </div>
                  </div>

                  <div class="bg-gray-50 p-4 rounded-lg">
                    <div class="font-medium text-gray-700 mb-3">
                      Trade History ({length(@simulation_results.trades)} trades)
                    </div>

                    <div class="overflow-x-auto">
                      <table class="min-w-full text-sm divide-y divide-gray-200">
                        <thead>
                          <tr>
                            <th class="px-4 py-2 text-left font-medium text-gray-500">Date</th>
                            <th class="px-4 py-2 text-left font-medium text-gray-500">Type</th>
                            <th class="px-4 py-2 text-left font-medium text-gray-500">Price</th>
                            <th class="px-4 py-2 text-left font-medium text-gray-500">Amount</th>
                            <th class="px-4 py-2 text-left font-medium text-gray-500">Fee</th>
                          </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-200">
                          <%= for trade <- @simulation_results.trades do %>
                            <tr class="hover:bg-gray-50">
                              <td class="px-4 py-2">
                                {trade.date
                                |> Calendar.strftime("%Y-%m-%d %H:%M:%S")}
                              </td>
                              <td class={"px-4 py-2 capitalize #{if trade.type == :buy, do: "text-green-600", else: "text-red-600"}"}>
                                {trade.type}
                              </td>
                              <td class="px-4 py-2">
                                {:erlang.float_to_binary(Decimal.to_float(trade.price), decimals: 4)} USDT
                              </td>
                              <td class="px-4 py-2">
                                {:erlang.float_to_binary(Decimal.to_float(trade.amount), decimals: 8)} BTC
                              </td>
                              <td class="px-4 py-2 text-gray-600">
                                {:erlang.float_to_binary(Decimal.to_float(trade.fee), decimals: 2)} USDT
                              </td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  </div>
                </div>

                <%= if !@strategy_status || @strategy_status.status != :running do %>
                  <div class="text-center mt-4">
                    <form phx-submit="start_strategy" class="inline-block">
                      <input
                        type="hidden"
                        name="investment_amount"
                        value={@simulation_results.initial_investment}
                      />
                      <input type="hidden" name="max_risk_percentage" value="2.0" />
                      <button
                        type="submit"
                        class="bg-green-600 text-white px-6 py-2 rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2 cursor-pointer"
                      >
                        Start Trading with These Settings
                      </button>
                    </form>
                  </div>
                <% end %>
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
                  value="2.0"
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

  defp transform_klines_for_chart(klines) do
    Enum.map(klines, fn kline ->
      %{
        x: kline.timestamp,
        o: kline.open,
        h: kline.high,
        l: kline.low,
        c: kline.close
      }
    end)
  end
end
