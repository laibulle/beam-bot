defmodule BeamBot.Exchanges.Infrastructure.Adapters.Pg.KlinesTuplesRepositoryPgTest do
  @moduledoc """
  Test suite for the KlinesTuplesRepositoryPg module.
  """

  use BeamBot.DataCase
  alias BeamBot.Exchanges.Infrastructure.Adapters.Pg.KlinesTuplesRepositoryPg
  alias BeamBot.Repo

  setup do
    # Clean up the klines table before each test
    Repo.delete_all("klines")

    # Create test data with all fields from the implementation
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    klines = [
      {
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
      },
      {
        "BTCUSDT",
        "binance",
        "1h",
        DateTime.add(now, -3600),
        Decimal.new("49500.0"),
        Decimal.new("50500.0"),
        Decimal.new("49000.0"),
        Decimal.new("50000.0"),
        Decimal.new("120.0"),
        Decimal.new("5940000.0"),
        1200,
        Decimal.new("60.0"),
        Decimal.new("2970000.0"),
        Decimal.new("0")
      }
    ]

    {:ok, count} = KlinesTuplesRepositoryPg.store_klines_tuples(klines)

    %{klines: klines, count: count, now: now}
  end

  describe "store_klines_tuples/1" do
    test "successfully stores klines with all fields" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      test_klines = [
        {
          "ETHUSDT",
          "binance",
          "4h",
          now,
          Decimal.new("2000.0"),
          Decimal.new("2100.0"),
          Decimal.new("1900.0"),
          Decimal.new("2050.0"),
          Decimal.new("500.0"),
          Decimal.new("1000000.0"),
          2000,
          Decimal.new("250.0"),
          Decimal.new("500000.0"),
          Decimal.new("0")
        }
      ]

      assert {:ok, 1} = KlinesTuplesRepositoryPg.store_klines_tuples(test_klines)

      [stored_kline] = KlinesTuplesRepositoryPg.get_klines_tuples("ETHUSDT", "4h") |> elem(1)
      test_kline = List.first(test_klines)

      # symbol
      assert elem(stored_kline, 0) == elem(test_kline, 0)
      # platform
      assert elem(stored_kline, 1) == elem(test_kline, 1)
      # interval
      assert elem(stored_kline, 2) == elem(test_kline, 2)
      # timestamp
      assert DateTime.compare(elem(stored_kline, 3), elem(test_kline, 3)) == :eq
      # open
      assert Decimal.equal?(elem(stored_kline, 4), elem(test_kline, 4))
      # high
      assert Decimal.equal?(elem(stored_kline, 5), elem(test_kline, 5))
      # low
      assert Decimal.equal?(elem(stored_kline, 6), elem(test_kline, 6))
      # close
      assert Decimal.equal?(elem(stored_kline, 7), elem(test_kline, 7))
      # volume
      assert Decimal.equal?(elem(stored_kline, 8), elem(test_kline, 8))
      # quote_volume
      assert Decimal.equal?(elem(stored_kline, 9), elem(test_kline, 9))
      # trades_count
      assert elem(stored_kline, 10) == elem(test_kline, 10)
      # taker_buy_base_volume
      assert Decimal.equal?(elem(stored_kline, 11), elem(test_kline, 11))
      # taker_buy_quote_volume
      assert Decimal.equal?(elem(stored_kline, 12), elem(test_kline, 12))
      # ignore
      assert Decimal.equal?(elem(stored_kline, 13), elem(test_kline, 13))
    end

    test "handles empty list" do
      assert {:ok, 0} = KlinesTuplesRepositoryPg.store_klines_tuples([])
    end

    test "handles invalid data" do
      invalid_klines = [{"invalid", "data"}]
      assert {:error, _} = KlinesTuplesRepositoryPg.store_klines_tuples(invalid_klines)
    end

    test "handles conflict with existing data", %{klines: [kline | _]} do
      # Try to insert the same kline again
      assert {:ok, 0} = KlinesTuplesRepositoryPg.store_klines_tuples([kline])
    end
  end

  describe "get_klines_tuples/5" do
    test "retrieves klines with all fields", %{klines: [kline | _]} do
      assert {:ok, [retrieved_kline | _]} =
               KlinesTuplesRepositoryPg.get_klines_tuples(elem(kline, 0), elem(kline, 2))

      # symbol
      assert elem(retrieved_kline, 0) == elem(kline, 0)
      # platform
      assert elem(retrieved_kline, 1) == elem(kline, 1)
      # interval
      assert elem(retrieved_kline, 2) == elem(kline, 2)
      # timestamp
      assert DateTime.compare(elem(retrieved_kline, 3), elem(kline, 3)) == :eq
      # open
      assert Decimal.equal?(elem(retrieved_kline, 4), elem(kline, 4))
      # high
      assert Decimal.equal?(elem(retrieved_kline, 5), elem(kline, 5))
      # low
      assert Decimal.equal?(elem(retrieved_kline, 6), elem(kline, 6))
      # close
      assert Decimal.equal?(elem(retrieved_kline, 7), elem(kline, 7))
      # volume
      assert Decimal.equal?(elem(retrieved_kline, 8), elem(kline, 8))
      # quote_volume
      assert Decimal.equal?(elem(retrieved_kline, 9), elem(kline, 9))
      # trades_count
      assert elem(retrieved_kline, 10) == elem(kline, 10)
      # taker_buy_base_volume
      assert Decimal.equal?(elem(retrieved_kline, 11), elem(kline, 11))
      # taker_buy_quote_volume
      assert Decimal.equal?(elem(retrieved_kline, 12), elem(kline, 12))
      # ignore
      assert Decimal.equal?(elem(retrieved_kline, 13), elem(kline, 13))
    end

    test "respects limit parameter", %{klines: [kline | _]} do
      assert {:ok, retrieved_klines} =
               KlinesTuplesRepositoryPg.get_klines_tuples(elem(kline, 0), elem(kline, 2), 1)

      assert length(retrieved_klines) == 1
    end

    test "filters by time range", %{klines: [kline | _], now: now} do
      start_time = DateTime.add(now, -7200)
      end_time = DateTime.add(now, 3600)

      assert {:ok, retrieved_klines} =
               KlinesTuplesRepositoryPg.get_klines_tuples(
                 elem(kline, 0),
                 elem(kline, 2),
                 500,
                 start_time,
                 end_time
               )

      assert length(retrieved_klines) == 2

      assert Enum.all?(retrieved_klines, fn k ->
               DateTime.compare(elem(k, 3), start_time) in [:eq, :gt] and
                 DateTime.compare(elem(k, 3), end_time) in [:eq, :lt]
             end)
    end

    test "returns empty list for non-existent symbol" do
      assert {:ok, []} = KlinesTuplesRepositoryPg.get_klines_tuples("NONEXISTENT", "1h")
    end
  end

  describe "get_latest_kline_tuple/2" do
    test "retrieves the latest kline", %{klines: [latest | _]} do
      assert {:ok, retrieved_kline} =
               KlinesTuplesRepositoryPg.get_latest_kline_tuple(elem(latest, 0), elem(latest, 2))

      # symbol
      assert elem(retrieved_kline, 0) == elem(latest, 0)
      # interval
      assert elem(retrieved_kline, 2) == elem(latest, 2)
      # timestamp
      assert DateTime.compare(elem(retrieved_kline, 3), elem(latest, 3)) == :eq
    end

    test "returns nil for non-existent symbol" do
      assert {:ok, nil} = KlinesTuplesRepositoryPg.get_latest_kline_tuple("NONEXISTENT", "1h")
    end
  end

  describe "delete_klines_tuples/4" do
    test "deletes klines within time range", %{klines: [kline | _], now: now} do
      start_time = DateTime.add(now, -7200)
      end_time = DateTime.add(now, 3600)

      assert {:ok, 2} =
               KlinesTuplesRepositoryPg.delete_klines_tuples(
                 elem(kline, 0),
                 elem(kline, 2),
                 start_time,
                 end_time
               )

      assert {:ok, []} =
               KlinesTuplesRepositoryPg.get_klines_tuples(elem(kline, 0), elem(kline, 2))
    end

    test "handles non-existent klines", %{now: now} do
      assert {:ok, 0} =
               KlinesTuplesRepositoryPg.delete_klines_tuples(
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
               KlinesTuplesRepositoryPg.delete_klines_tuples(
                 elem(kline, 0),
                 elem(kline, 2),
                 start_time,
                 end_time
               )

      assert {:ok, [_, _]} =
               KlinesTuplesRepositoryPg.get_klines_tuples(elem(kline, 0), elem(kline, 2))
    end
  end
end
