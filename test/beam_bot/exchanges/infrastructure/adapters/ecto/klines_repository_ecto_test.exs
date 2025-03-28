defmodule BeamBot.Exchanges.Infrastructure.Ecto.KlinesRepositoryEctoTest do
  use BeamBot.DataCase
  doctest BeamBot.Exchanges.Infrastructure.Ecto.KlinesRepositoryEcto
  alias BeamBot.Exchanges.Domain.Models.Kline
  alias BeamBot.Exchanges.Infrastructure.Ecto.KlinesRepositoryEcto
  alias BeamBot.Repo

  setup do
    # Create test data
    now = DateTime.utc_now()

    klines = [
      %Kline{
        symbol: "BTC/USDT",
        interval: "1h",
        timestamp: DateTime.add(now, -3600),
        open: 50_000.0,
        high: 51_000.0,
        low: 49_000.0,
        close: 50_500.0,
        volume: 100.0
      },
      %Kline{
        symbol: "BTC/USDT",
        interval: "1h",
        timestamp: now,
        open: 50_500.0,
        high: 51_500.0,
        low: 49_500.0,
        close: 51_000.0,
        volume: 150.0
      }
    ]

    {:ok, _} = KlinesRepositoryEcto.store_klines(klines)

    %{klines: klines}
  end

  @tag :aaa
  describe "store_klines/1" do
    test "successfully stores klines", %{klines: klines} do
      assert {:ok, 2} = KlinesRepositoryEcto.store_klines(klines)
    end

    test "handles empty list" do
      assert {:ok, 0} = KlinesRepositoryEcto.store_klines([])
    end

    test "handles invalid data" do
      invalid_klines = [%{invalid: "data"}]
      assert {:error, _} = KlinesRepositoryEcto.store_klines(invalid_klines)
    end
  end

  describe "get_klines/5" do
    test "retrieves klines for symbol and interval", %{klines: klines} do
      assert {:ok, retrieved_klines} = KlinesRepositoryEcto.get_klines("BTC/USDT", "1h")
      assert length(retrieved_klines) == 2
      assert Enum.all?(retrieved_klines, &(&1.symbol == "BTC/USDT"))
      assert Enum.all?(retrieved_klines, &(&1.interval == "1h"))
    end

    test "respects limit parameter" do
      assert {:ok, retrieved_klines} = KlinesRepositoryEcto.get_klines("BTC/USDT", "1h", 1)
      assert length(retrieved_klines) == 1
    end

    test "filters by time range" do
      now = DateTime.utc_now()
      start_time = DateTime.add(now, -7200)
      end_time = DateTime.add(now, 3600)

      assert {:ok, retrieved_klines} =
               KlinesRepositoryEcto.get_klines(
                 "BTC/USDT",
                 "1h",
                 500,
                 start_time,
                 end_time
               )

      assert length(retrieved_klines) == 2
    end

    test "returns empty list for non-existent symbol" do
      assert {:ok, []} = KlinesRepositoryEcto.get_klines("NONEXISTENT", "1h")
    end
  end

  describe "get_latest_kline/2" do
    test "retrieves the latest kline", %{klines: [latest | _]} do
      assert {:ok, retrieved_kline} = KlinesRepositoryEcto.get_latest_kline("BTC/USDT", "1h")
      assert retrieved_kline.symbol == latest.symbol
      assert retrieved_kline.interval == latest.interval
      assert retrieved_kline.timestamp == latest.timestamp
    end

    test "returns nil for non-existent symbol" do
      assert {:ok, nil} = KlinesRepositoryEcto.get_latest_kline("NONEXISTENT", "1h")
    end
  end

  describe "delete_klines/4" do
    test "deletes klines within time range" do
      now = DateTime.utc_now()
      start_time = DateTime.add(now, -7200)
      end_time = DateTime.add(now, 3600)

      assert {:ok, 2} = KlinesRepositoryEcto.delete_klines("BTC/USDT", "1h", start_time, end_time)
      assert {:ok, []} = KlinesRepositoryEcto.get_klines("BTC/USDT", "1h")
    end

    test "handles non-existent klines" do
      now = DateTime.utc_now()

      assert {:ok, 0} =
               KlinesRepositoryEcto.delete_klines(
                 "NONEXISTENT",
                 "1h",
                 DateTime.add(now, -3600),
                 now
               )
    end
  end
end
