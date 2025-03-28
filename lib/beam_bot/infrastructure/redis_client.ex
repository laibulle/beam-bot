defmodule BeamBot.Infrastructure.RedisClient do
  @moduledoc """
  Redis client module for handling Redis connections and operations.
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
  def handle_call({:set, key, value}, _from, %{conn: conn} = state) do
    result = Redix.command(conn, ["SET", key, value])
    {:reply, result, state}
  end

  def handle_call({:get, key}, _from, %{conn: conn} = state) do
    result = Redix.command(conn, ["GET", key])
    {:reply, result, state}
  end

  def handle_call({:keys, pattern}, _from, %{conn: conn} = state) do
    result = Redix.command(conn, ["KEYS", pattern])
    {:reply, result, state}
  end

  def handle_call({:del, key}, _from, %{conn: conn} = state) do
    result = Redix.command(conn, ["DEL", key])
    {:reply, result, state}
  end

  # Public API

  def set(key, value) do
    GenServer.call(__MODULE__, {:set, key, value})
  end

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def keys(pattern) do
    GenServer.call(__MODULE__, {:keys, pattern})
  end

  def del(key) do
    GenServer.call(__MODULE__, {:del, key})
  end
end
