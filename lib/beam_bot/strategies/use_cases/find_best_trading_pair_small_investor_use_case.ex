defmodule BeamBot.Strategies.UseCases.FindBestTradingPairSmallInvestorUseCase do
  @moduledoc """
  Find the best trading pair for a small investor using simulation over all active trading pairs
  return a list of trading pairs with the best performance


  ## Examples
      iex> params = %{
        investment_amount: "500",
        timeframe: "1h",
        rsi_oversold: "30",
        rsi_overbought: "70",
        days: "30"
      }
      iex> BeamBot.Strategies.UseCases.FindBestTradingPairSmallInvestorUseCase.find_best_trading_pairs_small_investor(params)
  """

  require Logger

  @trading_pairs_adapter Application.compile_env(:beam_bot, :trading_pairs_repository)

  @max_concurrency Application.compile_env(
                     :beam_bot,
                     :max_best_trading_pairs_small_investor_concurrency
                   )

  alias BeamBot.Strategies.Domain.SmallInvestorStrategy
  alias BeamBot.Strategies.Infrastructure.Workers.SmallInvestorStrategyRunner

  def find_best_trading_pairs_small_investor(
        %{
          investment_amount: investment_amount,
          timeframe: timeframe,
          rsi_oversold: rsi_oversold,
          rsi_overbought: rsi_overbought,
          days: days,
          user_id: user_id
        } = _params
      ) do
    # Get all active trading pairs
    active_symbols = @trading_pairs_adapter.list_trading_pairs() |> Enum.filter(& &1.is_active)

    # Convert params to appropriate types
    decimal_amount = Decimal.new(investment_amount)
    days_ago = String.to_integer(days)
    oversold = String.to_integer(rsi_oversold)
    overbought = String.to_integer(rsi_overbought)

    # Calculate start and end dates
    end_date = DateTime.utc_now()
    start_date = DateTime.add(end_date, -days_ago * 24 * 60 * 60, :second)

    # Create options
    options = [
      timeframe: timeframe,
      rsi_oversold_threshold: oversold,
      rsi_overbought_threshold: overbought,
      user_id: user_id
    ]

    # Process trading pairs in batches to reduce memory usage
    batch_size = 20
    total_pairs = length(active_symbols)
    processed_count = 0
    profitable_pairs = []

    # Create a context map to pass to the batch processing function
    context = %{
      decimal_amount: decimal_amount,
      options: options,
      start_date: start_date,
      end_date: end_date,
      total_pairs: total_pairs,
      user_id: user_id
    }

    # Process in batches
    {final_profitable_pairs, _} =
      active_symbols
      |> Enum.chunk_every(batch_size)
      |> Enum.reduce({profitable_pairs, processed_count}, fn batch,
                                                             {acc_profitable_pairs,
                                                              acc_processed_count} ->
        process_batch(
          batch,
          acc_profitable_pairs,
          acc_processed_count,
          context
        )
      end)

    {:ok, final_profitable_pairs}
  end

  # Helper function to process a batch of trading pairs
  defp process_batch(
         batch,
         acc_profitable_pairs,
         acc_processed_count,
         %{
           decimal_amount: decimal_amount,
           options: options,
           start_date: start_date,
           end_date: end_date,
           total_pairs: total_pairs,
           user_id: user_id
         } = _context
       ) do
    # Run simulations concurrently for this batch of trading pairs
    batch_results =
      batch
      |> Task.async_stream(
        fn trading_pair ->
          simulate_trading_pair(
            trading_pair,
            decimal_amount,
            options,
            start_date,
            end_date,
            user_id
          )
        end,
        # Reduced concurrency to prevent overwhelming the system
        max_concurrency: min(50, length(batch)),
        # 30 second timeout per task
        timeout: 30_000,
        ordered: false
      )
      |> Enum.map(fn
        {:ok, result} ->
          result

        {:exit, reason} ->
          Logger.error("Task exited with reason: #{inspect(reason)}")
          %{error: "Task execution failed", reason: reason}

        {:error, reason} ->
          Logger.error("Task error: #{inspect(reason)}")
          %{error: "Task execution failed", reason: reason}
      end)

    # Filter out errors and sort by ROI
    batch_profitable_pairs =
      batch_results
      |> Enum.reject(&Map.has_key?(&1, :error))
      |> Enum.sort_by(
        fn %{simulation_results: results} ->
          results.roi_percentage
        end,
        fn a, b -> Decimal.compare(a, b) == :gt end
      )

    # Merge with previous results and keep only top 100
    merged_profitable_pairs =
      (acc_profitable_pairs ++ batch_profitable_pairs)
      |> Enum.sort_by(
        fn %{simulation_results: results} ->
          results.roi_percentage
        end,
        fn a, b -> Decimal.compare(a, b) == :gt end
      )
      |> Enum.take(100)

    # Update processed count
    new_processed_count = acc_processed_count + length(batch)
    Logger.debug("Processed #{new_processed_count}/#{total_pairs} trading pairs")

    # Hint garbage collection after each batch
    :erlang.garbage_collect()

    {merged_profitable_pairs, new_processed_count}
  end

  # Helper function to simulate a single trading pair
  defp simulate_trading_pair(trading_pair, decimal_amount, options, start_date, end_date, user_id) do
    # Create strategy for this trading pair
    strategy = SmallInvestorStrategy.new(trading_pair.symbol, decimal_amount, user_id, options)

    # Run simulation directly without starting a GenServer
    case SmallInvestorStrategyRunner.run_simulation(strategy, start_date, end_date) do
      {:ok, simulation_results} ->
        Logger.debug(
          "Simulation results for #{trading_pair.symbol}: #{inspect(simulation_results)}"
        )

        %{
          trading_pair: trading_pair.symbol,
          simulation_results: simulation_results
        }

      {:error, reason} ->
        Logger.error("Error simulating #{trading_pair.symbol}: #{inspect(reason)}")

        %{
          trading_pair: trading_pair.symbol,
          error: reason
        }
    end
  end

  def find_best_trading_pairs_small_investor_stream(params, callback) do
    Logger.debug("Starting streaming analysis with params: #{inspect(params)}")

    # Get all active trading pairs
    active_symbols = @trading_pairs_adapter.list_trading_pairs() |> Enum.filter(& &1.is_active)
    Logger.debug("Found #{length(active_symbols)} active trading pairs")

    # Convert params to appropriate types
    decimal_amount = Decimal.new(params.investment_amount)
    days_ago = String.to_integer(params.days)
    oversold = String.to_integer(params.rsi_oversold)
    overbought = String.to_integer(params.rsi_overbought)

    # Calculate start and end dates
    end_date = DateTime.utc_now()
    start_date = DateTime.add(end_date, -days_ago * 24 * 60 * 60, :second)

    # Create options
    options = [
      timeframe: params.timeframe,
      rsi_oversold_threshold: oversold,
      rsi_overbought_threshold: overbought,
      user_id: params.user_id
    ]

    # Process trading pairs in batches to reduce memory usage
    batch_size = 20
    total_pairs = length(active_symbols)
    processed_count = 0
    profitable_pairs = []

    # Create a context map to pass to the batch processing function
    context = %{
      decimal_amount: decimal_amount,
      options: options,
      start_date: start_date,
      end_date: end_date,
      total_pairs: total_pairs,
      callback: callback
    }

    # Process in batches
    {final_profitable_pairs, _} =
      active_symbols
      |> Enum.chunk_every(batch_size)
      |> Enum.reduce({profitable_pairs, processed_count}, fn batch,
                                                             {acc_profitable_pairs,
                                                              acc_processed_count} ->
        process_batch_stream(
          batch,
          acc_profitable_pairs,
          acc_processed_count,
          context
        )
      end)

    Logger.debug(
      "Streaming analysis completed with #{length(final_profitable_pairs)} profitable pairs"
    )

    {:ok, final_profitable_pairs}
  end

  # Helper function to process a batch of trading pairs with streaming
  defp process_batch_stream(
         batch,
         acc_profitable_pairs,
         acc_processed_count,
         %{
           decimal_amount: decimal_amount,
           options: options,
           start_date: start_date,
           end_date: end_date,
           total_pairs: total_pairs,
           callback: callback
         } = _context
       ) do
    # Run simulations concurrently for this batch of trading pairs
    batch_results =
      batch
      |> Task.async_stream(
        fn trading_pair ->
          simulate_trading_pair_stream(
            trading_pair,
            decimal_amount,
            options,
            start_date,
            end_date,
            # Don't call the callback for each individual result
            fn _result -> :ok end
          )
        end,
        max_concurrency: min(@max_concurrency, length(batch)),
        timeout: 30_000,
        ordered: false
      )
      |> Enum.map(fn
        {:ok, result} ->
          result

        {:exit, reason} ->
          Logger.error("Task exited with reason: #{inspect(reason)}")
          %{error: "Task execution failed", reason: reason}

        {:error, reason} ->
          Logger.error("Task error: #{inspect(reason)}")
          %{error: "Task execution failed", reason: reason}
      end)

    # Filter out errors and sort by ROI
    batch_profitable_pairs =
      batch_results
      |> Enum.reject(&Map.has_key?(&1, :error))
      |> Enum.sort_by(
        fn %{simulation_results: results} ->
          results.roi_percentage
        end,
        fn a, b -> Decimal.compare(a, b) == :gt end
      )

    # Merge with previous results and keep only top 100
    merged_profitable_pairs =
      (acc_profitable_pairs ++ batch_profitable_pairs)
      |> Enum.sort_by(
        fn %{simulation_results: results} ->
          results.roi_percentage
        end,
        fn a, b -> Decimal.compare(a, b) == :gt end
      )
      |> Enum.take(100)

    # Update processed count
    new_processed_count = acc_processed_count + length(batch)

    # Calculate progress percentage
    progress = round(new_processed_count / total_pairs * 100)

    # Send batch update via callback
    if new_processed_count >= total_pairs do
      # Final batch - send results with 100% progress
      callback.({merged_profitable_pairs, 100})
    else
      # Intermediate batch - send results with current progress
      callback.({merged_profitable_pairs, progress})
    end

    # Hint garbage collection after each batch
    :erlang.garbage_collect()

    {merged_profitable_pairs, new_processed_count}
  end

  # Helper function to simulate a single trading pair with streaming
  defp simulate_trading_pair_stream(
         trading_pair,
         decimal_amount,
         options,
         start_date,
         end_date,
         callback
       ) do
    # Extract user_id from options
    user_id = Keyword.get(options, :user_id)
    strategy_options = Keyword.drop(options, [:user_id])

    # Create strategy for this trading pair
    strategy =
      SmallInvestorStrategy.new(trading_pair.symbol, decimal_amount, user_id, strategy_options)

    # Run simulation directly without starting a GenServer
    case SmallInvestorStrategyRunner.run_simulation(strategy, start_date, end_date) do
      {:ok, simulation_results} ->
        Logger.debug(
          "Simulation results for #{trading_pair.symbol}: #{inspect(simulation_results)}"
        )

        result = %{
          trading_pair: trading_pair.symbol,
          simulation_results: simulation_results
        }

        # Call the callback with the result
        callback.(result)
        result

      {:error, reason} ->
        Logger.error("Error simulating #{trading_pair.symbol}: #{inspect(reason)}")

        error_result = %{
          trading_pair: trading_pair.symbol,
          error: reason
        }

        # Call the callback with the error
        callback.(error_result)
        error_result
    end
  end
end
