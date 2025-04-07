use crate::domain::ports::binance_adapter::Kline;
use crate::domain::ports::klines_repository::{KlinesRepository, KlinesRepositoryError};
use std::sync::Arc;
use tokio::io::{AsyncWriteExt, BufWriter};
use tokio::net::TcpStream;
use tokio::sync::Mutex;

pub struct KlinesRepositoryQuestDb {
    writer: Arc<Mutex<BufWriter<TcpStream>>>,
}

impl KlinesRepositoryQuestDb {
    pub fn new(writer: BufWriter<TcpStream>) -> Self {
        Self {
            writer: Arc::new(Mutex::new(writer)),
        }
    }
}

impl KlinesRepository for KlinesRepositoryQuestDb {
    fn save_klines(
        &self,
        symbol: &str,
        klines: &[Kline],
    ) -> impl std::future::Future<Output = Result<(), KlinesRepositoryError>> + Send {
        let symbol = symbol.to_string();
        let klines = klines.to_vec();
        let writer = Arc::clone(&self.writer);

        async move {
            let mut writer = writer.lock().await;

            for kline in klines {
                let line = format!(
                    "klines_{},symbol={} open={},high={},low={},close={},volume={},quote_asset_volume={},taker_buy_base_asset_volume={},taker_buy_quote_asset_volume={},number_of_trades={} {}000000\n",
                    symbol.to_lowercase(),
                    symbol,
                    kline.open,
                    kline.high,
                    kline.low,
                    kline.close,
                    kline.volume,
                    kline.quote_asset_volume,
                    kline.taker_buy_base_asset_volume,
                    kline.taker_buy_quote_asset_volume,
                    kline.number_of_trades,
                    kline.open_time
                );

                if let Err(e) = writer.write_all(line.as_bytes()).await {
                    return Err(KlinesRepositoryError::DatabaseError(format!(
                        "Failed to write kline: {}",
                        e
                    )));
                }
            }

            if let Err(e) = writer.flush().await {
                return Err(KlinesRepositoryError::DatabaseError(format!(
                    "Failed to flush writer: {}",
                    e
                )));
            }

            Ok(())
        }
    }
}
