defmodule BeamBot.Strategies.Domain.IndicatorsTest do
  use ExUnit.Case
  alias BeamBot.Strategies.Domain.Indicators

  describe "sma/2" do
    test "calculates simple moving average correctly" do
      prices = [1, 2, 3, 4, 5]
      assert Indicators.sma(prices, 3) == 4.0
      assert Indicators.sma(prices, 2) == 4.5
      assert Indicators.sma(prices, 5) == 3.0
    end

    test "returns nil when not enough data points" do
      prices = [1, 2, 3]
      assert Indicators.sma(prices, 4) == nil
      assert Indicators.sma(prices, 5) == nil
    end
  end

  describe "ema/2" do
    test "calculates exponential moving average correctly" do
      prices = [1, 2, 3, 4, 5]
      # For period 3, k = 2/(3+1) = 0.5
      # First EMA = SMA of first 3 values = 2
      # Then: EMA = price * k + previous_ema * (1-k)
      # 3 * 0.5 + 2 * 0.5 = 2.5
      # 4 * 0.5 + 2.5 * 0.5 = 3.25
      # 5 * 0.5 + 3.25 * 0.5 = 4.125
      assert_in_delta Indicators.ema(prices, 3), 2.5, 0.001
    end

    test "returns nil when not enough data points" do
      prices = [1, 2, 3]
      assert Indicators.ema(prices, 4) == nil
      assert Indicators.ema(prices, 5) == nil
    end
  end

  describe "rsi/2" do
    test "calculates RSI correctly for typical case" do
      # Using a sequence that should give us a known RSI value
      # With alternating gains and losses of equal magnitude
      prices = [100, 101, 100, 101, 100, 101, 100, 101, 100, 101, 100, 101, 100, 101, 100]
      assert_in_delta Indicators.rsi(prices, 14), 50.0, 0.1
    end

    test "returns 50 when all price changes are zero" do
      prices = [10, 10, 10, 10, 10]
      assert Indicators.rsi(prices, 3) == 50.0
    end

    test "returns nil when not enough data points" do
      prices = [1, 2, 3]
      assert Indicators.rsi(prices, 4) == nil
    end

    test "returns RSI less than 30 for a downward trend" do
      # Using a sequence that should give us an RSI value less than 30
      prices = [100, 95, 90, 85, 80, 75, 70, 65, 60, 55, 50, 45, 40, 35, 30]
      assert Indicators.rsi(prices, 14) < 30.0
    end
  end

  describe "macd/4" do
    test "calculates MACD correctly" do
      # We need at least 47 data points for MACD with default periods (12, 26, 9)
      prices = Enum.map(1..50, &(&1 * 1.0))
      result = Indicators.macd(prices, 12, 26, 9)

      assert is_map(result)
      assert Map.has_key?(result, :macd_line)
      assert Map.has_key?(result, :signal_line)
      assert Map.has_key?(result, :histogram)
    end

    test "returns nil when not enough data points" do
      prices = [1, 2, 3]
      assert Indicators.macd(prices, 12, 26, 9) == nil
    end
  end

  describe "bollinger_bands/3" do
    test "calculates Bollinger Bands correctly" do
      prices = [10, 11, 12, 11, 12, 13, 14, 15, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4]
      result = Indicators.bollinger_bands(prices, 20, 2)

      assert is_map(result)
      assert Map.has_key?(result, :upper_band)
      assert Map.has_key?(result, :middle_band)
      assert Map.has_key?(result, :lower_band)
      assert result.upper_band > result.middle_band
      assert result.middle_band > result.lower_band
    end

    test "returns nil when not enough data points" do
      prices = [1, 2, 3]
      assert Indicators.bollinger_bands(prices, 20, 2) == nil
    end
  end
end
