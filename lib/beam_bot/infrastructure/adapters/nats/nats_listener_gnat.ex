defmodule BeamBot.Infrastructure.Adapters.Nats.NatsListenerGnat do
  @moduledoc """
  NATS adapter implementation using Gnat.
  """
  @behaviour BeamBot.Domain.Ports.NatsListener

  use GenServer

  @impl true
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    connection_name = Keyword.get(opts, :connection_name, :default)
    connection_settings = Keyword.get(opts, :connection_settings, %{})

    case Gnat.start_link(connection_settings, name: connection_name) do
      {:ok, _pid} -> {:ok, %{connection_name: connection_name}}
      error -> error
    end
  end

  @impl true
  def subscribe(subject, callback) do
    GenServer.call(__MODULE__, {:subscribe, subject, callback})
  end

  @impl true
  def publish(subject, message) do
    GenServer.call(__MODULE__, {:publish, subject, message})
  end

  @impl true
  def handle_call({:subscribe, subject, callback}, _from, state) do
    case Gnat.sub(state.connection_name, self(), subject) do
      {:ok, _subscription} ->
        Process.flag(:trap_exit, true)
        {:reply, :ok, Map.put(state, :callback, callback)}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:publish, subject, message}, _from, state) do
    result = Gnat.pub(state.connection_name, subject, Jason.encode!(message))
    {:reply, result, state}
  end

  @impl true
  def handle_info({:msg, %{body: body} = _message}, %{callback: callback} = state) do
    case Jason.decode(body) do
      {:ok, decoded} -> callback.(%{body: decoded})
      {:error, _} -> :ok
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:EXIT, _pid, _reason}, state) do
    {:noreply, state}
  end
end
