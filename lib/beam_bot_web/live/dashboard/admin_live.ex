defmodule BeamBotWeb.AdminLive do
  @moduledoc """
  Admin live view.
  """

  use BeamBotWeb, :live_view

  alias BeamBot.Exchanges.UseCases.SyncAllHistoricalDataForPlatformUseCase

  def mount(_params, _session, socket) do
    {:ok, assign(socket, sync_in_progress: false)}
  end

  def handle_event("sync_historical_data", _params, socket) do
    if socket.assigns.sync_in_progress do
      {:noreply, socket}
    else
      # Start the sync process in a separate task
      Task.start(fn ->
        SyncAllHistoricalDataForPlatformUseCase.sync_all_historical_data_for_platform("binance")
      end)

      {:noreply, assign(socket, sync_in_progress: true)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-2xl font-bold mb-6">Admin Dashboard</h1>

      <div class="bg-white rounded-lg shadow p-6">
        <h2 class="text-xl font-semibold mb-4">Data Management</h2>

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
      </div>
    </div>
    """
  end
end
