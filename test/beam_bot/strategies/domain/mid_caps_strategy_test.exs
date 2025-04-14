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
    @tag :aaa
    test "generates sell signal when volume and volatility are bellow thresholds" do
      strategy = MidCapsStrategy.new("BTCUSDT", Decimal.new("500"), 1)
      variation = 0.0001

      klines =
        Enum.reduce(0..60, [], fn i, acc ->
          previous =
            List.last(acc) ||
              [
                # open_price
                0.0163479,
                # high_price
                0.5,
                # low_price
                0.015758,
                # close_price
                0.015771,
                # volume
                1_000_000.0,
                DateTime.utc_now() |> DateTime.to_unix(:millisecond),
                # quote_asset_volume
                74_950,
                # number_of_trades
                50,
                # taker_buy_base_asset_volume
                74_950.0,
                # taker_buy_quote_asset_volume
                10.0,
                DateTime.utc_now() |> DateTime.to_iso8601()
              ]

          acc ++
            [
              [
                # open_price based on previous close_price
                Enum.at(previous, 3),
                # high_price
                Enum.at(previous, 1) + variation,
                # low_price
                Enum.at(previous, 2) - variation,
                # close_price
                Enum.at(previous, 3) + variation,
                # volume
                Enum.at(previous, 4) - i * 100_000,
                DateTime.utc_now()
                |> DateTime.add(i * 60, :second)
                |> DateTime.to_unix(:millisecond),
                # quote_asset_volume
                Enum.at(previous, 6),
                # number_of_trades
                Enum.at(previous, 7) + 1,
                # taker_buy_base_asset_volume
                Enum.at(previous, 8) + 100,
                # taker_buy_quote_asset_volume
                Enum.at(previous, 9) - 0.1,
                DateTime.utc_now() |> DateTime.add(i * 60 - 60, :second) |> DateTime.to_iso8601()
              ]
            ]
        end)

      assert {:ok, result} = MidCapsStrategy.analyze_market_with_data(klines, strategy)
      assert result.signal == :sell
      assert result.price == 0.021870999999999963
      assert is_struct(result.max_risk_amount, Decimal)
    end

    test "generates buy signal when volume and volatility are above thresholds" do
      strategy = MidCapsStrategy.new("BTCUSDT", Decimal.new("500"), 1)
      variation = 0.0001

      klines =
        Enum.reduce(0..60, [], fn i, acc ->
          previous =
            List.last(acc) ||
              [
                # open_price
                0.0163479,
                # high_price
                0.5,
                # low_price
                0.015758,
                # close_price
                0.015771,
                # volume
                1_000_000.0,
                DateTime.utc_now() |> DateTime.to_unix(:millisecond),
                # quote_asset_volume
                74_950,
                # number_of_trades
                50,
                # taker_buy_base_asset_volume
                74_950.0,
                # taker_buy_quote_asset_volume
                10.0,
                DateTime.utc_now() |> DateTime.to_iso8601()
              ]

          acc ++
            [
              [
                # open_price based on previous close_price
                Enum.at(previous, 3),
                # high_price
                Enum.at(previous, 1) + variation,
                # low_price
                Enum.at(previous, 2) - variation,
                # close_price
                Enum.at(previous, 3) + variation,
                # volume
                Enum.at(previous, 4) + variation,
                DateTime.utc_now()
                |> DateTime.add(i * 60, :second)
                |> DateTime.to_unix(:millisecond),
                # quote_asset_volume
                Enum.at(previous, 6),
                # number_of_trades
                Enum.at(previous, 7) + 1,
                # taker_buy_base_asset_volume
                Enum.at(previous, 8) + 100,
                # taker_buy_quote_asset_volume
                Enum.at(previous, 9) - 0.1,
                DateTime.utc_now() |> DateTime.add(i * 60 - 60, :second) |> DateTime.to_iso8601()
              ]
            ]
        end)

      assert {:ok, result} = MidCapsStrategy.analyze_market_with_data(klines, strategy)
      assert result.signal == :buy
      assert result.price == 0.021870999999999963
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
