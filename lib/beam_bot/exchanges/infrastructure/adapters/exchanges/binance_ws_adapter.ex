defmodule BeamBot.Exchanges.Infrastructure.Adapters.BinanceWsAdapter do
  @moduledoc """
  WebSocket client for Binance USDⓈ-M Futures streams.
  Handles connection and message processing for market data streams.
  """
  use WebSockex
  require Logger

  @base_url "wss://fstream.binance.com"
  # 5 seconds
  @reconnect_delay 5_000

  def start_link(streams, state \\ %{}) when is_list(streams) do
    Logger.info("Starting Binance WebSocket adapter with streams: #{inspect(streams)}")
    url = build_url(streams)

    initial_state =
      Map.merge(state, %{
        streams: streams,
        connected: false,
        reconnect_count: 0,
        last_message_time: nil
      })

    WebSockex.start_link(url, __MODULE__, initial_state, name: __MODULE__)
  end

  @doc """
  Handles incoming WebSocket frames
  """
  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, decoded_msg} ->
        Logger.debug("Received message: #{inspect(decoded_msg)}")

        updated_state = %{
          state
          | connected: true,
            last_message_time: DateTime.utc_now()
        }

        handle_message(decoded_msg, updated_state)

      {:error, error} ->
        Logger.error("Failed to decode message: #{inspect(error)}")
        {:ok, state}
    end
  end

  def handle_frame({:ping, _}, state) do
    Logger.debug("Received ping from Binance WebSocket server")
    {:reply, :pong, state}
  end

  def handle_frame({:pong, _}, state) do
    Logger.debug("Received pong response from Binance WebSocket server")
    {:ok, state}
  end

  @doc """
  Handle WebSocket connection established
  """
  def handle_connect(_conn, state) do
    Logger.info("Connected to Binance WebSocket server")

    # For reconnections, resubscribe to streams
    if state[:reconnect_count] > 0 do
      streams = state[:streams] || []

      if streams != [] do
        Logger.info("Resubscribing to streams after reconnection: #{inspect(streams)}")
        subscribe(streams)
      end
    end

    {:ok, %{state | connected: true}}
  end

  @doc """
  Handle WebSocket disconnection
  """
  def handle_disconnect(%{reason: reason}, state) do
    reconnect_count = (state[:reconnect_count] || 0) + 1

    Logger.warning(
      "Disconnected from Binance WebSocket server: #{inspect(reason)}. Reconnect attempt #{reconnect_count}"
    )

    # Reconnect with a delay
    Process.sleep(@reconnect_delay)

    {:reconnect, %{state | connected: false, reconnect_count: reconnect_count}}
  end

  @doc """
  Handle WebSocket errors
  """
  def handle_info({:EXIT, _, reason}, state) do
    Logger.error("WebSockex process exited: #{inspect(reason)}")
    {:ok, state}
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

  @doc """
  Ping the WebSocket server to check connectivity
  """
  def ping do
    case WebSockex.send_frame(__MODULE__, :ping) do
      :ok ->
        {:ok, "Connection is alive"}

      error ->
        {:error, "WebSocket connection error: #{inspect(error)}"}
    end
  end

  @doc """
  Check if the WebSocket process is alive
  """
  def alive? do
    case Process.whereis(__MODULE__) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end

  @doc """
  Get current connection status and details
  """
  def connection_status do
    case alive?() do
      true ->
        pid = Process.whereis(__MODULE__)
        state = :sys.get_state(pid)

        %{
          status: if(state.connected, do: :connected, else: :connecting),
          pid: pid,
          connected: state.connected,
          reconnect_count: state.reconnect_count,
          last_message_time: state.last_message_time,
          registered_name: Process.info(pid, :registered_name),
          memory_usage: Process.info(pid, :memory),
          message_queue_len: Process.info(pid, :message_queue_len)
        }

      false ->
        %{status: :disconnected}
    end
  end

  @doc """
  Get the list of streams the WebSocket is currently subscribed to
  """
  def get_streams do
    case alive?() do
      true ->
        pid = Process.whereis(__MODULE__)
        state = :sys.get_state(pid)
        {:ok, state.streams || []}

      false ->
        {:error, :disconnected}
    end
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
    # Broadcast the message to subscribers
    Logger.info("Received data from stream #{stream}: #{inspect(data)}")
    Phoenix.PubSub.broadcast(BeamBot.PubSub, "binance:#{stream}", {:binance_data, stream, data})
    {:ok, state}
  end

  defp handle_message(%{"result" => nil, "id" => id}, state) do
    # Handle subscription/unsubscription confirmations
    Logger.info("Received confirmation for request ID #{id}")
    {:ok, state}
  end

  defp handle_message(message, state) do
    # Handle other message types (like subscription responses)
    Logger.info("Received message: #{inspect(message)}")
    {:ok, state}
  end
end
