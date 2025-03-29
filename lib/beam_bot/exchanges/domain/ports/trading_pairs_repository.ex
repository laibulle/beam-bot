defmodule BeamBot.Exchanges.Domain.Ports.TradingPairsRepository do
  @moduledoc """
  This module is responsible for managing the trading pairs.
  """
  alias BeamBot.Exchanges.Domain.TradingPair

  @callback get_trading_pairs(String.t()) :: {:ok, list(TradingPair.t())} | {:error, String.t()}

  @callback list_trading_pairs() :: {:ok, list(TradingPair.t())} | {:error, String.t()}

  @callback upsert_trading_pairs(list(TradingPair.t())) ::
              {:ok, list(TradingPair.t())} | {:error, String.t()}

  @callback get_trading_pair_by_symbol(String.t()) ::
              {:ok, TradingPair.t()} | {:error, String.t()}
end
