defmodule BeamBot.Exchanges.Domain.KlineTest do
  use ExUnit.Case
  alias BeamBot.Exchanges.Domain.Kline

  describe "tuple_to_kline/1" do
    test "converts a kline tuple to a Kline struct" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      kline_tuple = {
        "BTCUSDT",
        "binance",
        "1h",
        now,
        Decimal.new("50000.0"),
        Decimal.new("51000.0"),
        Decimal.new("49000.0"),
        Decimal.new("50500.0"),
        Decimal.new("100.0"),
        Decimal.new("5000000.0"),
        1000,
        Decimal.new("50.0"),
        Decimal.new("2500000.0"),
        Decimal.new("0")
      }

      kline = Kline.tuple_to_kline(kline_tuple)

      assert kline.symbol == "BTCUSDT"
      assert kline.platform == "binance"
      assert kline.interval == "1h"
      assert DateTime.compare(kline.timestamp, now) == :eq
      assert Decimal.equal?(kline.open, Decimal.new("50000.0"))
      assert Decimal.equal?(kline.high, Decimal.new("51000.0"))
      assert Decimal.equal?(kline.low, Decimal.new("49000.0"))
      assert Decimal.equal?(kline.close, Decimal.new("50500.0"))
      assert Decimal.equal?(kline.volume, Decimal.new("100.0"))
      assert Decimal.equal?(kline.quote_volume, Decimal.new("5000000.0"))
      assert kline.trades_count == 1000
      assert Decimal.equal?(kline.taker_buy_base_volume, Decimal.new("50.0"))
      assert Decimal.equal?(kline.taker_buy_quote_volume, Decimal.new("2500000.0"))
      assert Decimal.equal?(kline.ignore, Decimal.new("0"))
    end

    test "handles nil values in optional fields" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      kline_tuple = {
        "BTCUSDT",
        "binance",
        "1h",
        now,
        Decimal.new("50000.0"),
        Decimal.new("51000.0"),
        Decimal.new("49000.0"),
        Decimal.new("50500.0"),
        Decimal.new("100.0"),
        nil,
        nil,
        nil,
        nil,
        nil
      }

      kline = Kline.tuple_to_kline(kline_tuple)

      assert kline.symbol == "BTCUSDT"
      assert kline.platform == "binance"
      assert kline.interval == "1h"
      assert DateTime.compare(kline.timestamp, now) == :eq
      assert Decimal.equal?(kline.open, Decimal.new("50000.0"))
      assert Decimal.equal?(kline.high, Decimal.new("51000.0"))
      assert Decimal.equal?(kline.low, Decimal.new("49000.0"))
      assert Decimal.equal?(kline.close, Decimal.new("50500.0"))
      assert Decimal.equal?(kline.volume, Decimal.new("100.0"))
      assert kline.quote_volume == nil
      assert kline.trades_count == nil
      assert kline.taker_buy_base_volume == nil
      assert kline.taker_buy_quote_volume == nil
      assert kline.ignore == nil
    end
  end

  describe "kline_to_tuple/1" do
    test "converts a Kline struct to a tuple" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      kline = %Kline{
        symbol: "BTCUSDT",
        platform: "binance",
        interval: "1h",
        timestamp: now,
        open: Decimal.new("50000.0"),
        high: Decimal.new("51000.0"),
        low: Decimal.new("49000.0"),
        close: Decimal.new("50500.0"),
        volume: Decimal.new("100.0"),
        quote_volume: Decimal.new("5000000.0"),
        trades_count: 1000,
        taker_buy_base_volume: Decimal.new("50.0"),
        taker_buy_quote_volume: Decimal.new("2500000.0"),
        ignore: Decimal.new("0")
      }

      tuple = Kline.kline_to_tuple(kline)

      assert tuple == {
               "BTCUSDT",
               "binance",
               "1h",
               now,
               Decimal.new("50000.0"),
               Decimal.new("51000.0"),
               Decimal.new("49000.0"),
               Decimal.new("50500.0"),
               Decimal.new("100.0"),
               Decimal.new("5000000.0"),
               1000,
               Decimal.new("50.0"),
               Decimal.new("2500000.0"),
               Decimal.new("0")
             }
    end

    test "handles nil values in optional fields" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      kline = %Kline{
        symbol: "BTCUSDT",
        platform: "binance",
        interval: "1h",
        timestamp: now,
        open: Decimal.new("50000.0"),
        high: Decimal.new("51000.0"),
        low: Decimal.new("49000.0"),
        close: Decimal.new("50500.0"),
        volume: Decimal.new("100.0"),
        quote_volume: nil,
        trades_count: nil,
        taker_buy_base_volume: nil,
        taker_buy_quote_volume: nil,
        ignore: nil
      }

      tuple = Kline.kline_to_tuple(kline)

      assert tuple == {
               "BTCUSDT",
               "binance",
               "1h",
               now,
               Decimal.new("50000.0"),
               Decimal.new("51000.0"),
               Decimal.new("49000.0"),
               Decimal.new("50500.0"),
               Decimal.new("100.0"),
               nil,
               nil,
               nil,
               nil,
               nil
             }
    end
  end

  describe "round-trip conversion" do
    test "kline_to_tuple and tuple_to_kline are inverses" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      original_kline = %Kline{
        symbol: "BTCUSDT",
        platform: "binance",
        interval: "1h",
        timestamp: now,
        open: Decimal.new("50000.0"),
        high: Decimal.new("51000.0"),
        low: Decimal.new("49000.0"),
        close: Decimal.new("50500.0"),
        volume: Decimal.new("100.0"),
        quote_volume: Decimal.new("5000000.0"),
        trades_count: 1000,
        taker_buy_base_volume: Decimal.new("50.0"),
        taker_buy_quote_volume: Decimal.new("2500000.0"),
        ignore: Decimal.new("0")
      }

      # Convert to tuple and back
      tuple = Kline.kline_to_tuple(original_kline)
      recovered_kline = Kline.tuple_to_kline(tuple)

      # Compare all fields
      assert recovered_kline.symbol == original_kline.symbol
      assert recovered_kline.platform == original_kline.platform
      assert recovered_kline.interval == original_kline.interval
      assert DateTime.compare(recovered_kline.timestamp, original_kline.timestamp) == :eq
      assert Decimal.equal?(recovered_kline.open, original_kline.open)
      assert Decimal.equal?(recovered_kline.high, original_kline.high)
      assert Decimal.equal?(recovered_kline.low, original_kline.low)
      assert Decimal.equal?(recovered_kline.close, original_kline.close)
      assert Decimal.equal?(recovered_kline.volume, original_kline.volume)
      assert Decimal.equal?(recovered_kline.quote_volume, original_kline.quote_volume)
      assert recovered_kline.trades_count == original_kline.trades_count

      assert Decimal.equal?(
               recovered_kline.taker_buy_base_volume,
               original_kline.taker_buy_base_volume
             )

      assert Decimal.equal?(
               recovered_kline.taker_buy_quote_volume,
               original_kline.taker_buy_quote_volume
             )

      assert Decimal.equal?(recovered_kline.ignore, original_kline.ignore)
    end
  end
end
