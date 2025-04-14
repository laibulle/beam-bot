# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :beam_bot,
  ecto_repos: [BeamBot.Repo],
  disabled_coins: ["USDT", "BTCUP", "BTCDOWN", "ETHUP", "ETHDOWN", "XMR", "ZEC", "DASH"],
  trading_pairs_repository:
    BeamBot.Exchanges.Infrastructure.Adapters.Ecto.TradingPairsRepositoryEcto,
  strategy_repository: BeamBot.Strategies.Infrastructure.Adapters.Ecto.StrategyRepositoryEcto,
  binance_req_adapter: BeamBot.Exchanges.Infrastructure.Adapters.Binance.BinanceReqAdapter,
  generators: [timestamp_type: :utc_datetime],
  telegram_bot_token: "7366626666:AAGgnLf1jlbNRxRXfK-48Yn9BXGBdwRoJYk",
  simulation_results_repository:
    BeamBot.Strategies.Infrastructure.Adapters.Ecto.SimulationResultsRepositoryEcto,
  # QuestDB configuration
  questdb_host: "localhost",
  questdb_port: 9000,
  questdb_username: "admin",
  questdb_password: "quest",
  # Rate limiter configuration
  binance_rate_limiter: [
    # 1 minute in milliseconds
    window_size: 60_000,
    # 1 second
    cleanup_interval: 1_000,
    default_weight_per_minute: 1200
  ]

config :beam_bot, :basic_auth, username: "admin", password: "admin123"

config :beam_bot,
  max_best_trading_pairs_small_investor_concurrency: 50,
  sync_all_historical_data_for_platform_concurrent_pairs: 5

# Configures the endpoint
config :beam_bot, BeamBotWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: BeamBotWeb.ErrorHTML, json: BeamBotWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: BeamBot.PubSub,
  live_view: [signing_salt: "mwGCog1m"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :beam_bot, BeamBot.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  beam_bot: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  beam_bot: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

import_config "di.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

# NATS Configuration
config :beam_bot, :nats,
  connection_settings: %{
    host: System.get_env("NATS_HOST", "localhost"),
    port: String.to_integer(System.get_env("NATS_PORT", "4222")),
    username: System.get_env("NATS_USERNAME", ""),
    password: System.get_env("NATS_PASSWORD", "")
  }
