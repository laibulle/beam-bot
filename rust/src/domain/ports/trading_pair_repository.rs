use crate::domain::trading_pairs::trading_pair::TradingPair;
use async_trait::async_trait;
use std::error::Error;

#[async_trait]
pub trait TradingPairRepository: Send + Sync {
    async fn save(&self, trading_pair: TradingPair) -> Result<(), Box<dyn Error + Send + Sync>>;
    async fn save_all(
        &self,
        trading_pairs: Vec<TradingPair>,
    ) -> Result<(), Box<dyn Error + Send + Sync>>;
    async fn find_by_symbol(
        &self,
        symbol: &str,
    ) -> Result<Option<TradingPair>, Box<dyn Error + Send + Sync>>;
    async fn find_all(&self) -> Result<Vec<TradingPair>, Box<dyn Error + Send + Sync>>;
}
