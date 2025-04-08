defmodule BeamBot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    base_children = [
      BeamBotWeb.Telemetry,
      BeamBot.Repo,
      {DNSCluster, query: Application.get_env(:beam_bot, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: BeamBot.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: BeamBot.Finch},
      # Start QuestDB client
      {BeamBot.QuestDB,
       [
         host: Application.get_env(:beam_bot, :questdb_host, "localhost"),
         port: Application.get_env(:beam_bot, :questdb_port, 9000),
         username: Application.get_env(:beam_bot, :questdb_username, "admin"),
         password: Application.get_env(:beam_bot, :questdb_password, "quest")
       ]},
      # Start to serve requests, typically the last entry
      BeamBotWeb.Endpoint,
      # Start NATS listener
      {BeamBot.Infrastructure.Adapters.Nats.NatsListenerGnat,
       connection_settings: Application.get_env(:beam_bot, :nats)[:connection_settings]},
      # Start Kline Saved Listener
      BeamBot.Infrastructure.Workers.KlineSavedListener,
      # Start Trading Pairs Updated Listener
      BeamBot.Infrastructure.Workers.TradingPairsUpdatedListener
    ]

    prod_children = [
      # Start the trading pairs sync worker
      BeamBot.Exchanges.Infrastructure.Workers.TradingPairsSyncWorker,
      # Start the Binance rate limiter
      BeamBot.Exchanges.Infrastructure.Workers.BinanceMultiRateLimiter,
      # Start the Registry for WebSocket connections
      {Registry, keys: :unique, name: BeamBot.Registry}
      # Start the Binance WebSocket supervisor
      # BeamBot.Exchanges.Infrastructure.Workers.BinanceWsSupervisor,
      # Start the Binance user data WebSocket supervisor
      # BeamBot.Exchanges.Infrastructure.Workers.BinanceUserWsSupervisor,
      # Start the strategy supervisor
      # BeamBot.Strategies.Infrastructure.Supervisors.StrategySupervisor
    ]

    test_children = [
      # Start the Registry for WebSocket connections in test mode
      {Registry, keys: :unique, name: BeamBot.Registry}
    ]

    children =
      case Application.get_env(:beam_bot, :env) do
        :test -> base_children ++ test_children
        _ -> base_children ++ prod_children
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BeamBot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BeamBotWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
