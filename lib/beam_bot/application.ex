defmodule BeamBot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    initial_streams = [
      # "btcusdt@aggTrade",
      # "ethusdt@aggTrade",
      # "solusdt@aggTrade",
      # "bnbusdt@aggTrade",
      "btcusdt@markPrice"
    ]

    base_children = [
      BeamBotWeb.Telemetry,
      BeamBot.Repo,
      {DNSCluster, query: Application.get_env(:beam_bot, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: BeamBot.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: BeamBot.Finch},
      # Start to serve requests, typically the last entry
      BeamBotWeb.Endpoint
    ]

    prod_children = [
      # Start the trading pairs sync worker
      BeamBot.Exchanges.Infrastructure.Workers.TradingPairsSyncWorker,
      # Start the small investor strategy worker
      BeamBot.Strategies.Infrastructure.Workers.SmallInvestorStrategyWorker,
      # Start the historical data sync worker
      # BeamBot.Exchanges.Infrastructure.Workers.HistoricalDataSyncWorker,
      # Start the Telegram messages sync worker
      # BeamBot.Socials.Workers.TelegramMessagesSyncWorker,
      {BeamBot.Exchanges.Infrastructure.Adapters.BinanceWsAdapter, initial_streams}
    ]

    children =
      case Application.get_env(:beam_bot, :env) do
        :test -> base_children
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
