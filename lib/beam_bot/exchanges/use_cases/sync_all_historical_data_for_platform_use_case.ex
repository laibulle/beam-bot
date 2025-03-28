defmodule BeamBot.Exchanges.UseCases.SyncAllHistoricalDataForPlatformUseCase do
  @moduledoc """
  This module is responsible for syncing all historical data for a platform.
  """

  alias BeamBot.Exchanges.UseCases.SyncHistoricalDataForSymbolUseCase

  @trading_pairs_adapter Application.compile_env(:beam_bot, :trading_pairs_repository)

  @intervals %{"1h" => 30, "1d" => 365, "1w" => 365, "1m" => 3650}

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

    # Sync historical data for each symbol
    Enum.each(symbols, fn trading_pair ->
      Enum.each(@intervals, fn {interval, days} ->
        SyncHistoricalDataForSymbolUseCase.sync_historical_data(
          trading_pair.symbol,
          interval,
          DateTime.utc_now(),
          DateTime.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)
        )
      end)
    end)
  end
end
