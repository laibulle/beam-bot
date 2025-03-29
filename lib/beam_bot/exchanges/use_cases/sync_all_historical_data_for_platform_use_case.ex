defmodule BeamBot.Exchanges.UseCases.SyncAllHistoricalDataForPlatformUseCase do
  @moduledoc """
  This module is responsible for syncing all historical data for a platform.
  """

  alias BeamBot.Exchanges.UseCases.SyncHistoricalDataForSymbolUseCase

  @symbols_adapter Application.compile_env(:beam_bot, :symbols_repository)
  @days 365

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
  def sync_all_historical_data_for_platform(platform) do
    # Get all symbols for the platform
    symbols = @symbols_adapter.get_all_symbols(platform)

    # Sync historical data for each symbol
    Enum.each(symbols, fn symbol ->
      SyncHistoricalDataForSymbolUseCase.sync_historical_data(
        symbol,
        "1h",
        DateTime.utc_now(),
        DateTime.add(DateTime.utc_now(), @days * 24 * 60 * 60, :second)
      )
    end)
  end
end
