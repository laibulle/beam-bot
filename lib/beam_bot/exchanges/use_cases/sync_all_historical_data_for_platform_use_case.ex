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

    send_initial_progress(progress_pid, total_tasks)

    initial_acc = %{
      completed_tasks: 0,
      successful_tasks: 0,
      failed_tasks: 0
    }

    final_acc =
      all_work_items
      |> Enum.chunk_every(@max_concurrency)
      |> Enum.reduce(initial_acc, fn work_chunk, acc ->
        {chunk_successes, chunk_failures} = process_work_chunk(work_chunk)

        new_completed = acc.completed_tasks + length(work_chunk)
        new_successes = acc.successful_tasks + chunk_successes
        new_failures = acc.failed_tasks + chunk_failures
        percentage = calculate_percentage(new_completed, total_tasks)

        send_progress_update(
          progress_pid,
          :in_progress,
          total_tasks,
          new_completed,
          new_successes,
          new_failures,
          percentage
        )

        %{
          completed_tasks: new_completed,
          successful_tasks: new_successes,
          failed_tasks: new_failures
        }
      end)

    send_completion_progress(progress_pid, total_tasks, final_acc)
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
    send_progress_update(progress_pid, :started, total_tasks, 0, 0, 0, 0)
  end

  defp send_completion_progress(progress_pid, total_tasks, final_acc) do
    send_progress_update(
      progress_pid,
      :completed,
      total_tasks,
      # Assuming completion means all were attempted
      total_tasks,
      final_acc.successful_tasks,
      final_acc.failed_tasks,
      100
    )
  end

  defp send_progress_update(
         progress_pid,
         status,
         total_tasks,
         completed_tasks,
         successful_tasks,
         failed_tasks,
         percentage
       ) do
    send(
      progress_pid,
      {:sync_progress,
       %{
         status: status,
         total_tasks: total_tasks,
         completed_tasks: completed_tasks,
         successful_tasks: successful_tasks,
         failed_tasks: failed_tasks,
         percentage: percentage
       }}
    )
  end

  defp process_work_chunk(work_chunk) do
    tasks = Enum.map(work_chunk, &create_sync_task/1)
    results = tasks |> Enum.map(&Task.await(&1, :infinity))

    {successes, failures} = count_results(results)

    if failures > 0 do
      # Log failures immediately within the chunk processing if needed
      failed_details =
        Enum.filter(results, fn
          {:error, _} -> true
          _ -> false
        end)
        |> Enum.map(fn {:error, {symbol, interval, reason}} ->
          "#{symbol} (#{interval}): #{inspect(reason)}"
        end)

      Logger.warning(
        "#{failures} task(s) failed in the current chunk: #{Enum.join(failed_details, ", ")}"
      )
    end

    {successes, failures}
  end

  defp calculate_percentage(completed, total) do
    if total == 0, do: 100, else: min(Float.round(completed / total * 100, 1), 100.0)
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
          # Capture stacktrace for catch
          stacktrace = System.stacktrace()

          Logger.error(
            "Caught #{kind} while syncing #{trading_pair.symbol} with interval #{interval}: #{inspect(e)}\n#{Exception.format_stacktrace(stacktrace)}"
          )

          # Include stacktrace in error tuple if helpful
          {:error, {trading_pair.symbol, interval, {kind, e, stacktrace}}}
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
