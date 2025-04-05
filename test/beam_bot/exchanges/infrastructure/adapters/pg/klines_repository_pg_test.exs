defmodule BeamBot.Exchanges.Infrastructure.Adapters.Pg.KlinesRepositoryPgTest do
  use BeamBot.DataCase
  alias BeamBot.Exchanges.Domain.Kline
  alias BeamBot.Exchanges.Infrastructure.Adapters.Pg.KlinesRepositoryPg
  alias BeamBot.Repo

  setup do
    # Clean up the klines table before each test
    Repo.delete_all(Kline)

    # Create test data with all fields from the implementation
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    klines = [
      %Kline{
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
      },
      %Kline{
        symbol: "BTCUSDT",
        platform: "binance",
        interval: "1h",
        timestamp: DateTime.add(now, -3600),
        open: Decimal.new("49500.0"),
        high: Decimal.new("50500.0"),
        low: Decimal.new("49000.0"),
        close: Decimal.new("50000.0"),
        volume: Decimal.new("120.0"),
        quote_volume: Decimal.new("5940000.0"),
        trades_count: 1200,
        taker_buy_base_volume: Decimal.new("60.0"),
        taker_buy_quote_volume: Decimal.new("2970000.0"),
        ignore: Decimal.new("0")
      }
    ]

    {:ok, count} = KlinesRepositoryPg.store_klines(klines)

    %{klines: klines, count: count, now: now}
  end

  describe "store_klines/1" do
    test "successfully stores klines with all fields" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      test_klines = [
        %Kline{
          # Different symbol
          symbol: "ETHUSDT",
          platform: "binance",
          # Different interval
          interval: "4h",
          timestamp: now,
          open: Decimal.new("2000.0"),
          high: Decimal.new("2100.0"),
          low: Decimal.new("1900.0"),
          close: Decimal.new("2050.0"),
          volume: Decimal.new("500.0"),
          quote_volume: Decimal.new("1000000.0"),
          trades_count: 2000,
          taker_buy_base_volume: Decimal.new("250.0"),
          taker_buy_quote_volume: Decimal.new("500000.0"),
          ignore: Decimal.new("0")
        }
      ]

      assert {:ok, 1} = KlinesRepositoryPg.store_klines(test_klines)

      stored_kline = Repo.one(from k in Kline, where: k.symbol == "ETHUSDT", limit: 1)
      test_kline = List.first(test_klines)

      assert stored_kline.symbol == test_kline.symbol
      assert stored_kline.platform == test_kline.platform
      assert stored_kline.interval == test_kline.interval
      assert DateTime.compare(stored_kline.timestamp, test_kline.timestamp) == :eq
      assert Decimal.equal?(stored_kline.open, test_kline.open)
      assert Decimal.equal?(stored_kline.high, test_kline.high)
      assert Decimal.equal?(stored_kline.low, test_kline.low)
      assert Decimal.equal?(stored_kline.close, test_kline.close)
      assert Decimal.equal?(stored_kline.volume, test_kline.volume)
      assert Decimal.equal?(stored_kline.quote_volume, test_kline.quote_volume)
      assert stored_kline.trades_count == test_kline.trades_count
      assert Decimal.equal?(stored_kline.taker_buy_base_volume, test_kline.taker_buy_base_volume)

      assert Decimal.equal?(
               stored_kline.taker_buy_quote_volume,
               test_kline.taker_buy_quote_volume
             )

      assert Decimal.equal?(stored_kline.ignore, test_kline.ignore)
    end

    test "handles string decimal values" do
      Repo.delete_all(Kline)

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      kline = %Kline{
        symbol: "BTCUSDT",
        platform: "binance",
        interval: "1h",
        timestamp: now,
        open: "50000.0",
        high: "51000.0",
        low: "49000.0",
        close: "50500.0",
        volume: "100.0",
        quote_volume: "5000000.0",
        trades_count: 1000,
        taker_buy_base_volume: "50.0",
        taker_buy_quote_volume: "2500000.0",
        ignore: "0"
      }

      assert {:ok, 1} = KlinesRepositoryPg.store_klines([kline])
    end

    test "handles numeric decimal values" do
      Repo.delete_all(Kline)

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

      assert {:ok, 1} = KlinesRepositoryPg.store_klines([kline])
    end

    test "handles empty list" do
      assert {:ok, 0} = KlinesRepositoryPg.store_klines([])
    end

    test "handles invalid data" do
      invalid_klines = [%{invalid: "data"}]
      assert {:error, _} = KlinesRepositoryPg.store_klines(invalid_klines)
    end

    test "handles conflict with existing data", %{klines: [kline | _]} do
      # Try to insert the same kline again
      assert {:ok, 0} = KlinesRepositoryPg.store_klines([kline])
    end
  end

  describe "get_klines/5" do
    test "retrieves klines with all fields", %{klines: [kline | _]} do
      assert {:ok, [retrieved_kline | _]} =
               KlinesRepositoryPg.get_klines(kline.symbol, kline.interval)

      assert retrieved_kline.symbol == kline.symbol
      assert retrieved_kline.platform == kline.platform
      assert retrieved_kline.interval == kline.interval
      assert DateTime.compare(retrieved_kline.timestamp, kline.timestamp) == :eq
      assert Decimal.equal?(retrieved_kline.open, kline.open)
      assert Decimal.equal?(retrieved_kline.high, kline.high)
      assert Decimal.equal?(retrieved_kline.low, kline.low)
      assert Decimal.equal?(retrieved_kline.close, kline.close)
      assert Decimal.equal?(retrieved_kline.volume, kline.volume)
      assert Decimal.equal?(retrieved_kline.quote_volume, kline.quote_volume)
      assert retrieved_kline.trades_count == kline.trades_count
      assert Decimal.equal?(retrieved_kline.taker_buy_base_volume, kline.taker_buy_base_volume)
      assert Decimal.equal?(retrieved_kline.taker_buy_quote_volume, kline.taker_buy_quote_volume)
      assert Decimal.equal?(retrieved_kline.ignore, kline.ignore)
    end

    test "respects limit parameter", %{klines: [kline | _]} do
      assert {:ok, retrieved_klines} =
               KlinesRepositoryPg.get_klines(kline.symbol, kline.interval, 1)

      assert length(retrieved_klines) == 1
    end

    test "filters by time range", %{klines: [kline | _], now: now} do
      start_time = DateTime.add(now, -7200)
      end_time = DateTime.add(now, 3600)

      assert {:ok, retrieved_klines} =
               KlinesRepositoryPg.get_klines(
                 kline.symbol,
                 kline.interval,
                 500,
                 start_time,
                 end_time
               )

      assert length(retrieved_klines) == 2

      assert Enum.all?(retrieved_klines, fn k ->
               DateTime.compare(k.timestamp, start_time) in [:eq, :gt] and
                 DateTime.compare(k.timestamp, end_time) in [:eq, :lt]
             end)
    end

    test "returns empty list for non-existent symbol" do
      assert {:ok, []} = KlinesRepositoryPg.get_klines("NONEXISTENT", "1h")
    end
  end

  describe "get_latest_kline/2" do
    test "retrieves the latest kline", %{klines: [latest | _]} do
      assert {:ok, retrieved_kline} =
               KlinesRepositoryPg.get_latest_kline(latest.symbol, latest.interval)

      assert retrieved_kline.symbol == latest.symbol
      assert retrieved_kline.interval == latest.interval
      assert DateTime.compare(retrieved_kline.timestamp, latest.timestamp) == :eq
    end

    test "returns nil for non-existent symbol" do
      assert {:ok, nil} = KlinesRepositoryPg.get_latest_kline("NONEXISTENT", "1h")
    end
  end

  describe "delete_klines/4" do
    test "deletes klines within time range", %{klines: [kline | _], now: now} do
      start_time = DateTime.add(now, -7200)
      end_time = DateTime.add(now, 3600)

      assert {:ok, 2} =
               KlinesRepositoryPg.delete_klines(
                 kline.symbol,
                 kline.interval,
                 start_time,
                 end_time
               )

      assert {:ok, []} = KlinesRepositoryPg.get_klines(kline.symbol, kline.interval)
    end

    test "handles non-existent klines", %{now: now} do
      assert {:ok, 0} =
               KlinesRepositoryPg.delete_klines(
                 "NONEXISTENT",
                 "1h",
                 DateTime.add(now, -3600),
                 now
               )
    end

    test "respects time range boundaries", %{klines: [kline | _], now: now} do
      # Delete only future klines
      start_time = DateTime.add(now, 3600)
      end_time = DateTime.add(now, 7200)

      assert {:ok, 0} =
               KlinesRepositoryPg.delete_klines(
                 kline.symbol,
                 kline.interval,
                 start_time,
                 end_time
               )

      assert {:ok, [_, _]} = KlinesRepositoryPg.get_klines(kline.symbol, kline.interval)
    end
  end
end
