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

    Logger.info(
      "Starting to sync historical data for #{total_pairs} trading pairs with #{total_intervals} intervals each"
    )

    # Sync historical data for each symbol
    Enum.with_index(symbols, 1)
    |> Enum.each(fn {trading_pair, index} ->
      Logger.info("Processing trading pair #{index}/#{total_pairs}: #{trading_pair.symbol}")

      Enum.with_index(@intervals, 1)
      |> Enum.each(fn {{interval, days}, interval_index} ->
        Logger.info(
          "Syncing interval #{interval_index}/#{total_intervals}: #{interval} for #{trading_pair.symbol}"
        )

        SyncHistoricalDataForSymbolUseCase.sync_historical_data(
          trading_pair.symbol,
          interval,
          DateTime.utc_now(),
          DateTime.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)
        )
      end)
    end)

    Logger.info("Completed syncing historical data for all trading pairs")
  end
end
