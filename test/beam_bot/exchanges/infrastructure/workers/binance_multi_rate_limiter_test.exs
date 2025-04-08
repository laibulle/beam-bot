defmodule BeamBot.Exchanges.Infrastructure.Workers.BinanceMultiRateLimiterTest do
  use ExUnit.Case, async: true
  alias BeamBot.Exchanges.Infrastructure.Workers.BinanceMultiRateLimiter

  describe "compute_weight/1" do
    test "returns the correct weight based on the limit" do
      # 1..100 -> 1
      assert BinanceMultiRateLimiter.compute_weight(1) == 1
      assert BinanceMultiRateLimiter.compute_weight(5) == 1
      assert BinanceMultiRateLimiter.compute_weight(100) == 1

      # 101..500 -> 5
      assert BinanceMultiRateLimiter.compute_weight(101) == 5
      assert BinanceMultiRateLimiter.compute_weight(500) == 5

      # 501..1000 -> 10
      assert BinanceMultiRateLimiter.compute_weight(501) == 10
      assert BinanceMultiRateLimiter.compute_weight(1000) == 10

      # 1001..5000 -> 50
      assert BinanceMultiRateLimiter.compute_weight(1001) == 50
      assert BinanceMultiRateLimiter.compute_weight(5000) == 50
    end
  end
end
