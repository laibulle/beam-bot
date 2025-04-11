import Config

config :beam_bot,
  trading_pairs_repository:
    BeamBot.Exchanges.Infrastructure.Adapters.Ecto.TradingPairsRepositoryMock,
  binance_req_adapter: BeamBot.Exchanges.Infrastructure.Adapters.Exchanges.BinanceReqAdapterMock,
  exchanges_repository: BeamBot.Exchanges.Infrastructure.Adapters.Ecto.ExchangesRepositoryMock,
  platform_credentials_repository:
    BeamBot.Exchanges.Infrastructure.Adapters.Ecto.PlatformCredentialsRepositoryMock,
  klines_tuples_repository:
    BeamBot.Exchanges.Infrastructure.Adapters.QuestDB.KlinesTuplesRepositoryMock,
  sync_history_repository:
    BeamBot.Exchanges.Infrastructure.Adapters.Ecto.SyncHistoryRepositoryMock
