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
    all_work_items = create_work_items()
    total_tasks = length(all_work_items)
    total_chunks = ceil(total_tasks / @max_concurrency)

    send_initial_progress(progress_pid, total_tasks)

    all_work_items
    |> Enum.chunk_every(@max_concurrency)
    |> Enum.with_index(1)
    |> Enum.each(fn {work_chunk, chunk_index} ->
      process_work_chunk(work_chunk, chunk_index, total_chunks, total_tasks, progress_pid)
    end)

    send_completion_progress(progress_pid, total_tasks)
    Logger.debug("Completed syncing historical data for all trading pairs")
    :ok
  end

  defp create_work_items do
    @trading_pairs_adapter.list_trading_pairs()
    |> Enum.flat_map(fn trading_pair ->
      Enum.map(@intervals, fn {interval, days} ->
        {trading_pair, interval, days}
      end)
    end)
  end

  defp send_initial_progress(progress_pid, total_tasks) do
    send(
      progress_pid,
      {:sync_progress,
       %{
         status: :started,
         total_tasks: total_tasks,
         completed_tasks: 0,
         successful_tasks: 0,
         failed_tasks: 0,
         percentage: 0
       }}
    )
  end

  defp send_completion_progress(progress_pid, total_tasks) do
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
  end

  defp process_work_chunk(work_chunk, chunk_index, total_chunks, total_tasks, progress_pid) do
    send_chunk_start_progress(progress_pid, chunk_index, total_chunks, work_chunk)

    tasks = Enum.map(work_chunk, &create_sync_task/1)
    results = tasks |> Enum.map(&Task.await(&1, :infinity))

    {successes, failures} = count_results(results)
    completed_tasks = chunk_index * @max_concurrency
    percentage = min(completed_tasks / total_tasks * 100, 100)

    send_chunk_completion_progress(
      progress_pid,
      chunk_index,
      total_chunks,
      completed_tasks,
      successes,
      failures,
      percentage
    )

    if failures > 0 do
      Logger.warning(
        "Some tasks in chunk #{chunk_index} failed. Check the logs above for details."
      )
    end
  end

  defp send_chunk_start_progress(progress_pid, chunk_index, total_chunks, work_chunk) do
    send(
      progress_pid,
      {:sync_progress,
       %{
         status: :processing_chunk,
         chunk_index: chunk_index,
         total_chunks: total_chunks,
         current_tasks: length(work_chunk)
       }}
    )
  end

  defp send_chunk_completion_progress(
         progress_pid,
         chunk_index,
         total_chunks,
         completed_tasks,
         successes,
         failures,
         percentage
       ) do
    send(
      progress_pid,
      {:sync_progress,
       %{
         status: :chunk_completed,
         chunk_index: chunk_index,
         total_chunks: total_chunks,
         completed_tasks: completed_tasks,
         successful_tasks: successes,
         failed_tasks: failures,
         percentage: percentage
       }}
    )
  end

  defp create_sync_task({trading_pair, interval, days}) do
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

  defp count_results(results) do
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

    {successes, failures}
  end
end
