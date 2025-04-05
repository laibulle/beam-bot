defmodule BeamBotWeb.Dashboard.StrategiesLive do
  use BeamBotWeb, :live_view

  require Logger

  alias BeamBot.Strategies.UseCases.FindBestTradingPairSmallInvestorUseCase

  @simulation_results_repository Application.compile_env(
                                   :beam_bot,
                                   :simulation_results_repository
                                 )

  @impl true
  def mount(_params, _session, socket) do
    # Default form settings
    form_settings = %{
      investment_amount: "5",
      timeframe: "1h",
      rsi_oversold: "30",
      rsi_overbought: "70",
      days: "30"
    }

    # Load previous simulations if user is authenticated
    previous_simulations =
      case socket.assigns do
        %{current_user: %{id: user_id}} ->
          @simulation_results_repository.get_simulation_results_by_user_id(user_id)

        _ ->
          []
      end

    {:ok,
     assign(socket,
       loading: false,
       results: [],
       error: nil,
       progress: 0,
       form_settings: form_settings,
       previous_simulations: previous_simulations
     )}
  end

  @impl true
  def handle_event("find_best_pairs", params, socket) do
    # Convert params and start analysis
    converted_params = prepare_params(params, socket.assigns.current_user.id)
    form_settings = extract_form_settings(params)
    _ = start_analysis(converted_params)

    {:noreply,
     assign(socket,
       loading: true,
       progress: 0,
       results: [],
       form_settings: form_settings
     )}
  end

  @impl true
  def handle_info({:task_complete, {:ok, results}}, socket) do
    Logger.debug("Task complete with results: #{inspect(results)}")
    final_results = process_results(results)
    Logger.debug("Processed results: #{inspect(final_results)}")

    # Save each simulation result
    saved_simulations =
      Enum.map(final_results, fn result ->
        simulation_attrs = %{
          "trading_pair" => result.trading_pair,
          "initial_investment" => result.simulation_results.initial_investment,
          "final_value" => result.simulation_results.final_value,
          "roi_percentage" => result.simulation_results.roi_percentage,
          "start_date" => result.simulation_results.start_date,
          "end_date" => result.simulation_results.end_date,
          "user_id" => socket.assigns.current_user.id,
          "trades" => result.simulation_results.trades
        }

        case @simulation_results_repository.save_simulation_result(simulation_attrs) do
          {:ok, simulation} -> simulation
          {:error, _reason} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    # Update previous simulations list with new results
    updated_previous_simulations =
      (saved_simulations ++ socket.assigns.previous_simulations)
      |> Enum.sort_by(&Decimal.to_float(&1.roi_percentage), :desc)
      # Keep only top 100 simulations
      |> Enum.take(100)

    {:noreply,
     assign(socket,
       loading: false,
       progress: 100,
       results: final_results,
       previous_simulations: updated_previous_simulations
     )}
  end

  @impl true
  def handle_info({:task_complete, {:error, reason}}, socket) do
    Logger.error("Task failed with error: #{inspect(reason)}")
    {:noreply, assign(socket, loading: false, error: reason)}
  end

  @impl true
  def handle_info({:progress_update, progress}, socket) do
    Logger.debug("Progress update: #{progress}%")
    {:noreply, assign(socket, progress: progress)}
  end

  # Private helpers

  defp prepare_params(params, user_id) do
    %{
      investment_amount: params["investment_amount"],
      timeframe: params["timeframe"],
      rsi_oversold: params["rsi_oversold"],
      rsi_overbought: params["rsi_overbought"],
      days: params["days"],
      user_id: user_id
    }
  end

  defp extract_form_settings(params) do
    %{
      investment_amount: params["investment_amount"],
      timeframe: params["timeframe"],
      rsi_oversold: params["rsi_oversold"],
      rsi_overbought: params["rsi_overbought"],
      days: params["days"]
    }
  end

  defp start_analysis(params) do
    parent = self()

    Task.start(fn ->
      handle_analysis_result(
        FindBestTradingPairSmallInvestorUseCase.find_best_trading_pairs_small_investor_stream(
          params,
          fn results -> handle_batch_results(results, parent) end
        )
      )
    end)
  end

  defp handle_analysis_result({:ok, _}), do: :ok

  defp handle_batch_results({results, progress}, pid) do
    # Always send the progress update
    send(pid, {:progress_update, progress})

    # Only send task completion if we have final results (100% progress)
    if progress >= 100 do
      send(pid, {:task_complete, {:ok, results}})
    end
  end

  defp process_results(results) do
    results
    |> Enum.reject(&Map.has_key?(&1, :error))
    |> Enum.sort_by(
      fn %{simulation_results: results} -> results.roi_percentage end,
      fn a, b -> Decimal.compare(a, b) == :gt end
    )
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
                value={@form_settings.investment_amount}
                min="1"
                step="1"
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
                <option value="1m" selected={@form_settings.timeframe == "1m"}>1 minute</option>
                <option value="5m" selected={@form_settings.timeframe == "5m"}>5 minutes</option>
                <option value="15m" selected={@form_settings.timeframe == "15m"}>15 minutes</option>
                <option value="1h" selected={@form_settings.timeframe == "1h"}>1 hour</option>
                <option value="4h" selected={@form_settings.timeframe == "4h"}>4 hours</option>
                <option value="1d" selected={@form_settings.timeframe == "1d"}>1 day</option>
              </select>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                RSI Oversold Threshold
              </label>
              <input
                type="number"
                name="rsi_oversold"
                value={@form_settings.rsi_oversold}
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
                value={@form_settings.rsi_overbought}
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
                value={@form_settings.days}
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

        <%= if @previous_simulations && length(@previous_simulations) > 0 do %>
          <div class="mt-8">
            <h6 class="text-lg font-semibold mb-4">Previous Simulations</h6>
            <div class="bg-white rounded-lg shadow overflow-hidden">
              <div class="overflow-x-auto">
                <table class="min-w-full text-sm divide-y divide-gray-200">
                  <thead>
                    <tr>
                      <th class="px-4 py-2 text-left font-medium text-gray-500">Date</th>
                      <th class="px-4 py-2 text-left font-medium text-gray-500">Trading Pair</th>
                      <th class="px-4 py-2 text-left font-medium text-gray-500">Investment</th>
                      <th class="px-4 py-2 text-left font-medium text-gray-500">Final Value</th>
                      <th class="px-4 py-2 text-left font-medium text-gray-500">ROI</th>
                      <th class="px-4 py-2 text-left font-medium text-gray-500">Trades</th>
                      <th class="px-4 py-2 text-left font-medium text-gray-500">Actions</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-200">
                    <%= for simulation <- @previous_simulations do %>
                      <tr class="hover:bg-gray-50">
                        <td class="px-4 py-2">
                          {simulation.start_date |> Calendar.strftime("%Y-%m-%d %H:%M")}
                        </td>
                        <td class="px-4 py-2">
                          {simulation.trading_pair}
                        </td>
                        <td class="px-4 py-2">
                          {simulation.initial_investment} USDT
                        </td>
                        <td class="px-4 py-2">
                          {:erlang.float_to_binary(Decimal.to_float(simulation.final_value),
                            decimals: 2
                          )} USDT
                        </td>
                        <td class={"px-4 py-2 #{if Decimal.to_float(simulation.roi_percentage) > 0, do: "text-green-600", else: "text-red-600"}"}>
                          {:erlang.float_to_binary(Decimal.to_float(simulation.roi_percentage),
                            decimals: 2
                          )}%
                        </td>
                        <td class="px-4 py-2">
                          {length(simulation.trades)}
                        </td>
                        <td class="px-4 py-2">
                          <.link
                            navigate={~p"/dashboard/trading-pair/#{simulation.trading_pair}"}
                            class="text-blue-600 hover:text-blue-800 font-medium"
                          >
                            View Details
                          </.link>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </.live_component>
    """
  end
end
