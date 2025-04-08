defmodule BeamBot.Exchanges.Infrastructure.Workers.BinanceRateLimiterTest do
  use ExUnit.Case, async: true
  alias BeamBot.Exchanges.Infrastructure.Workers.BinanceRateLimiter

  @moduletag :capture_log

  setup do
    # Get the current configuration
    config = BinanceRateLimiter.get_config()

    # Start a new rate limiter for each test with a unique name
    test_name = :"#{:rand.uniform(999_999_999)}"
    {:ok, pid} = BinanceRateLimiter.start_link(name: test_name)
    %{rate_limiter: test_name, pid: pid, config: config}
  end

  describe "configuration" do
    test "uses configured values", %{config: config} do
      binance_config = Application.get_env(:beam_bot, :binance_rate_limiter, [])
      assert config.window_size == Keyword.get(binance_config, :window_size, 5_000)
      assert config.cleanup_interval == Keyword.get(binance_config, :cleanup_interval, 50)

      assert config.default_weight_per_minute ==
               Keyword.get(binance_config, :default_weight_per_minute, 50)
    end
  end

  describe "check_rate_limit/1" do
    test "allows requests within the limit", %{rate_limiter: limiter, config: config} do
      # Try with exactly half the limit
      half_limit = div(config.default_weight_per_minute, 2)
      assert :ok = GenServer.call(limiter, {:check_rate_limit, half_limit})

      # Second request should still work
      assert :ok = GenServer.call(limiter, {:check_rate_limit, half_limit})

      # Third request should be rate limited since we're over the limit
      assert {:error, wait_time} = GenServer.call(limiter, {:check_rate_limit, 1})
      assert wait_time > 0
    end

    test "rejects requests exceeding the limit", %{rate_limiter: limiter, config: config} do
      # First use up most of the capacity
      # 80% of limit
      initial_weight = div(config.default_weight_per_minute * 4, 5)
      assert :ok = GenServer.call(limiter, {:check_rate_limit, initial_weight})

      # Next request should be rate limited
      # Just over remaining capacity
      remaining_weight = div(config.default_weight_per_minute, 5) + 1
      assert {:error, wait_time} = GenServer.call(limiter, {:check_rate_limit, remaining_weight})
      assert wait_time > 0
    end

    test "handles multiple small requests", %{rate_limiter: limiter, config: config} do
      weight_per_request = 5
      request_count = div(config.default_weight_per_minute, weight_per_request)

      # Send requests until we reach the limit
      for _ <- 1..request_count do
        assert :ok = GenServer.call(limiter, {:check_rate_limit, weight_per_request})
      end

      # Next request should be rate limited
      assert {:error, wait_time} =
               GenServer.call(limiter, {:check_rate_limit, weight_per_request})

      assert wait_time > 0
    end
  end

  describe "record_request/1" do
    test "accurately tracks request weights", %{rate_limiter: limiter, config: config} do
      half_limit = div(config.default_weight_per_minute, 2)

      # Record some requests
      GenServer.cast(limiter, {:record_request, half_limit})
      GenServer.cast(limiter, {:record_request, half_limit})

      # Next request should be rate limited
      assert {:error, _wait_time} = GenServer.call(limiter, {:check_rate_limit, half_limit})
    end

    test "handles rapid request recording", %{rate_limiter: limiter, config: config} do
      weight_per_request = 5
      request_count = div(config.default_weight_per_minute, weight_per_request)

      # Rapidly record many small requests
      for _ <- 1..request_count do
        GenServer.cast(limiter, {:record_request, weight_per_request})
      end

      # Should be rate limited now
      assert {:error, _wait_time} =
               GenServer.call(limiter, {:check_rate_limit, weight_per_request})
    end
  end

  describe "cleanup behavior" do
    test "cleans up old requests after window", %{rate_limiter: limiter, config: config} do
      half_limit = div(config.default_weight_per_minute, 2)

      # Record requests
      GenServer.cast(limiter, {:record_request, half_limit})
      GenServer.cast(limiter, {:record_request, half_limit})

      # Wait for window to pass
      Process.sleep(config.window_size + config.cleanup_interval)

      # Should be allowed again
      assert :ok = GenServer.call(limiter, {:check_rate_limit, config.default_weight_per_minute})
    end

    test "maintains sliding window correctly", %{rate_limiter: limiter, config: config} do
      half_limit = div(config.default_weight_per_minute, 2)

      # Fill up half the capacity
      GenServer.cast(limiter, {:record_request, half_limit})

      # Wait for half the window
      Process.sleep(div(config.window_size, 2))

      # Add more requests
      assert :ok = GenServer.call(limiter, {:check_rate_limit, div(half_limit, 2)})
      GenServer.cast(limiter, {:record_request, div(half_limit, 2)})

      # Should be near limit
      assert {:error, _wait_time} = GenServer.call(limiter, {:check_rate_limit, half_limit})

      # Wait for first request to expire
      Process.sleep(div(config.window_size, 2) + config.cleanup_interval)

      # Should allow requests again
      assert :ok = GenServer.call(limiter, {:check_rate_limit, half_limit})
    end
  end

  describe "wait time calculation" do
    test "provides accurate wait times", %{rate_limiter: limiter, config: config} do
      # Fill the capacity
      GenServer.cast(limiter, {:record_request, config.default_weight_per_minute})

      # Try another request
      {:error, wait_time} = GenServer.call(limiter, {:check_rate_limit, 5})

      # Wait time should be close to window_size
      assert_in_delta wait_time, config.window_size, config.cleanup_interval
    end

    test "wait times decrease as requests expire", %{rate_limiter: limiter, config: config} do
      # Fill the capacity
      GenServer.cast(limiter, {:record_request, config.default_weight_per_minute})

      # Get initial wait time
      {:error, initial_wait} = GenServer.call(limiter, {:check_rate_limit, 5})

      # Wait for half the window
      half_window = div(config.window_size, 2)
      Process.sleep(half_window)

      # Get new wait time
      {:error, new_wait} = GenServer.call(limiter, {:check_rate_limit, 5})

      # New wait time should be about half_window less
      assert_in_delta new_wait, initial_wait - half_window, config.cleanup_interval
    end
  end

  describe "concurrent access" do
    test "handles concurrent requests safely", %{rate_limiter: limiter, config: config} do
      weight_per_request = 5
      request_count = 15
      max_success = div(config.default_weight_per_minute, weight_per_request)

      # First, fill up the rate limiter to its limit
      for _ <- 1..max_success do
        assert :ok = GenServer.call(limiter, {:check_rate_limit, weight_per_request})
      end

      # Now try concurrent requests - they should all be rate limited
      tasks =
        for _ <- 1..request_count do
          Task.async(fn ->
            GenServer.call(limiter, {:check_rate_limit, weight_per_request})
          end)
        end

      results = Task.await_many(tasks, 5000)

      # All requests should be rate limited
      assert Enum.all?(results, fn
               {:error, wait_time} when is_integer(wait_time) and wait_time > 0 -> true
               _ -> false
             end)
    end
  end

  describe "error cases" do
    test "handles zero weight requests", %{rate_limiter: limiter} do
      assert :ok = GenServer.call(limiter, {:check_rate_limit, 0})
    end

    test "handles negative weight requests", %{rate_limiter: limiter} do
      assert :ok = GenServer.call(limiter, {:check_rate_limit, -1})
    end

    test "handles large weight requests", %{rate_limiter: limiter, config: config} do
      assert {:error, _wait_time} =
               GenServer.call(limiter, {:check_rate_limit, config.default_weight_per_minute * 2})
    end
  end
end
