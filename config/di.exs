import Config

config :beam_bot,
  trading_pairs_repository:
    BeamBot.Exchanges.Infrastructure.Adapters.Ecto.TradingPairsRepositoryEcto,
  binance_req_adapter: BeamBot.Exchanges.Infrastructure.Adapters.Exchanges.BinanceReqAdapter,
  klines_repository: BeamBot.Exchanges.Infrastructure.Adapters.Ecto.KlinesRepositoryEcto
