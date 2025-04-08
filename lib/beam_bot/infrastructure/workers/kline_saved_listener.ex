defmodule BeamBot.Infrastructure.Workers.KlineSavedListener do
  @moduledoc """
  Worker that listens for kline:saved events and processes them.
  """
  use GenServer

  alias BeamBot.Infrastructure.Adapters.Nats.NatsListenerGnat

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Subscribe to kline:saved events
    case NatsListenerGnat.subscribe("klines:initialized", &handle_nats_message/1) do
      :ok -> {:ok, %{}}
      error -> {:stop, error}
    end
  end

  defp handle_nats_message(%{body: body} = _message) do
    Logger.info("Received klines data: #{inspect(body)}")
    :ok
  end
end
