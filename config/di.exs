import Config

config :beam_bot,
  trading_pairs_repository:
    BeamBot.Exchanges.Infrastructure.Adapters.Ecto.TradingPairsRepositoryEcto,
  binance_req_adapter: BeamBot.Exchanges.Infrastructure.Adapters.Exchanges.BinanceReqAdapter,
  klines_repository: BeamBot.Exchanges.Infrastructure.Adapters.Pg.KlinesRepositoryPg,
  strategy_repository: BeamBot.Strategies.Infrastructure.Adapters.Ecto.StrategyRepositoryEcto,
  exchanges_repository: BeamBot.Exchanges.Infrastructure.Adapters.Ecto.ExchangesRepositoryEcto,
  platform_credentials_repository:
    BeamBot.Exchanges.Infrastructure.Adapters.Ecto.PlatformCredentialsRepositoryEcto,
  klines_tuples_repository: BeamBot.Exchanges.Infrastructure.Adapters.QuestDB.QuestDBRestAdapter
