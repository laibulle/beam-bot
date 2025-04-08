defmodule BeamBot.Exchanges.Infrastructure.Adapters.Exchanges.BinanceReqAdapterTest do
  use ExUnit.Case, async: true

  alias BeamBot.Exchanges.Infrastructure.Adapters.Exchanges.BinanceReqAdapter

  @one_minute_ms 1 * 60 * 1000
  @three_minutes_ms 3 * @one_minute_ms
  @five_minutes_ms 5 * @one_minute_ms
  @fifteen_minutes_ms 15 * @one_minute_ms
  @thirty_minutes_ms 30 * @one_minute_ms
  @one_hour_ms 1 * 60 * 60 * 1000
  @two_hours_ms 2 * @one_hour_ms
  @four_hours_ms 4 * @one_hour_ms
  @six_hours_ms 6 * @one_hour_ms
  @eight_hours_ms 8 * @one_hour_ms
  @twelve_hours_ms 12 * @one_hour_ms
  @one_day_ms 1 * 24 * @one_hour_ms
  @three_days_ms 3 * @one_day_ms
  @one_week_ms 7 * @one_day_ms
  # Approx 1 Month
  @one_month_ms 30 * @one_day_ms

  describe "compute_klines_limits/3" do
    # --- Minute Intervals ---
    test "returns correct limit for 1m interval" do
      assert BinanceReqAdapter.compute_klines_limits("1m", 0, 0) == {:ok, 1}
      assert BinanceReqAdapter.compute_klines_limits("1m", 0, @one_minute_ms - 1) == {:ok, 1}
      assert BinanceReqAdapter.compute_klines_limits("1m", 0, @one_minute_ms) == {:ok, 2}

      assert BinanceReqAdapter.compute_klines_limits("1m", 1000, 1000 + @one_minute_ms * 5) ==
               {:ok, 6}
    end

    test "returns correct limit for 3m interval" do
      assert BinanceReqAdapter.compute_klines_limits("3m", 0, @three_minutes_ms * 2) == {:ok, 3}
    end

    test "returns correct limit for 5m interval" do
      assert BinanceReqAdapter.compute_klines_limits("5m", 0, @five_minutes_ms * 4) == {:ok, 5}
    end

    test "returns correct limit for 15m interval" do
      assert BinanceReqAdapter.compute_klines_limits("15m", 0, @fifteen_minutes_ms) ==
               {:ok, 2}
    end

    test "returns correct limit for 30m interval" do
      assert BinanceReqAdapter.compute_klines_limits("30m", 0, @thirty_minutes_ms * 3) == {:ok, 4}
    end

    # --- Hour Intervals ---
    test "returns correct limit for 1h interval" do
      assert BinanceReqAdapter.compute_klines_limits("1h", 0, 0) == {:ok, 1}
      assert BinanceReqAdapter.compute_klines_limits("1h", 0, @one_hour_ms - 1) == {:ok, 1}
      assert BinanceReqAdapter.compute_klines_limits("1h", 0, @one_hour_ms) == {:ok, 2}
    end

    test "returns correct limit for 2h interval" do
      assert BinanceReqAdapter.compute_klines_limits("2h", 0, @two_hours_ms * 2) == {:ok, 3}
    end

    test "returns correct limit for 4h interval" do
      assert BinanceReqAdapter.compute_klines_limits("4h", 0, @four_hours_ms * 3) == {:ok, 4}
    end

    test "returns correct limit for 6h interval" do
      assert BinanceReqAdapter.compute_klines_limits("6h", 0, @six_hours_ms) == {:ok, 2}
    end

    test "returns correct limit for 8h interval" do
      assert BinanceReqAdapter.compute_klines_limits("8h", 0, @eight_hours_ms * 2) == {:ok, 3}
    end

    test "returns correct limit for 12h interval" do
      assert BinanceReqAdapter.compute_klines_limits("12h", 0, @twelve_hours_ms * 4) == {:ok, 5}
    end

    # --- Day/Week/Month Intervals ---
    test "returns correct limit for 1d interval" do
      assert BinanceReqAdapter.compute_klines_limits("1d", 0, 0) == {:ok, 1}
      assert BinanceReqAdapter.compute_klines_limits("1d", 0, @one_day_ms - 1) == {:ok, 1}
      assert BinanceReqAdapter.compute_klines_limits("1d", 0, @one_day_ms) == {:ok, 2}
    end

    test "returns correct limit for 3d interval" do
      assert BinanceReqAdapter.compute_klines_limits("3d", 0, @three_days_ms * 2) == {:ok, 3}
    end

    test "returns correct limit for 1w interval" do
      assert BinanceReqAdapter.compute_klines_limits("1w", 0, 0) == {:ok, 1}
      assert BinanceReqAdapter.compute_klines_limits("1w", 0, @one_week_ms - 1) == {:ok, 1}
      assert BinanceReqAdapter.compute_klines_limits("1w", 0, @one_week_ms) == {:ok, 2}
    end

    test "returns correct limit for 1M interval" do
      assert BinanceReqAdapter.compute_klines_limits("1M", 0, 0) == {:ok, 1}
      assert BinanceReqAdapter.compute_klines_limits("1M", 0, @one_month_ms - 1) == {:ok, 1}
      assert BinanceReqAdapter.compute_klines_limits("1M", 0, @one_month_ms) == {:ok, 2}
    end

    # --- Limit check ---
    test "returns error when limit exceeds 5000" do
      # limit = div(5000 * @one_minute_ms, @one_minute_ms) + 1 = 5001
      assert BinanceReqAdapter.compute_klines_limits("1m", 0, 5000 * @one_minute_ms) ==
               {:error, "Limit is greater than 5000"}
    end

    test "returns ok when limit is exactly 5000" do
      # limit = div(4999 * @one_minute_ms, @one_minute_ms) + 1 = 5000
      assert BinanceReqAdapter.compute_klines_limits("1m", 0, 4999 * @one_minute_ms) ==
               {:ok, 5000}

      # limit = div(5000 * @one_minute_ms - 1, @one_minute_ms) + 1 = 4999 + 1 = 5000
      assert BinanceReqAdapter.compute_klines_limits("1m", 0, 5000 * @one_minute_ms - 1) ==
               {:ok, 5000}
    end

    test "handles from > to" do
      # limit = div(-1, interval_ms) + 1 = -1 + 1 = 0
      assert BinanceReqAdapter.compute_klines_limits("1h", @one_hour_ms, @one_hour_ms - 1) ==
               {:ok, 1}

      assert BinanceReqAdapter.compute_klines_limits("1m", 1000, 0) == {:ok, 1}
    end
  end
end
