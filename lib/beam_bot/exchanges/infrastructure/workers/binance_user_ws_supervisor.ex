defmodule BeamBot.Exchanges.Infrastructure.Workers.BinanceUserWsSupervisor do
  @moduledoc """
  Supervisor for managing Binance user data WebSocket connections.
  Each user gets their own WebSocket connection managed by this supervisor.
  """
  use Supervisor
  require Logger

  alias BeamBot.Exchanges.Infrastructure.Adapters.BinanceUserWsAdapter

  @platform_credentials_repository Application.compile_env(
                                     :beam_bot,
                                     :platform_credentials_repository
                                   )

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Custom start function that returns the already started pid.
  This is used to supervise pre-started processes.
  """
  def start_child(pid) when is_pid(pid), do: {:ok, pid}

  @impl true
  def init(state) do
    # Get all active platform credentials
    {:ok, credentials} =
      @platform_credentials_repository.get_by_user_id_and_exchange_id(state.user_id, "binance")

    Logger.debug(
      "Starting Binance user data WebSocket supervisor with #{length(credentials)} active users"
    )

    # Clean up any existing processes
    Enum.each(credentials, fn cred ->
      case Registry.lookup(BeamBot.Registry, {BinanceUserWsAdapter, cred.user_id}) do
        [{pid, _}] ->
          Logger.debug("Found existing process for user #{cred.user_id}, terminating it")
          Process.exit(pid, :normal)

        [] ->
          :ok
      end
    end)

    # Start children concurrently using Task.async_stream
    children =
      credentials
      |> Task.async_stream(
        fn cred ->
          # Start the child process directly
          {:ok, pid} = BinanceUserWsAdapter.start_link(cred)
          # Return the child spec with the already started pid
          %{
            id: {:binance_user_ws, cred.user_id},
            start: {__MODULE__, :start_child, [pid]},
            restart: :permanent,
            type: :worker
          }
        end,
        max_concurrency: 10,
        ordered: false
      )
      |> Enum.map(fn {:ok, child} -> child end)

    # Use one_for_one strategy to handle failures independently
    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end

  @doc """
  Start a new user data WebSocket connection for a user.
  """
  def start_user_connection(user_id) when is_integer(user_id) do
    with {:ok, credentials} <-
           @platform_credentials_repository.get_by_user_id_and_exchange_id(user_id, "binance"),
         {:ok, pid} <- BinanceUserWsAdapter.start_link(credentials) do
      child_spec = %{
        id: {:binance_user_ws, user_id},
        start: {__MODULE__, :start_child, [pid]},
        restart: :permanent,
        type: :worker
      }

      Supervisor.start_child(__MODULE__, child_spec)
    end
  end

  @doc """
  Stop a user data WebSocket connection for a user.
  """
  def stop_user_connection(user_id) when is_integer(user_id) do
    Supervisor.terminate_child(__MODULE__, {:binance_user_ws, user_id})
  end

  @doc """
  Get the status of all WebSocket connections managed by this supervisor.
  """
  def get_connection_statuses do
    credentials = []

    Enum.map(credentials, fn cred ->
      BinanceUserWsAdapter.connection_status(cred.user_id)
    end)
  end

  @doc """
  Get the status of a specific WebSocket connection.
  """
  def get_connection_status(user_id) when is_integer(user_id) do
    BinanceUserWsAdapter.connection_status(user_id)
  end

  @doc """
  Check if a specific WebSocket connection is alive.
  """
  def alive?(user_id) when is_integer(user_id) do
    BinanceUserWsAdapter.alive?(user_id)
  end
end
