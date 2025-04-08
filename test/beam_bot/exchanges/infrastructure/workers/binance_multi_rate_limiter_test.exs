defmodule BeamBot.Exchanges.Infrastructure.Workers.BinanceMultiRateLimiterTest do
  use ExUnit.Case, async: true
  alias BeamBot.Exchanges.Infrastructure.Workers.BinanceMultiRateLimiter

  describe "compute_klines_weight_from_limit/1" do
    test "returns the correct weight based on the limit" do
      # 1..100 -> 1
      assert BinanceMultiRateLimiter.compute_klines_weight_from_limit(1) == 1
      assert BinanceMultiRateLimiter.compute_klines_weight_from_limit(5) == 1
      assert BinanceMultiRateLimiter.compute_klines_weight_from_limit(100) == 1

      # 101..500 -> 2
      assert BinanceMultiRateLimiter.compute_klines_weight_from_limit(101) == 2
      assert BinanceMultiRateLimiter.compute_klines_weight_from_limit(500) == 2

      # 501..1000 -> 5
      assert BinanceMultiRateLimiter.compute_klines_weight_from_limit(501) == 5
      assert BinanceMultiRateLimiter.compute_klines_weight_from_limit(1000) == 5

      # 1001..5000 -> 10
      assert BinanceMultiRateLimiter.compute_klines_weight_from_limit(1001) == 10
      assert BinanceMultiRateLimiter.compute_klines_weight_from_limit(5000) == 10
    end
  end
end
