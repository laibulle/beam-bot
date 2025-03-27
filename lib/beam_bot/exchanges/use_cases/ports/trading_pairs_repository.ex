defmodule BeamBot.Exchanges.UseCases.Ports.TradingPairsRepository do
  @moduledoc """
  This module is responsible for managing the trading pairs.
  """
  alias BeamBot.Exchanges.Domain.TradingPair

  @callback get_trading_pairs(String.t()) :: {:ok, list(TradingPair.t())} | {:error, String.t()}

  @callback list_trading_pairs() :: {:ok, list(TradingPair.t())} | {:error, String.t()}
end
