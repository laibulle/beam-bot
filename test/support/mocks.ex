import Mox

defmock(BeamBot.Exchanges.Infrastructure.Adapters.Ecto.TradingPairsRepositoryMock,
  for: BeamBot.Exchanges.Domain.Ports.TradingPairsRepository
)

defmock(BeamBot.Exchanges.Infrastructure.Adapters.Ecto.ExchangesRepositoryMock,
  for: BeamBot.Exchanges.Domain.Ports.ExchangesRepository
)

defmock(BeamBot.Exchanges.Infrastructure.Adapters.Exchanges.BinanceReqAdapterMock,
  for: BeamBot.Exchanges.Domain.Ports.ExchangePort
)

defmock(BeamBot.Exchanges.Infrastructure.Adapters.Ecto.PlatformCredentialsRepositoryMock,
  for: BeamBot.Exchanges.Domain.Ports.PlatformCredentialsRepository
)

defmock(BeamBot.Exchanges.Infrastructure.Adapters.QuestDB.KlinesTuplesRepositoryMock,
  for: BeamBot.Exchanges.Domain.Ports.KlinesTuplesRepository
)

defmock(BeamBot.Exchanges.Infrastructure.Adapters.Ecto.SyncHistoryRepositoryMock,
  for: BeamBot.Exchanges.Domain.Ports.SyncHistoryRepository
)
