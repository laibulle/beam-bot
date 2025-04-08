defmodule BeamBot.Exchanges.Infrastructure.Workers.BinanceMultiRateLimiterTest do
  use ExUnit.Case, async: true
  alias BeamBot.Exchanges.Infrastructure.Workers.BinanceMultiRateLimiter

  @moduletag :capture_log

  setup do
    # Start a new rate limiter for each test with a unique name
    test_name = :"#{:rand.uniform(999_999_999)}"
    {:ok, pid} = BinanceMultiRateLimiter.start_link(name: test_name)
    %{rate_limiter: test_name, pid: pid}
  end

  describe "weight-based rate limiting" do
    test "allows requests within weight limit", %{rate_limiter: limiter} do
      # Try with a small weight
      assert :ok = GenServer.call(limiter, {:check_weight_limit, 100})

      # Try with a larger weight
      assert :ok = GenServer.call(limiter, {:check_weight_limit, 500})

      # Try with a weight that should exceed the limit
      assert {:error, wait_time} = GenServer.call(limiter, {:check_weight_limit, 6000})
      assert wait_time > 0
      # Should not wait more than a minute
      assert wait_time <= 60_000
    end

    test "resets weight counter at minute boundary", %{rate_limiter: limiter} do
      # Get current minute start
      now = :os.system_time(:millisecond)
      current_minute = div(now, 60_000) * 60_000
      next_minute = current_minute + 60_000

      # Fill up most of the weight limit
      assert :ok = GenServer.call(limiter, {:check_weight_limit, 5900})

      # This should be rate limited
      assert {:error, _} = GenServer.call(limiter, {:check_weight_limit, 200})

      # Wait until just after the next minute starts
      wait_time = next_minute - now + 10
      Process.sleep(wait_time)

      # Should be able to make requests again
      assert :ok = GenServer.call(limiter, {:check_weight_limit, 6000})
    end
  end

  describe "order rate limiting" do
    test "resets order counter at second boundary", %{rate_limiter: limiter} do
      # Get current second start
      now = :os.system_time(:millisecond)
      current_second = div(now, 1000) * 1000
      next_second = current_second + 1000

      # Fill up the per-second limit
      for _ <- 1..100 do
        assert :ok = GenServer.call(limiter, :check_order_limit)
      end

      # This should be rate limited
      assert {:error, wait_time} = GenServer.call(limiter, :check_order_limit)
      assert wait_time > 0
      # Should not wait more than a second
      assert wait_time <= 1000

      # Wait until just after the next second starts
      wait_time = next_second - now + 10
      Process.sleep(wait_time)

      # Should be able to place orders again
      assert :ok = GenServer.call(limiter, :check_order_limit)
    end

    test "resets order counter at day boundary", %{rate_limiter: limiter} do
      # Mock a state where we're near the day limit
      state = :sys.get_state(limiter)
      now = :os.system_time(:millisecond)
      day_start = div(div(now, 1000), 86_400) * 86_400 * 1000

      # Artificially set the state to simulate being near the day limit
      state = %{state | current_day_start: day_start, current_day_orders: 199_990}
      :sys.replace_state(limiter, fn _ -> state end)

      # Should still allow a few more orders
      for _ <- 1..9 do
        assert :ok = GenServer.call(limiter, :check_order_limit)
      end

      # This should be rate limited
      assert {:error, wait_time} = GenServer.call(limiter, :check_order_limit)
      assert wait_time > 0
      # Should not wait more than a day
      assert wait_time <= 86_400_000
    end
  end

  describe "raw request rate limiting" do
    test "resets request counter at 5-minute intervals", %{rate_limiter: limiter} do
      # Get current 5-minute interval start
      now = :os.system_time(:millisecond)
      current_5min = div(now, 300_000) * 300_000
      next_5min = current_5min + 300_000

      # Fill up the 5-minute limit
      for _ <- 1..61_000 do
        GenServer.cast(limiter, :record_raw_request)
      end

      # This should be rate limited
      assert {:error, wait_time} = GenServer.call(limiter, :check_raw_request_limit)
      assert wait_time > 0
      # Should not wait more than 5 minutes
      assert wait_time <= 300_000

      # Wait until just after the next 5-minute interval starts
      wait_time = next_5min - now + 10
      Process.sleep(wait_time)

      # Should be able to make requests again
      assert :ok = GenServer.call(limiter, :check_raw_request_limit)
    end
  end

  describe "interval calculations" do
    test "calculates correct minute interval start", %{rate_limiter: limiter} do
      state = :sys.get_state(limiter)
      now = :os.system_time(:millisecond)
      expected_minute_start = div(now, 60_000) * 60_000
      assert state.current_minute_start == expected_minute_start
    end

    test "calculates correct 5-minute interval start", %{rate_limiter: limiter} do
      state = :sys.get_state(limiter)
      now = :os.system_time(:millisecond)
      expected_5min_start = div(now, 300_000) * 300_000
      assert state.current_5min_start == expected_5min_start
    end

    test "calculates correct day start in UTC", %{rate_limiter: limiter} do
      state = :sys.get_state(limiter)
      now = :os.system_time(:millisecond)
      expected_day_start = div(div(now, 1000), 86_400) * 86_400 * 1000
      assert state.current_day_start == expected_day_start
    end
  end

  describe "concurrent access" do
    test "handles concurrent weight requests safely", %{rate_limiter: limiter} do
      tasks =
        for _ <- 1..20 do
          Task.async(fn ->
            GenServer.call(limiter, {:check_weight_limit, 500})
          end)
        end

      results = Task.await_many(tasks, 5000)
      ok_count = Enum.count(results, &(&1 == :ok))
      error_count = Enum.count(results, &match?({:error, _}, &1))

      # We should have some successful requests and some rate limited ones
      assert ok_count > 0
      assert error_count > 0
      assert ok_count + error_count == 20
    end

    test "handles concurrent order requests safely", %{rate_limiter: limiter} do
      tasks =
        for _ <- 1..150 do
          Task.async(fn ->
            GenServer.call(limiter, :check_order_limit)
          end)
        end

      results = Task.await_many(tasks, 5000)
      ok_count = Enum.count(results, &(&1 == :ok))
      error_count = Enum.count(results, &match?({:error, _}, &1))

      # We should have exactly 100 successful requests (per-second limit)
      assert ok_count <= 100
      assert ok_count + error_count == 150
    end
  end
end
