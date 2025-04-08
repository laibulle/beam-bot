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
       sync_progress: nil,
       sync_stats: nil
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
         sync_progress: %{status: :initializing},
         sync_stats: nil
       )}
    end
  end

  def handle_info({:sync_progress, progress}, socket) do
    stats =
      case progress.status do
        :started ->
          %{
            total_tasks: progress.total_tasks,
            percentage: 0
          }

        :processing_chunk ->
          %{
            chunk_index: progress.chunk_index,
            total_chunks: progress.total_chunks,
            current_tasks: progress.current_tasks,
            percentage: (progress.chunk_index - 1) / progress.total_chunks * 100
          }

        :chunk_completed ->
          %{
            completed_tasks: progress.completed_tasks,
            successful_tasks: progress.successful_tasks,
            failed_tasks: progress.failed_tasks,
            percentage: progress.percentage
          }

        :completed ->
          %{
            total_tasks: progress.total_tasks,
            successful_tasks: progress.successful_tasks,
            failed_tasks: progress.failed_tasks,
            percentage: 100
          }
      end

    {:noreply,
     assign(socket,
       sync_progress: progress,
       sync_stats: stats,
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

            <%= if not is_nil(@sync_stats) do %>
              <div class="mt-4">
                <div class="w-full bg-gray-200 rounded-full h-2.5">
                  <div
                    class="bg-blue-600 h-2.5 rounded-full transition-all duration-300"
                    style={"width: #{@sync_stats.percentage}%"}
                  >
                  </div>
                </div>

                <div class="mt-2 text-sm text-gray-600">
                  <%= case @sync_progress.status do %>
                    <% :started -> %>
                      Initializing sync for {@sync_stats.total_tasks} tasks
                    <% :processing_chunk -> %>
                      Processing chunk {@sync_stats.chunk_index} of {@sync_stats.total_chunks}
                    <% :chunk_completed -> %>
                      Progress: {Float.round(@sync_stats.percentage, 1)}%
                      ({@sync_stats.completed_tasks} tasks completed) <br />
                      Successful: {@sync_stats.successful_tasks} | Failed: {@sync_stats.failed_tasks}
                    <% :completed -> %>
                      Sync completed! {@sync_stats.successful_tasks} tasks successful, {@sync_stats.failed_tasks} failed
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
