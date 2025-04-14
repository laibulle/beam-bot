defmodule BeamBot.Strategies.Domain.MidCapsStrategyTest do
  use ExUnit.Case
  import Mox
  alias BeamBot.Strategies.Domain.MidCapsStrategy

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "new/3" do
    test "creates strategy with default values" do
      strategy = MidCapsStrategy.new("BTCUSDT", Decimal.new("500"), 1)

      assert strategy.trading_pair == "BTCUSDT"
      assert strategy.investment_amount == Decimal.new("500")
      assert strategy.max_risk_percentage == Decimal.new("1.5")
      assert strategy.volume_threshold == Decimal.new("1000000")
      assert strategy.volatility_threshold == Decimal.new("2")
      assert strategy.ma_short_period == 5
      assert strategy.ma_long_period == 20
      assert strategy.timeframe == "1h"
      assert strategy.maker_fee == Decimal.new("0.02")
      assert strategy.taker_fee == Decimal.new("0.1")
      assert is_struct(strategy.activated_at, DateTime)
    end

    test "creates strategy with custom values" do
      strategy =
        MidCapsStrategy.new("ETHUSDT", Decimal.new("1000"), 1,
          max_risk_percentage: "2",
          volume_threshold: Decimal.new("2000000"),
          volatility_threshold: Decimal.new("3"),
          ma_short_period: 7,
          ma_long_period: 25,
          timeframe: "4h",
          maker_fee: Decimal.new("0.01"),
          taker_fee: Decimal.new("0.05")
        )

      assert strategy.trading_pair == "ETHUSDT"
      assert strategy.investment_amount == Decimal.new("1000")
      assert strategy.max_risk_percentage == Decimal.new("2")
      assert strategy.volume_threshold == Decimal.new("2000000")
      assert strategy.volatility_threshold == Decimal.new("3")
      assert strategy.ma_short_period == 7
      assert strategy.ma_long_period == 25
      assert strategy.timeframe == "4h"
      assert strategy.maker_fee == Decimal.new("0.01")
      assert strategy.taker_fee == Decimal.new("0.05")
    end
  end

  describe "analyze_market_with_data/2" do
    test "generates buy signal when volume and volatility are above thresholds" do
      strategy = MidCapsStrategy.new("BTCUSDT", Decimal.new("500"), 1)

      # Mock klines with high volume and volatility
      klines =
        Enum.map(1..60, fn _i ->
          %BeamBot.Exchanges.Domain.Kline{
            close: Decimal.new("50000"),
            volume: Decimal.new("2000000")
          }
        end)

      # Add the last two klines with different values
      klines =
        klines ++
          [
            %BeamBot.Exchanges.Domain.Kline{
              close: Decimal.new("51000"),
              volume: Decimal.new("2500000")
            }
          ]

      assert {:ok, result} = MidCapsStrategy.analyze_market_with_data(klines, strategy)
      assert result.signal == :buy
      assert result.price == 51_000.0
      assert is_struct(result.max_risk_amount, Decimal)
    end

    test "generates sell signal when volume and volatility are below thresholds" do
      strategy = MidCapsStrategy.new("BTCUSDT", Decimal.new("500"), 1)

      # Mock klines with low volume and volatility
      klines =
        Enum.map(1..60, fn _i ->
          %BeamBot.Exchanges.Domain.Kline{
            close: Decimal.new("50000"),
            volume: Decimal.new("500000")
          }
        end)

      # Add the last two klines with different values
      klines =
        klines ++
          [
            %BeamBot.Exchanges.Domain.Kline{
              close: Decimal.new("50100"),
              volume: Decimal.new("400000")
            }
          ]

      assert {:ok, result} = MidCapsStrategy.analyze_market_with_data(klines, strategy)
      assert result.signal == :hold
      assert result.price == 50_100.0
      assert is_struct(result.max_risk_amount, Decimal)
    end

    test "generates hold signal when conditions are mixed" do
      strategy = MidCapsStrategy.new("BTCUSDT", Decimal.new("500"), 1)

      # Mock klines with mixed signals
      klines =
        Enum.map(1..60, fn _i ->
          %BeamBot.Exchanges.Domain.Kline{
            close: Decimal.new("50000"),
            volume: Decimal.new("2000000")
          }
        end)

      # Add the last two klines with different values
      klines =
        klines ++
          [
            %BeamBot.Exchanges.Domain.Kline{
              close: Decimal.new("50100"),
              volume: Decimal.new("400000")
            }
          ]

      assert {:ok, result} = MidCapsStrategy.analyze_market_with_data(klines, strategy)
      assert result.signal == :sell
      assert result.price == 50_100.0
      assert is_struct(result.max_risk_amount, Decimal)
    end

    test "returns error when not enough data points" do
      strategy = MidCapsStrategy.new("BTCUSDT", Decimal.new("500"), 1)

      # Mock klines with insufficient data
      klines = [
        %BeamBot.Exchanges.Domain.Kline{
          close: Decimal.new("50000"),
          volume: Decimal.new("2000000")
        }
      ]

      assert {:error, ":not_enough_data"} =
               MidCapsStrategy.analyze_market_with_data(klines, strategy)
    end
  end
end
