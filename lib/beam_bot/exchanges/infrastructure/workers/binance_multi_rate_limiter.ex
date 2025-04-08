defmodule BeamBot.Exchanges.Infrastructure.Workers.BinanceMultiRateLimiter do
  @moduledoc """
  A GenServer that implements multiple rate limiting strategies for Binance API requests.
  Rate limits are based on fixed intervals that reset at specific times:
  1. REQUEST_WEIGHT - Weight-based limits that reset every minute (at XX:XX:00)
  2. ORDERS - Order count limits that reset:
     - Every second (at XX:XX:XX.000)
     - Every day (at 00:00:00 UTC)
  3. RAW_REQUESTS - Raw request count limits that reset every 5 minutes (at XX:X0:00, XX:X5:00, etc)
  """
  use GenServer
  require Logger

  # Get configuration values with defaults
  @weight_limit_per_minute 6000
  @orders_per_second 100
  @orders_per_day 200_000
  @raw_requests_per_5min 61_000

  # Interval durations in milliseconds
  @minute_interval 60_000
  @second_interval 1_000
  @five_min_interval 300_000

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Checks if a request with the given weight can be made.
  Returns :ok if the request is allowed, or {:error, wait_time} if rate limited.
  """
  def check_weight_limit(weight \\ 1) do
    GenServer.call(__MODULE__, {:check_weight_limit, weight})
  end

  @doc """
  Checks if an order can be placed.
  Returns :ok if the order is allowed, or {:error, wait_time} if rate limited.
  """
  def check_order_limit do
    GenServer.call(__MODULE__, :check_order_limit)
  end

  @doc """
  Checks if a raw request can be made.
  Returns :ok if the request is allowed, or {:error, wait_time} if rate limited.
  """
  def check_raw_request_limit do
    GenServer.call(__MODULE__, :check_raw_request_limit)
  end

  @doc """
  Records that a request was made with the given weight.
  """
  def record_weight_request(weight \\ 1) do
    GenServer.cast(__MODULE__, {:record_weight_request, weight})
  end

  @doc """
  Records that an order was placed.
  """
  def record_order do
    GenServer.cast(__MODULE__, :record_order)
  end

  @doc """
  Records that a raw request was made.
  """
  def record_raw_request do
    GenServer.cast(__MODULE__, :record_raw_request)
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
    now = :os.system_time(:millisecond)

    {:ok,
     %{
       # Weight-based requests for current minute
       current_minute_start: get_current_interval_start(now, @minute_interval),
       current_minute_weight: 0,

       # Order requests for current second
       current_second_start: get_current_interval_start(now, @second_interval),
       current_second_orders: 0,

       # Order requests for current day (UTC)
       current_day_start: get_current_day_start(now),
       current_day_orders: 0,

       # Raw requests for current 5-minute interval
       current_5min_start: get_current_interval_start(now, @five_min_interval),
       current_5min_requests: 0
     }}
  end

  @impl true
  def handle_call({:check_weight_limit, weight}, _from, state) when weight <= 0 do
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:check_weight_limit, weight}, _from, state) do
    now = :os.system_time(:millisecond)
    interval_start = get_current_interval_start(now, @minute_interval)

    # Reset counter if we're in a new interval
    state =
      if interval_start > state.current_minute_start do
        %{state | current_minute_start: interval_start, current_minute_weight: 0}
      else
        state
      end

    if state.current_minute_weight + weight <= @weight_limit_per_minute do
      new_state = %{state | current_minute_weight: state.current_minute_weight + weight}
      {:reply, :ok, new_state}
    else
      # Calculate wait time until next interval
      wait_time = state.current_minute_start + @minute_interval - now
      {:reply, {:error, wait_time}, state}
    end
  end

  @impl true
  def handle_call(:check_order_limit, _from, state) do
    now = :os.system_time(:millisecond)
    second_start = get_current_interval_start(now, @second_interval)
    day_start = get_current_day_start(now)

    # Reset counters if we're in new intervals
    state =
      state
      |> maybe_reset_second_orders(second_start)
      |> maybe_reset_day_orders(day_start)

    cond do
      state.current_second_orders >= @orders_per_second ->
        wait_time = state.current_second_start + @second_interval - now
        {:reply, {:error, wait_time}, state}

      state.current_day_orders >= @orders_per_day ->
        wait_time = state.current_day_start + 86_400_000 - now
        {:reply, {:error, wait_time}, state}

      true ->
        new_state = %{
          state
          | current_second_orders: state.current_second_orders + 1,
            current_day_orders: state.current_day_orders + 1
        }

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:check_raw_request_limit, _from, state) do
    now = :os.system_time(:millisecond)
    interval_start = get_current_interval_start(now, @five_min_interval)

    # Reset counter if we're in a new interval
    state =
      if interval_start > state.current_5min_start do
        %{state | current_5min_start: interval_start, current_5min_requests: 0}
      else
        state
      end

    if state.current_5min_requests + 1 <= @raw_requests_per_5min do
      new_state = %{state | current_5min_requests: state.current_5min_requests + 1}
      {:reply, :ok, new_state}
    else
      # Calculate wait time until next interval
      wait_time = state.current_5min_start + @five_min_interval - now
      {:reply, {:error, wait_time}, state}
    end
  end

  @impl true
  def handle_cast({:record_weight_request, weight}, state) when weight <= 0 do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:record_weight_request, weight}, state) do
    now = :os.system_time(:millisecond)
    interval_start = get_current_interval_start(now, @minute_interval)

    # Reset counter if we're in a new interval
    state =
      if interval_start > state.current_minute_start do
        %{state | current_minute_start: interval_start, current_minute_weight: 0}
      else
        state
      end

    {:noreply, %{state | current_minute_weight: state.current_minute_weight + weight}}
  end

  @impl true
  def handle_cast(:record_order, state) do
    now = :os.system_time(:millisecond)
    second_start = get_current_interval_start(now, @second_interval)
    day_start = get_current_day_start(now)

    # Reset counters if we're in new intervals
    state =
      state
      |> maybe_reset_second_orders(second_start)
      |> maybe_reset_day_orders(day_start)

    new_state = %{
      state
      | current_second_orders: state.current_second_orders + 1,
        current_day_orders: state.current_day_orders + 1
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:record_raw_request, state) do
    now = :os.system_time(:millisecond)
    interval_start = get_current_interval_start(now, @five_min_interval)

    # Reset counter if we're in a new interval
    state =
      if interval_start > state.current_5min_start do
        %{state | current_5min_start: interval_start, current_5min_requests: 0}
      else
        state
      end

    {:noreply, %{state | current_5min_requests: state.current_5min_requests + 1}}
  end

  # Helper functions for interval calculations

  defp get_current_interval_start(timestamp_ms, interval_ms) do
    # Round down to the nearest interval
    div(timestamp_ms, interval_ms) * interval_ms
  end

  defp get_current_day_start(timestamp_ms) do
    # Convert to UTC seconds, round down to day boundary, convert back to milliseconds
    timestamp_ms
    # to seconds
    |> div(1000)
    # to days
    |> div(86_400)
    # back to seconds at day boundary
    |> Kernel.*(86_400)
    # back to milliseconds
    |> Kernel.*(1000)
  end

  defp maybe_reset_second_orders(state, new_second_start) do
    if new_second_start > state.current_second_start do
      %{state | current_second_start: new_second_start, current_second_orders: 0}
    else
      state
    end
  end

  defp maybe_reset_day_orders(state, new_day_start) do
    if new_day_start > state.current_day_start do
      %{state | current_day_start: new_day_start, current_day_orders: 0}
    else
      state
    end
  end
end
