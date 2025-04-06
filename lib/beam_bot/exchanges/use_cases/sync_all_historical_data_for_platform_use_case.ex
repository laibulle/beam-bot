defmodule BeamBot.Exchanges.UseCases.SyncAllHistoricalDataForPlatformUseCase do
  @moduledoc """
  This module is responsible for syncing all historical data for a platform.
  """

  alias BeamBot.Exchanges.UseCases.SyncHistoricalDataForSymbolUseCase
  require Logger

  @trading_pairs_adapter Application.compile_env(:beam_bot, :trading_pairs_repository)
  @max_concurrency Application.compile_env(
                     :beam_bot,
                     :sync_all_historical_data_for_platform_concurrent_pairs
                   )
  @intervals %{"1m" => 30, "1h" => 30, "1d" => 365, "1w" => 365, "1M" => 3650}

  @doc """
  Syncs all historical data for a platform.

  ## Parameters
    - platform: The platform to sync historical data for
    - progress_pid: The PID to send progress updates to

  ## Returns
    - :ok

  ## Example
      iex> BeamBot.Exchanges.UseCases.SyncAllHistoricalDataForPlatformUseCase.sync_all_historical_data_for_platform("binance", self())
      :ok
  """
  def sync_all_historical_data_for_platform(_platform, progress_pid) do
    # Get all symbols for the platform
    symbols = @trading_pairs_adapter.list_trading_pairs()
    total_pairs = length(symbols)
    total_intervals = map_size(@intervals)
    total_tasks = total_pairs * total_intervals

    send(
      progress_pid,
      {:sync_progress,
       %{
         status: :started,
         total_pairs: total_pairs,
         total_intervals: total_intervals,
         total_tasks: total_tasks,
         completed_tasks: 0,
         successful_tasks: 0,
         failed_tasks: 0,
         percentage: 0
       }}
    )

    # Process trading pairs in chunks of 4 (4 pairs * 5 intervals = 20 parallel tasks)
    symbols
    |> Enum.chunk_every(@max_concurrency)
    |> Enum.with_index(1)
    |> Enum.each(fn {pairs_chunk, chunk_index} ->
      send(
        progress_pid,
        {:sync_progress,
         %{
           status: :processing_chunk,
           chunk_index: chunk_index,
           total_chunks: ceil(total_pairs / 4),
           current_pairs: length(pairs_chunk)
         }}
      )

      # Create tasks for this chunk
      tasks =
        for trading_pair <- pairs_chunk,
            {interval, days} <- @intervals do
          Task.async(fn ->
            Logger.debug("Starting sync for #{trading_pair.symbol} with interval #{interval}")
            start_time = DateTime.utc_now()

            try do
              Logger.debug(
                "Calling sync_historical_data for #{trading_pair.symbol} with interval #{interval}"
              )

              {:ok, _} =
                SyncHistoricalDataForSymbolUseCase.sync_historical_data(
                  trading_pair.symbol,
                  interval,
                  DateTime.utc_now(),
                  DateTime.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)
                )

              end_time = DateTime.utc_now()
              duration = DateTime.diff(end_time, start_time, :second)

              Logger.debug(
                "Successfully synced #{trading_pair.symbol} with interval #{interval} in #{duration} seconds"
              )

              {:ok, {trading_pair.symbol, interval}}
            rescue
              e ->
                Logger.error(
                  "Failed to sync #{trading_pair.symbol} with interval #{interval}: #{inspect(e)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
                )

                {:error, {trading_pair.symbol, interval, e}}
            catch
              kind, e ->
                Logger.error(
                  "Caught #{kind} while syncing #{trading_pair.symbol} with interval #{interval}: #{inspect(e)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
                )

                {:error, {trading_pair.symbol, interval, {kind, e}}}
            end
          end)
        end

      # Wait for all tasks in this chunk to complete before moving to the next chunk
      results =
        tasks
        |> Enum.map(&Task.await(&1, :infinity))

      # Process results for this chunk
      successes =
        Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)

      failures =
        Enum.count(results, fn
          {:error, _} -> true
          _ -> false
        end)

      completed = successes + failures
      percentage = completed / total_tasks * 100

      send(
        progress_pid,
        {:sync_progress,
         %{
           status: :chunk_completed,
           chunk_index: chunk_index,
           total_chunks: ceil(total_pairs / 4),
           completed_tasks: completed,
           successful_tasks: successes,
           failed_tasks: failures,
           percentage: percentage
         }}
      )

      if failures > 0 do
        Logger.warning(
          "Some tasks in chunk #{chunk_index} failed. Check the logs above for details."
        )
      end
    end)

    send(
      progress_pid,
      {:sync_progress,
       %{
         status: :completed,
         total_tasks: total_tasks,
         successful_tasks: total_tasks,
         failed_tasks: 0,
         percentage: 100
       }}
    )

    Logger.debug("Completed syncing historical data for all trading pairs")
    :ok
  end
end
