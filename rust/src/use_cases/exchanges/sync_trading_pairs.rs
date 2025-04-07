use crate::domain::ports::binance_adapter::BinanceAdapter;
use crate::domain::ports::trading_pair_repository::TradingPairRepository;
use std::error::Error;

pub struct SyncTradingPairsUseCase<T: TradingPairRepository, B: BinanceAdapter> {
    repository: T,
    binance_adapter: B,
}

impl<T: TradingPairRepository, B: BinanceAdapter> SyncTradingPairsUseCase<T, B> {
    pub fn new(repository: T, binance_adapter: B) -> Self {
        Self {
            repository,
            binance_adapter,
        }
    }

    pub async fn execute(&self) -> Result<(), Box<dyn Error + Send + Sync>> {
        let trading_pairs = self.binance_adapter.get_trading_pairs().await?;
        self.repository.save_all(trading_pairs).await?;
        Ok(())
    }
}
