defmodule BeamBot.Exchanges.Infrastructure.Adapters.Redis.KlinesRedisAdapterTest do
  use ExUnit.Case, async: true
  alias BeamBot.Exchanges.Infrastructure.Adapters.Redis.KlinesRedisAdapter
  alias BeamBot.Infrastructure.RedisClient

  setup do
    # Start Redis client if not already started
    case Process.whereis(RedisClient) do
      nil -> {:ok, _} = RedisClient.start_link([])
      _pid -> :ok
    end

    # Clean up Redis before each test
    {:ok, keys} = Application.get_env(:beam_bot, :redis_client).keys("klines:*")

    Enum.each(keys, fn key ->
      {:ok, _} = Application.get_env(:beam_bot, :redis_client).del(key)
    end)

    :ok
  end

  @tag :aaa
  describe "store_klines/3" do
    test "stores klines data successfully" do
      symbol = "BTCUSDT"
      interval = "1h"

      klines = [
        [1_716_864_000_000, 20_000.0, 20_100.0, 19_900.0, 20_050.0, 100.0],
        [1_716_867_600_000, 20_050.0, 20_200.0, 20_000.0, 20_150.0, 150.0]
      ]

      assert {:ok, :stored} = KlinesRedisAdapter.store_klines(symbol, interval, klines)

      # Verify the data was stored correctly
      assert {:ok, klines} = KlinesRedisAdapter.get_klines(symbol, interval)
      assert length(klines) == 2

      assert Enum.at(klines, 0) == [
               1_716_864_000_000,
               20_000.0,
               20_100.0,
               19_900.0,
               20_050.0,
               100.0
             ]

      assert Enum.at(klines, 1) == [
               1_716_867_600_000,
               20_050.0,
               20_200.0,
               20_000.0,
               20_150.0,
               150.0
             ]
    end

    test "handles empty klines list" do
      symbol = "BTCUSDT"
      interval = "1h"
      klines = []

      assert {:ok, :stored} = KlinesRedisAdapter.store_klines(symbol, interval, klines)
      assert {:ok, []} = KlinesRedisAdapter.get_klines(symbol, interval)
    end

    test "handles invalid kline data" do
      symbol = "BTCUSDT"
      interval = "1h"
      klines = [[1_716_864_000_000, "invalid", 20_100.0, 19_900.0, 20_050.0, 100.0]]

      assert {:error, _} = KlinesRedisAdapter.store_klines(symbol, interval, klines)
    end
  end

  describe "get_klines/5" do
    setup do
      symbol = "BTCUSDT"
      interval = "1h"

      klines = [
        [1_716_864_000_000, 20_000.0, 20_100.0, 19_900.0, 20_050.0, 100.0],
        [1_716_867_600_000, 20_050.0, 20_200.0, 20_000.0, 20_150.0, 150.0],
        [1_716_871_200_000, 20_150.0, 20_300.0, 20_100.0, 20_250.0, 200.0]
      ]

      {:ok, _} = KlinesRedisAdapter.store_klines(symbol, interval, klines)
      %{symbol: symbol, interval: interval, klines: klines}
    end

    test "retrieves all klines", %{symbol: symbol, interval: interval, klines: klines} do
      assert {:ok, ^klines} = KlinesRedisAdapter.get_klines(symbol, interval)
    end

    test "retrieves klines with limit", %{symbol: symbol, interval: interval} do
      assert {:ok, klines} = KlinesRedisAdapter.get_klines(symbol, interval, 2)
      assert length(klines) == 2
    end

    test "retrieves klines within time range", %{symbol: symbol, interval: interval} do
      start_time = 1_716_864_000_000
      end_time = 1_716_867_600_000

      assert {:ok, klines} =
               KlinesRedisAdapter.get_klines(symbol, interval, 500, start_time, end_time)

      assert length(klines) == 2

      assert Enum.all?(klines, fn [timestamp | _] ->
               timestamp >= start_time and timestamp <= end_time
             end)
    end

    test "returns empty list for non-existent symbol", %{interval: interval} do
      assert {:ok, []} = KlinesRedisAdapter.get_klines("NONEXISTENT", interval)
    end

    test "returns empty list for non-existent interval", %{symbol: symbol} do
      assert {:ok, []} = KlinesRedisAdapter.get_klines(symbol, "1d")
    end
  end
end
