defmodule BeamBot.Infrastructure.Workers.TradingPairsUpdatedListener do
  @moduledoc """
  Worker that listens for trading_pairs:updated events and processes them.
  """
  use GenServer

  alias BeamBot.Infrastructure.Adapters.Nats.NatsListenerGnat

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Subscribe to trading_pairs:updated events
    case NatsListenerGnat.subscribe("trading_pairs:updated", &handle_nats_message/1) do
      :ok -> {:ok, %{}}
      error -> {:stop, error}
    end
  end

  defp handle_nats_message(%{body: body} = _message) do
    Logger.info("Received trading pair update: #{inspect(body)}")
    :ok
  end
end
