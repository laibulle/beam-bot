defmodule BeamBotWeb.Dashboard.StrategiesLive do
  use BeamBotWeb, :live_view

  require Logger

  alias BeamBot.Strategies.UseCases.FindBestTradingPairSmallInvestorUseCase

  @trading_pairs_repository Application.compile_env(:beam_bot, :trading_pairs_repository)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(BeamBot.PubSub, "strategies:progress")
    end

    {:ok,
     socket
     |> assign(:loading, false)
     |> assign(:results, [])
     |> assign(:error, nil)
     |> assign(:progress, 0)
     |> assign(:total_pairs, 0)
     |> assign(:task_ref, nil)}
  end

  @impl true
  def handle_event("find_best_pairs", params, socket) do
    Logger.info("Starting find_best_pairs with params: #{inspect(params)}")

    # Set loading state
    socket = assign(socket, loading: true, results: [], error: nil, progress: 0)

    # Convert string params to atom keys
    converted_params = %{
      investment_amount: params["investment_amount"],
      timeframe: params["timeframe"],
      rsi_oversold: params["rsi_oversold"],
      rsi_overbought: params["rsi_overbought"],
      days: params["days"]
    }

    # Get total number of active trading pairs
    active_symbols =
      @trading_pairs_repository.list_trading_pairs()
      |> Enum.filter(& &1.is_active)

    total_pairs = length(active_symbols)
    Logger.info("Found #{total_pairs} active trading pairs")

    # Start async task with streaming
    task =
      Task.async(fn ->
        Logger.info("Starting task with params: #{inspect(converted_params)}")

        result =
          FindBestTradingPairSmallInvestorUseCase.find_best_trading_pairs_small_investor_stream(
            converted_params,
            fn result ->
              Logger.info("Received result: #{inspect(result)}")
              # Send progress update to LiveView
              Phoenix.PubSub.broadcast(
                BeamBot.PubSub,
                "strategies:progress",
                {:progress_update, result}
              )
            end
          )

        Logger.info("Task completed with result: #{inspect(result)}")
        # Send final result to LiveView
        Phoenix.PubSub.broadcast(BeamBot.PubSub, "strategies:progress", {:task_complete, result})
        result
      end)

    # Monitor the task process
    Process.monitor(task.pid)

    {:noreply, assign(socket, total_pairs: total_pairs, task_ref: task.ref)}
  end

  @impl true
  def handle_info({:progress_update, result}, socket) do
    Logger.info("Received progress update: #{inspect(result)}")

    # Update results list with new result and sort by ROI
    new_results =
      [result | socket.assigns.results]
      |> Enum.reject(&Map.has_key?(&1, :error))
      |> Enum.sort_by(
        fn %{simulation_results: results} ->
          Decimal.to_float(results.roi_percentage)
        end,
        :desc
      )

    # Calculate progress
    progress = min(100, round(length(new_results) / socket.assigns.total_pairs * 100))
    Logger.info("Updated progress: #{progress}% with #{length(new_results)} results")

    {:noreply,
     assign(socket,
       results: new_results,
       progress: progress,
       total_pairs: socket.assigns.total_pairs
     )}
  end

  @impl true
  def handle_info({:task_complete, {:ok, final_results}}, socket) do
    Logger.info("Task completed with results: #{inspect(final_results)}")
    Logger.info("Current socket assigns: #{inspect(socket.assigns)}")

    # Update results with final results and sort by ROI
    final_results_list =
      final_results
      |> Enum.reject(&Map.has_key?(&1, :error))
      |> Enum.sort_by(
        fn %{simulation_results: results} ->
          Decimal.to_float(results.roi_percentage)
        end,
        :desc
      )

    {:noreply, assign(socket, loading: false, progress: 100, results: final_results_list)}
  end

  @impl true
  def handle_info({ref, {:ok, final_results}}, socket) when is_reference(ref) do
    Logger.info("Task completed with results: #{inspect(final_results)}")
    Logger.info("Current socket assigns: #{inspect(socket.assigns)}")

    # Update results with final results and sort by ROI
    final_results_list =
      final_results
      |> Enum.reject(&Map.has_key?(&1, :error))
      |> Enum.sort_by(
        fn %{simulation_results: results} ->
          Decimal.to_float(results.roi_percentage)
        end,
        :desc
      )

    {:noreply, assign(socket, loading: false, progress: 100, results: final_results_list)}
  end

  @impl true
  def handle_info({:task_complete, {:error, reason}}, socket) do
    Logger.error("Task failed with reason: #{inspect(reason)}")
    Logger.info("Current socket assigns: #{inspect(socket.assigns)}")
    {:noreply, assign(socket, loading: false, error: reason)}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, socket) when is_reference(ref) do
    Logger.info("Task process down with reason: #{inspect(reason)}")
    Logger.info("Current socket assigns: #{inspect(socket.assigns)}")
    {:noreply, assign(socket, task_ref: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={BeamBotWeb.Layouts.DashboardComponent}
      id="dashboard"
      current_user={@current_user}
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
                    Analyzing... {@progress}%
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

        <%= if @results != [] do %>
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
                      <.link
                        navigate={~p"/dashboard/trading-pair/#{result.trading_pair}"}
                        class="flex-1 min-w-0"
                      >
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
                            ROI: {Decimal.round(result.simulation_results.roi_percentage, 2)}%
                          </div>
                        </div>
                      </.link>
                      <div class="ml-4 flex-shrink-0">
                        <div class="text-sm text-gray-900">
                          Initial: {result.simulation_results.initial_investment} USDT
                        </div>
                        <div class="text-sm text-gray-500">
                          Final: {Decimal.round(result.simulation_results.final_value, 2)} USDT
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
