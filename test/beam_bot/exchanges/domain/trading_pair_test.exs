defmodule BeamBot.Exchanges.Domain.TradingPairTest do
  use ExUnit.Case
  alias BeamBot.Exchanges.Domain.TradingPair

  describe "JSON encoding" do
    test "encodes only specified fields" do
      trading_pair = %TradingPair{
        symbol: "BTC/USDT",
        base_asset: "BTC",
        quote_asset: "USDT",
        min_price: Decimal.new("1000"),
        max_price: Decimal.new("50000"),
        tick_size: Decimal.new("0.1"),
        min_qty: Decimal.new("0.001"),
        max_qty: Decimal.new("100"),
        step_size: Decimal.new("0.001"),
        min_notional: Decimal.new("10"),
        is_active: true
      }

      encoded = Jason.encode!(trading_pair)
      decoded = Jason.decode!(encoded)

      assert decoded == %{
               "symbol" => "BTC/USDT",
               "base_asset" => "BTC",
               "quote_asset" => "USDT",
               "is_active" => true
             }
    end
  end
end
