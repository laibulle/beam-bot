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
  alias BeamBot.Strategies.Domain.{SmallInvestorStrategy, StrategyRunner}

  def find_best_trading_pairs_small_investor(%{
        investment_amount: investment_amount,
        timeframe: timeframe,
        rsi_oversold: rsi_oversold,
        rsi_overbought: rsi_overbought,
        days: days
      }) do
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
      rsi_overbought_threshold: overbought
    ]

    # Run simulations for each trading pair
    results =
      Enum.map(active_symbols, fn trading_pair ->
        # Create strategy for this trading pair
        strategy = SmallInvestorStrategy.new(trading_pair.symbol, decimal_amount, options)

        # Run simulation
        case StrategyRunner.run_simulation(strategy, start_date, end_date) do
          {:ok, simulation_results} ->
            Logger.info(
              "Simulation results for #{trading_pair.symbol}: #{inspect(simulation_results)}"
            )

            %{
              trading_pair: trading_pair.symbol,
              simulation_results: simulation_results
            }

          {:error, reason} ->
            %{
              trading_pair: trading_pair.symbol,
              error: reason
            }
        end
      end)

    # Filter out errors and sort by ROI
    profitable_pairs =
      results
      |> Enum.reject(&Map.has_key?(&1, :error))
      |> Enum.sort_by(
        fn %{simulation_results: results} ->
          Decimal.to_float(results.roi_percentage)
        end,
        :desc
      )

    {:ok, profitable_pairs}
  end
end
