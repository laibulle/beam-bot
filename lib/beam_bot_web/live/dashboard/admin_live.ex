defmodule BeamBotWeb.AdminLive do
  @moduledoc """
  Admin live view.
  """

  use BeamBotWeb, :live_view

  alias BeamBot.Exchanges.UseCases.SyncAllHistoricalDataForPlatformUseCase

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       sync_in_progress: false,
       sync_progress: nil
     )}
  end

  def handle_event("sync_historical_data", _params, socket) do
    if socket.assigns.sync_in_progress do
      {:noreply, socket}
    else
      live_view_pid = self()
      # Start the sync process in a separate task
      _ =
        Task.start(fn ->
          SyncAllHistoricalDataForPlatformUseCase.sync_all_historical_data_for_platform(
            "binance",
            live_view_pid
          )
        end)

      {:noreply,
       assign(socket,
         sync_in_progress: true,
         sync_progress: %{
           status: :initializing,
           total_tasks: 0,
           completed_tasks: 0,
           successful_tasks: 0,
           failed_tasks: 0,
           percentage: 0.0
         },
         sync_stats: nil
       )}
    end
  end

  def handle_info({:sync_progress, progress}, socket) do
    {:noreply,
     assign(socket,
       sync_progress: progress,
       sync_in_progress: progress.status != :completed
     )}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={BeamBotWeb.Layouts.DashboardComponent}
      id="dashboard"
      current_user={@current_user}
    >
      <div class="container mx-auto px-4 py-8">
        <h1 class="text-2xl font-bold mb-6">Admin Dashboard</h1>

        <div class="bg-white rounded-lg shadow p-6">
          <h2 class="text-xl font-semibold mb-4">Data Management</h2>

          <div class="space-y-4">
            <button
              phx-click="sync_historical_data"
              disabled={@sync_in_progress}
              class={[
                "px-4 py-2 rounded-md text-white font-medium",
                if(@sync_in_progress,
                  do: "bg-gray-400 cursor-not-allowed",
                  else: "bg-blue-600 hover:bg-blue-700"
                )
              ]}
            >
              {if @sync_in_progress, do: "Syncing...", else: "Sync Historical Data"}
            </button>

            <%= if not is_nil(@sync_progress) and @sync_progress.status != :initializing do %>
              <div class="mt-4">
                <div class="w-full bg-gray-200 rounded-full h-2.5">
                  <div
                    class="bg-blue-600 h-2.5 rounded-full transition-all duration-300"
                    style={"width: #{@sync_progress.percentage}%"}
                  >
                  </div>
                </div>

                <div class="mt-2 text-sm text-gray-600">
                  <%= case @sync_progress.status do %>
                    <% :started -> %>
                      Starting sync for {@sync_progress.total_tasks} tasks...
                    <% :in_progress -> %>
                      Progress: {Float.round(@sync_progress.percentage, 1)}%
                      ({@sync_progress.completed_tasks}/{@sync_progress.total_tasks} tasks) <br />
                      Successful: {@sync_progress.successful_tasks} | Failed: {@sync_progress.failed_tasks}
                    <% :completed -> %>
                      Sync completed! {@sync_progress.successful_tasks}/{@sync_progress.total_tasks} tasks successful, {@sync_progress.failed_tasks} failed.
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </.live_component>
    """
  end
end
