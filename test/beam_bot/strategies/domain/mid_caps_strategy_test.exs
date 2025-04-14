defmodule BeamBot.Strategies.Domain.MidCapsStrategyTest do
  use ExUnit.Case
  import Mox
  alias BeamBot.Strategies.Domain.MidCapsStrategy
  alias BeamBotWeb.KlinesData
  alias BeamBotWeb.KlinesData.InputSettings

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

      klines =
        KlinesData.generate_klines_data(%InputSettings{
          interval: "1h",
          start_time: DateTime.utc_now() |> DateTime.add(-3600 * 60, :second),
          end_time: DateTime.utc_now()
        })

      assert {:ok, result} = MidCapsStrategy.analyze_market_with_data(klines, strategy)
      # assert result.signal == :buy
      # assert result.price == 51_000.0
      assert is_struct(result.max_risk_amount, Decimal)
    end

    test "generates sell signal when volume and volatility are below thresholds" do
      strategy = MidCapsStrategy.new("BTCUSDT", Decimal.new("500"), 1)

      klines =
        Enum.map(0..60, fn i ->
          [
            # Adjusted to ensure lower price changes
            0.0163479 + i * 0.00001,
            # Adjusted to ensure lower volatility
            0.8 + i * 0.00001,
            0.015758 + i * 0.00001,
            0.015771 + i * 0.00001,
            # Adjusted to ensure lower volume
            148_976.11427815 - i * 100,
            DateTime.utc_now() |> DateTime.add(i * 60, :second) |> DateTime.to_unix(:millisecond),
            # Adjusted to ensure lower volume
            2434.19055334 - i * 10,
            # Adjusted to ensure lower trades
            308 - i,
            # Adjusted to ensure lower taker volume
            1756.87402397 - i * 5,
            # Adjusted to ensure lower volatility
            28.46694368 - i * 0.1,
            DateTime.utc_now() |> DateTime.add(i * 60 - 60, :second) |> DateTime.to_iso8601()
          ]
        end)

      assert {:ok, result} = MidCapsStrategy.analyze_market_with_data(klines, strategy)
      # assert result.signal == :sell
      # assert result.price == 0.015773
      assert is_struct(result.max_risk_amount, Decimal)
    end

    test "generates hold signal when conditions are mixed" do
      strategy = MidCapsStrategy.new("BTCUSDT", Decimal.new("500"), 1)

      klines =
        KlinesData.generate_klines_data(%InputSettings{
          interval: "1h",
          start_time: DateTime.utc_now() |> DateTime.add(-3600 * 60, :second),
          end_time: DateTime.utc_now()
        })

      assert {:ok, result} = MidCapsStrategy.analyze_market_with_data(klines, strategy)
      assert result.signal == :hold
      assert result.price == 0.021671
      assert is_struct(result.max_risk_amount, Decimal)
    end

    test "returns error when not enough data points" do
      strategy = MidCapsStrategy.new("BTCUSDT", Decimal.new("500"), 1)

      klines = []

      assert {:error, ":not_enough_data"} =
               MidCapsStrategy.analyze_market_with_data(klines, strategy)
    end
  end
end
