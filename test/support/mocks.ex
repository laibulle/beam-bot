import Mox

defmock(BeamBot.Exchanges.Infrastructure.Adapters.Ecto.TradingPairsRepositoryMock,
  for: BeamBot.Exchanges.Domain.Ports.TradingPairsRepository
)

defmock(BeamBot.Exchanges.Infrastructure.Adapters.Ecto.KlinesRepositoryMock,
  for: BeamBot.Exchanges.UseCases.Ports.KlinesRepository
)
