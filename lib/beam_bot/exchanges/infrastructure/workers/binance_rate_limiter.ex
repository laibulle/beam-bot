defmodule BeamBot.Exchanges.Infrastructure.Workers.BinanceRateLimiter do
  @moduledoc """
  A GenServer that implements rate limiting for Binance API requests.
  It uses a sliding window approach to track request timestamps and enforces rate limits.
  """
  use GenServer
  require Logger

  # Get configuration values with defaults
  @window_size Application.compile_env!(:beam_bot, :binance_rate_limiter)[:window_size]
  @cleanup_interval Application.compile_env!(:beam_bot, :binance_rate_limiter)[:cleanup_interval]
  @default_weight_per_minute Application.compile_env!(:beam_bot, :binance_rate_limiter)[
                               :default_weight_per_minute
                             ]

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Checks if a request with the given weight can be made.
  Returns :ok if the request is allowed, or {:error, wait_time} if rate limited.
  """
  def check_rate_limit(weight \\ 1) do
    GenServer.call(__MODULE__, {:check_rate_limit, weight})
  end

  @doc """
  Records that a request was made with the given weight.
  """
  def record_request(weight \\ 1) do
    GenServer.cast(__MODULE__, {:record_request, weight})
  end

  @doc """
  Returns the current configuration values.
  Useful for testing and verification.
  """
  def get_config do
    %{
      window_size: @window_size,
      cleanup_interval: @cleanup_interval,
      default_weight_per_minute: @default_weight_per_minute
    }
  end

  @doc """
  Computes the weight for a given limit value based on Binance's order book depth rules.
  Returns the corresponding weight value.

  ## Examples

      iex> compute_weight(5)
      1
      iex> compute_weight(500)
      5
      iex> compute_weight(5000)
      50

  """
  def compute_weight(limit) when limit in 1..100, do: 1
  def compute_weight(limit) when limit in 101..500, do: 5
  def compute_weight(limit) when limit in 501..1000, do: 10
  def compute_weight(limit) when limit in 1001..5000, do: 50

  def compute_weight(_),
    do:
      raise(
        ArgumentError,
        "Invalid limit value. Allowed values are between 1 and 5000"
      )

  @impl true
  def init(_opts) do
    # Schedule the first cleanup
    schedule_cleanup()

    {:ok,
     %{
       # List of {timestamp, weight} tuples, sorted by timestamp (newest first)
       requests: [],
       total_weight: 0,
       last_cleanup: :os.system_time(:millisecond),
       # Lock to prevent concurrent access issues
       locked: false
     }}
  end

  @impl true
  def handle_call({:check_rate_limit, weight}, _from, state) when weight <= 0 do
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:check_rate_limit, weight}, _from, state) do
    now = :os.system_time(:millisecond)
    window_start = now - @window_size

    # Clean up old requests first
    state = cleanup_requests(state, window_start)

    # Check if adding this weight would exceed the limit
    if state.total_weight + weight <= @default_weight_per_minute do
      # Record the request immediately when we check it
      new_requests = [{now, weight} | state.requests]
      new_total = state.total_weight + weight
      {:reply, :ok, %{state | requests: new_requests, total_weight: new_total}}
    else
      # Calculate wait time until enough weight frees up
      wait_time = calculate_wait_time(state.requests, weight, window_start)
      {:reply, {:error, wait_time}, state}
    end
  end

  @impl true
  def handle_cast({:record_request, weight}, state) when weight <= 0 do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:record_request, weight}, state) do
    now = :os.system_time(:millisecond)
    window_start = now - @window_size

    # Clean up old requests first
    state = cleanup_requests(state, window_start)

    # Add new request to the front of the list (newest first)
    new_requests = [{now, weight} | state.requests]
    new_total = state.total_weight + weight

    {:noreply, %{state | requests: new_requests, total_weight: new_total}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = :os.system_time(:millisecond)
    window_start = now - @window_size

    # Clean up old requests
    state = cleanup_requests(state, window_start)

    # Schedule next cleanup
    schedule_cleanup()

    {:noreply, state}
  end

  defp cleanup_requests(state, window_start) do
    # Since requests are stored newest first, we can stop at the first request within the window
    {current, removed} = Enum.split_while(state.requests, fn {ts, _} -> ts >= window_start end)

    removed_weight = Enum.reduce(removed, 0, fn {_ts, weight}, acc -> acc + weight end)
    current_weight = state.total_weight - removed_weight

    %{
      state
      | requests: current,
        total_weight: current_weight,
        last_cleanup: :os.system_time(:millisecond)
    }
  end

  defp calculate_wait_time(requests, new_weight, window_start) do
    now = :os.system_time(:millisecond)

    # Since requests are stored newest first, we need to reverse them to process oldest first
    sorted_requests = Enum.reverse(requests)

    # Find how long we need to wait for enough weight to free up
    {wait_time, _} =
      calculate_wait_time_for_requests(sorted_requests, new_weight, window_start, now)

    # If we have no requests in the window, wait for the full window
    if wait_time == 0 and length(requests) > 0 do
      @window_size
    else
      # Ensure we always return a positive wait time when rate limiting
      max(1, wait_time)
    end
  end

  defp calculate_wait_time_for_requests(requests, new_weight, window_start, now) do
    Enum.reduce_while(requests, {0, @default_weight_per_minute}, fn {ts, weight},
                                                                    {_wait, remaining_capacity} ->
      if ts < window_start do
        # This request is outside the window, skip it
        {:cont, {0, remaining_capacity}}
      else
        handle_request_in_window(ts, weight, new_weight, remaining_capacity, now)
      end
    end)
  end

  defp handle_request_in_window(ts, weight, new_weight, remaining_capacity, now) do
    new_remaining = remaining_capacity - weight
    next_wait = ts + @window_size - now

    if new_remaining >= new_weight do
      # We have enough capacity, but we need to wait for the window to slide
      {:halt, {next_wait, new_remaining}}
    else
      # Not enough capacity, continue checking older requests
      {:cont, {next_wait, new_remaining}}
    end
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
end
