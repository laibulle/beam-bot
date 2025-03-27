defmodule BeamBotWeb.TradingPairLive do
  use BeamBotWeb, :live_view

  @binance_req_adapter Application.compile_env(:beam_bot, :binance_req_adapter)
  @trading_pairs_repository Application.compile_env(:beam_bot, :trading_pairs_repository)

  @impl true
  def mount(%{"symbol" => symbol}, _session, socket) do
    {:ok, trading_pair} = @trading_pairs_repository.get_trading_pair_by_symbol(symbol)
    {:ok, data} = @binance_req_adapter.get_klines(symbol, "1h")
    {:ok, socket |> assign(data: data) |> assign(trading_pair: trading_pair)}
  end

  @impl true
  def render(assigns) do
    ~H"""
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
        <canvas id="priceChart" phx-hook="PriceChart" data-chart-data={Jason.encode!(@data)}></canvas>
      </div>
    </div>

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
      </div>
    </div>
    """
  end
end
