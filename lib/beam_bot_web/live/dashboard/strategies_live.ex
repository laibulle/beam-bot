defmodule BeamBotWeb.Dashboard.StrategiesLive do
  use BeamBotWeb, :live_view

  alias BeamBot.Strategies.UseCases.FindBestTradingPairSmallInvestorUseCase

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:loading, false)
     |> assign(:results, nil)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("find_best_pairs", params, socket) do
    # Set loading state
    socket = assign(socket, loading: true, results: nil, error: nil)

    # Convert string params to atom keys
    converted_params = %{
      investment_amount: params["investment_amount"],
      timeframe: params["timeframe"],
      rsi_oversold: params["rsi_oversold"],
      rsi_overbought: params["rsi_overbought"],
      days: params["days"]
    }

    # Start async task
    Task.async(fn ->
      case FindBestTradingPairSmallInvestorUseCase.find_best_trading_pairs_small_investor(
             converted_params
           ) do
        {:ok, results} -> {:ok, results}
        {:error, reason} -> {:error, reason}
      end
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({ref, {:ok, results}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, assign(socket, loading: false, results: results)}
  end

  @impl true
  def handle_info({ref, {:error, reason}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, assign(socket, loading: false, error: reason)}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={BeamBotWeb.Layouts.DashboardComponent}
      id="dashboard"
      current_user={%{email: "fake"}}
    >
      <div class="container mx-auto px-4 py-8">
        <h1 class="text-3xl font-bold mb-8">Find Best Trading Pairs</h1>

        <div class="bg-white rounded-lg shadow p-6 mb-8">
          <form phx-submit="find_best_pairs" class="grid grid-cols-1 md:grid-cols-2 gap-4">
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
                required
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Timeframe
              </label>
              <select
                name="timeframe"
                class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                required
              >
                <option value="1h">1 Hour</option>
                <option value="4h">4 Hours</option>
                <option value="1d">1 Day</option>
              </select>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                RSI Oversold Threshold
              </label>
              <input
                type="number"
                name="rsi_oversold"
                value="30"
                min="0"
                max="100"
                class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                required
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
                min="0"
                max="100"
                class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                required
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Days to Analyze
              </label>
              <input
                type="number"
                name="days"
                value="30"
                min="1"
                max="365"
                class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                required
              />
            </div>

            <div class="md:col-span-2">
              <button
                type="submit"
                class="w-full bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 cursor-pointer"
                disabled={@loading}
              >
                <%= if @loading do %>
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
                    Analyzing...
                  </span>
                <% else %>
                  Find Best Pairs
                <% end %>
              </button>
            </div>
          </form>
        </div>

        <%= if @error do %>
          <div class="bg-red-50 border-l-4 border-red-400 p-4 mb-8">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                  <path
                    fill-rule="evenodd"
                    d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                    clip-rule="evenodd"
                  />
                </svg>
              </div>
              <div class="ml-3">
                <p class="text-sm text-red-700">
                  {@error}
                </p>
              </div>
            </div>
          </div>
        <% end %>

        <%= if @results do %>
          <div class="bg-white rounded-lg shadow overflow-hidden">
            <div class="px-4 py-5 sm:px-6">
              <h3 class="text-lg leading-6 font-medium text-gray-900">
                Best Trading Pairs
              </h3>
            </div>
            <div class="border-t border-gray-200">
              <ul role="list" class="divide-y divide-gray-200">
                <%= for result <- @results do %>
                  <li class="px-4 py-4 sm:px-6">
                    <div class="flex items-center justify-between">
                      <div class="flex-1 min-w-0">
                        <p class="text-sm font-medium text-blue-600 truncate">
                          {result.trading_pair}
                        </p>
                        <div class="mt-2 flex">
                          <div class="flex items-center text-sm text-gray-500">
                            <svg
                              class="flex-shrink-0 mr-1.5 h-5 w-5 text-gray-400"
                              xmlns="http://www.w3.org/2000/svg"
                              viewBox="0 0 20 20"
                              fill="currentColor"
                            >
                              <path
                                fill-rule="evenodd"
                                d="M4 4a2 2 0 00-2 2v8a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2H4zm3 5a1 1 0 011-1h.01a1 1 0 110 2H8a1 1 0 01-1-1zm2 3a1 1 0 011-1h.01a1 1 0 110 2H10a1 1 0 01-1-1zm4-3a1 1 0 011-1h.01a1 1 0 110 2H13a1 1 0 01-1-1zm2 3a1 1 0 011-1h.01a1 1 0 110 2H15a1 1 0 01-1-1z"
                                clip-rule="evenodd"
                              />
                            </svg>
                            ROI: {Float.round(result.simulation_results.roi_percentage, 2)}%
                          </div>
                        </div>
                      </div>
                      <div class="ml-4 flex-shrink-0">
                        <div class="text-sm text-gray-900">
                          Initial: {result.simulation_results.initial_investment} USDT
                        </div>
                        <div class="text-sm text-gray-500">
                          Final: {result.simulation_results.final_value} USDT
                        </div>
                      </div>
                    </div>
                  </li>
                <% end %>
              </ul>
            </div>
          </div>
        <% end %>
      </div>
    </.live_component>
    """
  end
end
