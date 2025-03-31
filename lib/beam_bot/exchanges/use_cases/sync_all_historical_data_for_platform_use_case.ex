defmodule BeamBot.Exchanges.UseCases.SyncAllHistoricalDataForPlatformUseCase do
  @moduledoc """
  This module is responsible for syncing all historical data for a platform.
  """

  alias BeamBot.Exchanges.UseCases.SyncHistoricalDataForSymbolUseCase
  require Logger

  @trading_pairs_adapter Application.compile_env(:beam_bot, :trading_pairs_repository)

  @intervals %{"1m" => 1, "1h" => 30, "1d" => 365, "1w" => 365, "1M" => 3650}

  @doc """
  Syncs all historical data for a platform.

  ## Parameters
    - platform: The platform to sync historical data for

  ## Returns
    - :ok

  ## Example
      iex> BeamBot.Exchanges.UseCases.SyncAllHistoricalDataForPlatformUseCase.sync_all_historical_data_for_platform("binance")
      :ok
  """
  def sync_all_historical_data_for_platform(_platform) do
    # Get all symbols for the platform
    symbols = @trading_pairs_adapter.list_trading_pairs()
    total_pairs = length(symbols)
    total_intervals = map_size(@intervals)
    total_tasks = total_pairs * total_intervals

    Logger.info("""
    Starting to sync historical data:
    - Total pairs: #{total_pairs}
    - Total intervals: #{total_intervals}
    - Total tasks: #{total_tasks}
    """)

    # Create a process to track progress
    progress_pid = spawn(fn -> progress_tracker(total_tasks) end)

    # Process trading pairs in chunks of 4 (4 pairs * 5 intervals = 20 parallel tasks)
    symbols
    |> Enum.chunk_every(4)
    |> Enum.with_index(1)
    |> Enum.each(fn {pairs_chunk, chunk_index} ->
      Logger.info(
        "Processing chunk #{chunk_index}/#{ceil(total_pairs / 20)} (#{length(pairs_chunk)} pairs)"
      )

      # Create tasks for this chunk
      tasks =
        for trading_pair <- pairs_chunk,
            {interval, days} <- @intervals do
          Task.async(fn ->
            Logger.info("Starting sync for #{trading_pair.symbol} with interval #{interval}")
            start_time = DateTime.utc_now()

            try do
              Logger.debug(
                "Calling sync_historical_data for #{trading_pair.symbol} with interval #{interval}"
              )

              result =
                SyncHistoricalDataForSymbolUseCase.sync_historical_data(
                  trading_pair.symbol,
                  interval,
                  DateTime.utc_now(),
                  DateTime.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)
                )

              end_time = DateTime.utc_now()
              duration = DateTime.diff(end_time, start_time, :second)

              Logger.info(
                "Successfully synced #{trading_pair.symbol} with interval #{interval} in #{duration} seconds"
              )

              # Send progress update
              send(progress_pid, {:task_completed, {:ok, {trading_pair.symbol, interval}}})
              {:ok, {trading_pair.symbol, interval}}
            rescue
              e ->
                Logger.error(
                  "Failed to sync #{trading_pair.symbol} with interval #{interval}: #{inspect(e)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
                )

                # Send progress update
                send(
                  progress_pid,
                  {:task_completed, {:error, {trading_pair.symbol, interval, e}}}
                )

                {:error, {trading_pair.symbol, interval, e}}
            catch
              kind, e ->
                Logger.error(
                  "Caught #{kind} while syncing #{trading_pair.symbol} with interval #{interval}: #{inspect(e)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
                )

                # Send progress update
                send(
                  progress_pid,
                  {:task_completed, {:error, {trading_pair.symbol, interval, {kind, e}}}}
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

      Logger.info("""
      Completed chunk #{chunk_index}/#{ceil(total_pairs / 20)}:
      - Total tasks: #{length(results)}
      - Successful: #{successes}
      - Failed: #{failures}
      """)

      if failures > 0 do
        Logger.warning(
          "Some tasks in chunk #{chunk_index} failed. Check the logs above for details."
        )
      end
    end)

    # Wait for progress tracker to finish
    send(progress_pid, :done)
    Process.wait(progress_pid)

    Logger.info("Completed syncing historical data for all trading pairs")
    :ok
  end

  defp progress_tracker(total_tasks) do
    progress_tracker(total_tasks, 0, 0, 0)
  end

  defp progress_tracker(total_tasks, completed, successes, failures) do
    receive do
      {:task_completed, {:ok, _}} ->
        new_completed = completed + 1
        new_successes = successes + 1
        percentage = new_completed / total_tasks * 100
        print_progress(percentage, new_completed, total_tasks, new_successes, failures)
        progress_tracker(total_tasks, new_completed, new_successes, failures)

      {:task_completed, {:error, _}} ->
        new_completed = completed + 1
        new_failures = failures + 1
        percentage = new_completed / total_tasks * 100
        print_progress(percentage, new_completed, total_tasks, successes, new_failures)
        progress_tracker(total_tasks, new_completed, successes, new_failures)

      :done ->
        Logger.info("""
        Final Progress:
        - Total tasks: #{total_tasks}
        - Completed: #{completed}
        - Successful: #{successes}
        - Failed: #{failures}
        - Progress: 100%
        """)
    end
  end

  defp print_progress(percentage, completed, total, successes, failures) do
    Logger.info("""
    Progress: #{Float.round(percentage, 2)}% (#{completed}/#{total} tasks)
    - Successful: #{successes}
    - Failed: #{failures}
    """)
  end
end
