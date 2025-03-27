defmodule BeamBot.Exchanges.Infrastructure.Adapters.BinanceWsAdapter do
  @moduledoc """
  WebSocket client for Binance USDⓈ-M Futures streams.
  Handles connection and message processing for market data streams.
  """
  use WebSockex
  require Logger

  @base_url "wss://fstream.binance.com"

  def start_link(streams, state \\ %{}) when is_list(streams) do
    Logger.info("Starting Binance WebSocket adapter with streams: #{inspect(streams)}")
    url = build_url(streams)
    WebSockex.start_link(url, __MODULE__, state, name: __MODULE__)
  end

  @doc """
  Handles incoming WebSocket frames
  """
  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, decoded_msg} ->
        Logger.debug("Received message: #{inspect(decoded_msg)}")
        handle_message(decoded_msg, state)

      {:error, error} ->
        Logger.error("Failed to decode message: #{inspect(error)}")
    end

    {:ok, state}
  end

  def handle_frame({:ping, _}, state) do
    {:reply, :pong, state}
  end

  @doc """
  Subscribe to additional streams after connection is established
  """
  def subscribe(streams) when is_list(streams) do
    subscription_msg = %{
      method: "SUBSCRIBE",
      params: streams,
      id: :os.system_time(:millisecond)
    }

    WebSockex.send_frame(__MODULE__, {:text, Jason.encode!(subscription_msg)})
  end

  @doc """
  Unsubscribe from streams
  """
  def unsubscribe(streams) when is_list(streams) do
    unsubscription_msg = %{
      method: "UNSUBSCRIBE",
      params: streams,
      id: :os.system_time(:millisecond)
    }

    WebSockex.send_frame(__MODULE__, {:text, Jason.encode!(unsubscription_msg)})
  end

  # Private functions

  defp build_url([]) do
    "#{@base_url}/ws"
  end

  defp build_url(streams) when is_list(streams) do
    streams_string = Enum.join(streams, "/")
    "#{@base_url}/stream?streams=#{streams_string}"
  end

  defp handle_message(%{"stream" => stream, "data" => data}, state) do
    # Handle different stream types here
    # You can pattern match on the stream name and process accordingly
    Logger.info("Received data from stream #{stream}: #{inspect(data)}")
    {:ok, state}
  end

  defp handle_message(message, state) do
    Logger.info("Received message: #{inspect(message)}")
    {:ok, state}
  end
end
