defmodule BeamBot.Infrastructure.RedisClient do
  @moduledoc """
  Redis client module for handling Redis connections and TimeSeries operations.
  """

  use GenServer
  require Logger

  @redis_url Application.compile_env(:beam_bot, :redis_url, "redis://localhost:6379")

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_state) do
    {:ok, conn} = Redix.start_link(@redis_url)
    {:ok, %{conn: conn}}
  end

  @impl true
  def handle_call({:ts_add, key, timestamp, value}, _from, %{conn: conn} = state) do
    result = Redix.command(conn, ["TS.ADD", key, timestamp, value])
    {:reply, result, state}
  end

  def handle_call({:ts_get, key}, _from, %{conn: conn} = state) do
    result = Redix.command(conn, ["TS.GET", key])
    {:reply, result, state}
  end

  def handle_call({:keys, pattern}, _from, %{conn: conn} = state) do
    result = Redix.command(conn, ["KEYS", pattern])
    {:reply, result, state}
  end

  # Public API

  def ts_add(key, timestamp, value) do
    GenServer.call(__MODULE__, {:ts_add, key, timestamp, value})
  end

  def ts_get(key) do
    GenServer.call(__MODULE__, {:ts_get, key})
  end

  def keys(pattern) do
    GenServer.call(__MODULE__, {:keys, pattern})
  end
end
