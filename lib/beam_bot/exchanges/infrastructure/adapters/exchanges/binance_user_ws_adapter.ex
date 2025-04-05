defmodule BeamBot.Exchanges.Infrastructure.Adapters.BinanceUserWsAdapter do
  @moduledoc """
  WebSocket client for Binance USDⓈ-M Futures user data streams.
  Handles connection and message processing for user-specific data like account updates.
  Each instance manages a single user's data stream.
  """
  use WebSockex
  require Logger

  alias BeamBot.Exchanges.Domain.PlatformCredentials

  @base_url "wss://fstream.binance.com"
  @api_base_url "https://fapi.binance.com"
  # 5 seconds for reconnection, but faster for initial connection
  @reconnect_delay 5_000
  @initial_connect_delay 1_000
  # Listen key validity period (less than 60 minutes to be safe)
  @listen_key_refresh_interval 45 * 60 * 1000

  def start_link(%PlatformCredentials{} = credentials, state \\ %{}) do
    Logger.debug("Starting Binance user data WebSocket adapter")

    # Get initial listen key
    case get_listen_key(credentials) do
      {:ok, listen_key} ->
        url = build_url(listen_key)

        initial_state =
          Map.merge(state, %{
            credentials: credentials,
            listen_key: listen_key,
            connected: false,
            reconnect_count: 0,
            last_message_time: nil,
            is_initial_connection: true
          })

        # Schedule listen key refresh
        schedule_listen_key_refresh()

        name = via_tuple(credentials.user_id)
        WebSockex.start_link(url, __MODULE__, initial_state, name: name)

      {:error, reason} ->
        Logger.error("Failed to get listen key: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def via_tuple(user_id) do
    {:via, Registry, {BeamBot.Registry, {__MODULE__, user_id}}}
  end

  @doc """
  Handles incoming WebSocket frames
  """
  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, decoded_msg} ->
        Logger.debug("Received user data message: #{inspect(decoded_msg)}")

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
  Handle cast messages sent to the WebSocket process
  """
  def handle_cast(message, state) do
    Logger.debug(
      "Received cast message for user #{state.credentials.user_id}: #{inspect(message)}"
    )

    {:ok, state}
  end

  @doc """
  Handle WebSocket connection established
  """
  def handle_connect(_conn, state) do
    Logger.debug("Connected to Binance WebSocket server for user data stream")
    {:ok, %{state | connected: true}}
  end

  @doc """
  Handle WebSocket disconnection
  """
  def handle_disconnect(%{reason: reason, conn: conn}, state) do
    reconnect_count = (state[:reconnect_count] || 0) + 1
    delay = if state[:is_initial_connection], do: @initial_connect_delay, else: @reconnect_delay

    Logger.warning(
      "Disconnected from Binance WebSocket server. Reason: #{inspect(reason)}. Reconnecting in #{delay / 1000} seconds..."
    )

    {:reconnect, conn,
     %{state | connected: false, reconnect_count: reconnect_count, is_initial_connection: false}}
  end

  def handle_info({:EXIT, _, reason}, state) do
    Logger.error("WebSockex process exited: #{inspect(reason)}")
    {:ok, state}
  end

  def handle_info(:refresh_listen_key, state) do
    case refresh_listen_key(state.credentials, state.listen_key) do
      {:ok, _} ->
        schedule_listen_key_refresh()
        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to refresh listen key: #{inspect(reason)}")
        {:ok, state}
    end
  end

  @doc """
  Check if the WebSocket process is alive
  """
  def alive?(user_id) when is_integer(user_id) do
    case Registry.lookup(BeamBot.Registry, {__MODULE__, user_id}) do
      [{pid, _}] -> Process.alive?(pid)
      [] -> false
    end
  end

  @doc """
  Get current connection status and details
  """
  def connection_status(user_id) when is_integer(user_id) do
    case alive?(user_id) do
      true ->
        [{pid, _}] = Registry.lookup(BeamBot.Registry, {__MODULE__, user_id})
        state = :sys.get_state(pid)

        %{
          status: if(state.connected, do: :connected, else: :connecting),
          user_id: user_id,
          pid: pid,
          connected: state.connected,
          reconnect_count: state.reconnect_count,
          last_message_time: state.last_message_time,
          registered_name: Process.info(pid, :registered_name),
          memory_usage: Process.info(pid, :memory),
          message_queue_len: Process.info(pid, :message_queue_len)
        }

      false ->
        %{status: :disconnected, user_id: user_id}
    end
  end

  # Private functions

  defp build_url(listen_key) do
    "#{@base_url}/ws/#{listen_key}"
  end

  defp get_listen_key(%PlatformCredentials{api_key: api_key}) do
    url = "#{@api_base_url}/fapi/v1/listenKey"
    headers = [{"X-MBX-APIKEY", api_key}]

    case Req.post!(url, headers: headers) do
      %Req.Response{status: status, body: body} when status in 200..299 ->
        {:ok, body["listenKey"]}

      response ->
        Logger.error("Failed to get listen key: #{inspect(response)}")
        {:error, "Failed to get listen key"}
    end
  end

  defp refresh_listen_key(%PlatformCredentials{api_key: api_key}, listen_key) do
    url = "#{@api_base_url}/fapi/v1/listenKey"
    headers = [{"X-MBX-APIKEY", api_key}]

    case Req.put!(url, headers: headers) do
      %Req.Response{status: status} when status in 200..299 ->
        Logger.debug("Successfully refreshed listen key: #{listen_key}")
        {:ok, listen_key}

      response ->
        Logger.error("Failed to refresh listen key: #{inspect(response)}")
        {:error, "Failed to refresh listen key"}
    end
  end

  defp schedule_listen_key_refresh do
    Process.send_after(self(), :refresh_listen_key, @listen_key_refresh_interval)
  end

  defp handle_message(%{"e" => "ACCOUNT_UPDATE"} = msg, state) do
    # Extract balance updates
    balances =
      for balance <- msg["a"]["B"] do
        %{
          asset: balance["a"],
          wallet_balance: Decimal.new(balance["wb"]),
          cross_wallet_balance: Decimal.new(balance["cw"]),
          balance_change: Decimal.new(balance["bc"])
        }
      end

    # Broadcast balance updates
    case Phoenix.PubSub.broadcast(
           BeamBot.PubSub,
           "binance:account:#{state.credentials.user_id}",
           {:balance_update, balances}
         ) do
      :ok ->
        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to broadcast balance update: #{inspect(reason)}")
        {:ok, state}
    end
  end

  defp handle_message(%{"e" => "ORDER_TRADE_UPDATE"} = msg, state) do
    # Broadcast order updates
    case Phoenix.PubSub.broadcast(
           BeamBot.PubSub,
           "binance:account:#{state.credentials.user_id}",
           {:order_update, msg["o"]}
         ) do
      :ok ->
        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to broadcast order update: #{inspect(reason)}")
        {:ok, state}
    end
  end

  defp handle_message(msg, state) do
    Logger.warning("Unhandled user data message type: #{inspect(msg)}")
    {:ok, state}
  end
end
