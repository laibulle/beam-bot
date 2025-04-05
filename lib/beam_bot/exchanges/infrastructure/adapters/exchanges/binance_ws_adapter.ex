defmodule BeamBot.Exchanges.Infrastructure.Adapters.BinanceWsAdapter do
  @moduledoc """
  WebSocket client for Binance USDⓈ-M Futures streams.
  Handles connection and message processing for market data streams.
  Each instance manages a single symbol's streams.
  """
  use WebSockex
  require Logger

  alias BeamBot.Exchanges.Domain.{Kline, MarkPriceUpdate, Trade.AggregateTrade}

  @klines_repository Application.compile_env(:beam_bot, :klines_repository)

  @base_url "wss://fstream.binance.com"
  # 5 seconds for reconnection, but faster for initial connection
  @reconnect_delay 5_000
  @initial_connect_delay 1_000

  def start_link(symbol, streams, state \\ %{}) when is_binary(symbol) and is_list(streams) do
    # Only log at debug level for initial connection to reduce startup noise
    Logger.debug(
      "Starting Binance WebSocket adapter for symbol #{symbol} with streams: #{inspect(streams)}"
    )

    url = build_url(symbol, streams)

    initial_state =
      Map.merge(state, %{
        symbol: symbol,
        streams: streams,
        connected: false,
        reconnect_count: 0,
        last_message_time: nil,
        is_initial_connection: true
      })

    name = via_tuple(symbol)
    WebSockex.start_link(url, __MODULE__, initial_state, name: name)
  end

  def via_tuple(symbol) do
    {:via, Registry, {BeamBot.Registry, {__MODULE__, symbol}}}
  end

  @doc """
  Handles incoming WebSocket frames
  """
  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, decoded_msg} ->
        Logger.debug("Received message for #{state.symbol}: #{inspect(decoded_msg)}")

        updated_state = %{
          state
          | connected: true,
            last_message_time: DateTime.utc_now()
        }

        handle_message(decoded_msg, updated_state)

      {:error, error} ->
        Logger.error("Failed to decode message for #{state.symbol}: #{inspect(error)}")
        {:ok, state}
    end
  end

  def handle_frame({:ping, _}, state) do
    Logger.debug("Received ping from Binance WebSocket server for #{state.symbol}")
    {:reply, :pong, state}
  end

  def handle_frame({:pong, _}, state) do
    Logger.debug("Received pong response from Binance WebSocket server for #{state.symbol}")
    {:ok, state}
  end

  @doc """
  Handle cast messages sent to the WebSocket process
  """
  def handle_cast(message, state) do
    Logger.debug("Received cast message for #{state.symbol}: #{inspect(message)}")
    {:ok, state}
  end

  @doc """
  Handle WebSocket connection established
  """
  def handle_connect(_conn, state) do
    Logger.debug("Connected to Binance WebSocket server for #{state.symbol}")
    state = maybe_resubscribe_to_streams(state)
    {:ok, %{state | connected: true}}
  end

  defp maybe_resubscribe_to_streams(%{reconnect_count: count, streams: streams} = state)
       when count > 0 and streams != [] do
    Logger.debug(
      "Resubscribing to streams after reconnection for #{state.symbol}: #{inspect(streams)}"
    )

    case subscribe(state.symbol, streams) do
      :ok ->
        Logger.debug("Successfully resubscribed to streams for #{state.symbol}")

      {:error, reason} ->
        Logger.error("Failed to resubscribe to streams for #{state.symbol}: #{inspect(reason)}")
    end

    state
  end

  defp maybe_resubscribe_to_streams(state), do: state

  @doc """
  Handle WebSocket disconnection
  """
  def handle_disconnect(%{reason: reason, conn: conn}, state) do
    reconnect_count = (state[:reconnect_count] || 0) + 1
    delay = if state[:is_initial_connection], do: @initial_connect_delay, else: @reconnect_delay

    Logger.warning(
      "Disconnected from Binance WebSocket server for #{state.symbol}. Reason: #{inspect(reason)}. Reconnecting in #{delay / 1000} seconds..."
    )

    {:reconnect, conn,
     %{state | connected: false, reconnect_count: reconnect_count, is_initial_connection: false}}
  end

  @doc """
  Handle WebSocket errors
  """
  def handle_info({:EXIT, _, reason}, state) do
    Logger.error("WebSockex process exited for #{state.symbol}: #{inspect(reason)}")
    {:ok, state}
  end

  @doc """
  Subscribe to additional streams after connection is established
  """
  def subscribe(symbol, streams) when is_binary(symbol) and is_list(streams) do
    subscription_msg = %{
      method: "SUBSCRIBE",
      params: Enum.map(streams, &"#{symbol.downcase}@#{&1}"),
      id: :os.system_time(:millisecond)
    }

    case WebSockex.send_frame(via_tuple(symbol), {:text, Jason.encode!(subscription_msg)}) do
      :ok ->
        Logger.debug("Successfully sent subscription message for #{symbol}")
        :ok

      {:error, %{__struct__: error_type} = error} ->
        Logger.error("Failed to subscribe #{symbol} to streams: #{inspect(error)}")
        {:error, error_type}
    end
  end

  @doc """
  Unsubscribe from streams
  """
  def unsubscribe(symbol, streams) when is_binary(symbol) and is_list(streams) do
    unsubscription_msg = %{
      method: "UNSUBSCRIBE",
      params: Enum.map(streams, &"#{symbol.downcase}@#{&1}"),
      id: :os.system_time(:millisecond)
    }

    case WebSockex.send_frame(via_tuple(symbol), {:text, Jason.encode!(unsubscription_msg)}) do
      :ok ->
        Logger.debug("Successfully sent unsubscription message for #{symbol}")
        :ok

      {:error, %{__struct__: error_type} = error} ->
        Logger.error("Failed to unsubscribe #{symbol} from streams: #{inspect(error)}")
        {:error, error_type}
    end
  end

  @doc """
  Ping the WebSocket server to check connectivity
  """
  def ping(symbol) when is_binary(symbol) do
    case WebSockex.send_frame(via_tuple(symbol), :ping) do
      :ok ->
        {:ok, "Connection is alive"}

      error ->
        {:error, "WebSocket connection error: #{inspect(error)}"}
    end
  end

  @doc """
  Check if the WebSocket process is alive
  """
  def alive?(symbol) when is_binary(symbol) do
    case Registry.lookup(BeamBot.Registry, {__MODULE__, symbol}) do
      [{pid, _}] -> Process.alive?(pid)
      [] -> false
    end
  end

  @doc """
  Get current connection status and details
  """
  def connection_status(symbol) when is_binary(symbol) do
    case alive?(symbol) do
      true ->
        [{pid, _}] = Registry.lookup(BeamBot.Registry, {__MODULE__, symbol})
        state = :sys.get_state(pid)

        %{
          status: if(state.connected, do: :connected, else: :connecting),
          symbol: state.symbol,
          pid: pid,
          connected: state.connected,
          reconnect_count: state.reconnect_count,
          last_message_time: state.last_message_time,
          registered_name: Process.info(pid, :registered_name),
          memory_usage: Process.info(pid, :memory),
          message_queue_len: Process.info(pid, :message_queue_len)
        }

      false ->
        %{status: :disconnected, symbol: symbol}
    end
  end

  @doc """
  Get the list of streams the WebSocket is currently subscribed to
  """
  def get_streams(symbol) when is_binary(symbol) do
    case alive?(symbol) do
      true ->
        [{pid, _}] = Registry.lookup(BeamBot.Registry, {__MODULE__, symbol})
        state = :sys.get_state(pid)
        {:ok, state.streams || []}

      false ->
        {:error, :disconnected}
    end
  end

  # Private functions

  defp build_url(symbol, streams) when is_binary(symbol) and is_list(streams) do
    streams_string = Enum.map_join(streams, "/", &"#{String.downcase(symbol)}@#{&1}")
    "#{@base_url}/stream?streams=#{streams_string}"
  end

  defp handle_message(%{"stream" => stream, "data" => data}, state) do
    # Broadcast the message to subscribers
    Logger.debug("Received data from stream #{stream} for #{state.symbol}: #{inspect(data)}")

    process_message(stream, data)

    {:ok, state}
  end

  defp handle_message(%{"result" => nil, "id" => id}, state) do
    # Handle subscription/unsubscription confirmations
    Logger.debug("Received confirmation for request ID #{id} for #{state.symbol}")
    {:ok, state}
  end

  defp process_message(stream, data) do
    cond do
      String.contains?(stream, "@aggTrade") ->
        handle_aggregate_trade(data)

      String.contains?(stream, "@markPrice") ->
        handle_mark_price(data)

      String.contains?(stream, "@kline_") ->
        handle_kline(data)

      true ->
        Logger.warning("Unhandled stream type: #{stream}")
        :error
    end
  end

  defp handle_aggregate_trade(data) do
    trade = AggregateTrade.from_binance(data)
    store_and_broadcast_trade(trade)
  end

  defp store_and_broadcast_trade(trade) do
    with {:ok, _} <- @klines_repository.store_klines([trade]),
         :ok <- broadcast_trade(trade) do
      :ok
    else
      {:error, error} ->
        Logger.error("Failed to store/broadcast trade for #{trade.symbol}: #{inspect(error)}")
        :error
    end
  end

  defp broadcast_trade(trade) do
    case Phoenix.PubSub.broadcast(BeamBot.PubSub, "binance:aggTrade:#{trade.symbol}", trade) do
      :ok ->
        :ok

      {:error, reason} = error ->
        Logger.error("Failed to broadcast trade for #{trade.symbol}: #{inspect(reason)}")
        error
    end
  end

  defp handle_mark_price(data) do
    mark_price = MarkPriceUpdate.from_binance(data)
    broadcast_mark_price(mark_price)
  end

  defp broadcast_mark_price(mark_price) do
    case Phoenix.PubSub.broadcast(
           BeamBot.PubSub,
           "binance:markPrice:#{mark_price.symbol}",
           mark_price
         ) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error(
          "Failed to broadcast mark price for #{mark_price.symbol}: #{inspect(reason)}"
        )

        :error
    end
  end

  defp handle_kline(data) do
    kline = create_kline_from_binance(data)
    store_and_broadcast_kline(kline)
  end

  defp store_and_broadcast_kline(kline) do
    with {:ok, _} <- @klines_repository.store_klines([kline]),
         :ok <- broadcast_kline(kline) do
      :ok
    else
      {:error, error} ->
        Logger.error("Failed to store/broadcast kline for #{kline.symbol}: #{inspect(error)}")
        :error
    end
  end

  defp broadcast_kline(kline) do
    case Phoenix.PubSub.broadcast(BeamBot.PubSub, "binance:kline:#{kline.symbol}", kline) do
      :ok ->
        :ok

      {:error, reason} = error ->
        Logger.error("Failed to broadcast kline for #{kline.symbol}: #{inspect(reason)}")
        error
    end
  end

  defp create_kline_from_binance(%{"k" => kline_data, "s" => symbol}) do
    %Kline{
      symbol: symbol,
      platform: "binance",
      interval: kline_data["i"],
      timestamp: DateTime.from_unix!(div(kline_data["t"], 1000), :second),
      open: Decimal.new(kline_data["o"]),
      high: Decimal.new(kline_data["h"]),
      low: Decimal.new(kline_data["l"]),
      close: Decimal.new(kline_data["c"]),
      volume: Decimal.new(kline_data["v"]),
      quote_volume: Decimal.new(kline_data["q"]),
      trades_count: kline_data["n"],
      taker_buy_base_volume: Decimal.new(kline_data["V"]),
      taker_buy_quote_volume: Decimal.new(kline_data["Q"]),
      ignore: Decimal.new(kline_data["B"])
    }
  end
end
