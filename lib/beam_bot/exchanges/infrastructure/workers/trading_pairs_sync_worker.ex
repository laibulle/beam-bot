defmodule BeamBot.Exchanges.Infrastructure.Workers.TradingPairsSyncWorker do
  @moduledoc """
  A GenServer that periodically syncs trading pairs from Binance.
  """
  use GenServer
  require Logger

  alias BeamBot.Exchanges.UseCases.SyncTradingPairsUseCase

  @sync_interval :timer.minutes(60)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_state) do
    # Trigger immediate sync
    send(self(), :sync_trading_pairs)
    # Schedule next sync
    schedule_sync()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sync_trading_pairs, state) do
    case SyncTradingPairsUseCase.sync_trading_pairs() do
      {:ok, trading_pairs} ->
        Logger.debug("Successfully synced #{length(trading_pairs)} trading pairs")

      {:error, reason} ->
        Logger.error("Failed to sync trading pairs: #{inspect(reason)}")
    end

    # Schedule next sync
    schedule_sync()
    {:noreply, state}
  end

  defp schedule_sync do
    Process.send_after(self(), :sync_trading_pairs, @sync_interval)
  end
end
