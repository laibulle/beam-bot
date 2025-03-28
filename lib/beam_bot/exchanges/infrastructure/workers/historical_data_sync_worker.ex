defmodule BeamBot.Exchanges.Infrastructure.Workers.HistoricalDataSyncWorker do
  @moduledoc """
  A GenServer that periodically syncs historical market data from Binance to Redis.
  """

  use GenServer
  require Logger

  alias BeamBot.Exchanges.UseCases.SyncHistoricalDataUseCase

  # Sync every 6 hours
  @sync_interval :timer.hours(6)

  # Default trading pairs to sync
  @default_pairs ["BTCUSDT", "ETHUSDT", "BNBUSDT", "SOLUSDT"]

  # Default intervals to sync
  @default_intervals ["1h", "4h", "1d"]

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_state) do
    # Trigger immediate sync
    send(self(), :sync_historical_data)
    # Schedule next sync
    schedule_sync()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sync_historical_data, state) do
    case SyncHistoricalDataUseCase.sync_multiple_pairs(@default_pairs, @default_intervals) do
      {:ok, results} ->
        Logger.info("Successfully synced historical data: #{inspect(results)}")

      {:error, reason, results} ->
        Logger.error("Failed to sync some historical data: #{inspect(reason)}")
        Logger.error("Partial results: #{inspect(results)}")
    end

    # Schedule next sync
    schedule_sync()
    {:noreply, state}
  end

  defp schedule_sync do
    Process.send_after(self(), :sync_historical_data, @sync_interval)
  end
end
