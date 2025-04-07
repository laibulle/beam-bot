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
        spawn_link(fn -> handle_messages(callback) end)
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:publish, subject, message}, _from, state) do
    result = Gnat.pub(state.connection_name, subject, Jason.encode!(message))
    {:reply, result, state}
  end

  defp handle_messages(callback) do
    receive do
      {:msg, %{body: body}} ->
        case Jason.decode(body) do
          {:ok, decoded} -> callback.(decoded)
          {:error, _} -> :ok
        end

        handle_messages(callback)

      {:EXIT, _pid, _reason} ->
        :ok
    end
  end
end
