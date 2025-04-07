use crate::domain::ports::trading_pair_repository::TradingPairRepository;
use crate::domain::trading_pairs::trading_pair::TradingPair;
use sqlx::postgres::PgPool;
use sqlx::Row;
use std::error::Error;

pub struct TradingPairRepositoryPostgres {
    pool: PgPool,
}

impl TradingPairRepositoryPostgres {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait::async_trait]
impl TradingPairRepository for TradingPairRepositoryPostgres {
    async fn save(&self, trading_pair: TradingPair) -> Result<(), Box<dyn Error + Send + Sync>> {
        sqlx::query(
            r#"
            INSERT INTO trading_pairs (symbol, exchange, base_asset, quote_asset, status, is_margin_trading, is_spot_trading, sync_start_time, sync_end_time)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            ON CONFLICT (symbol, exchange) DO UPDATE SET
                base_asset = EXCLUDED.base_asset,
                quote_asset = EXCLUDED.quote_asset,
                status = EXCLUDED.status,
                is_margin_trading = EXCLUDED.is_margin_trading,
                is_spot_trading = EXCLUDED.is_spot_trading,
                sync_start_time = EXCLUDED.sync_start_time,
                sync_end_time = EXCLUDED.sync_end_time,
                updated_at = CURRENT_TIMESTAMP
            "#,
        )
        .bind(&trading_pair.symbol)
        .bind(&trading_pair.exchange)
        .bind(&trading_pair.base_asset)
        .bind(&trading_pair.quote_asset)
        .bind(&trading_pair.status)
        .bind(trading_pair.is_margin_trading)
        .bind(trading_pair.is_spot_trading)
        .bind(trading_pair.sync_start_time)
        .bind(trading_pair.sync_end_time)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn save_all(
        &self,
        trading_pairs: Vec<TradingPair>,
    ) -> Result<(), Box<dyn Error + Send + Sync>> {
        for trading_pair in trading_pairs {
            self.save(trading_pair).await?;
        }
        Ok(())
    }

    async fn find_by_symbol(
        &self,
        symbol: &str,
    ) -> Result<Option<TradingPair>, Box<dyn Error + Send + Sync>> {
        let row = sqlx::query(
            r#"
            SELECT symbol, base_asset, quote_asset, status, is_margin_trading, is_spot_trading, exchange, sync_start_time, sync_end_time
            FROM trading_pairs
            WHERE symbol = $1
            "#,
        )
        .bind(symbol)
        .fetch_optional(&self.pool)
        .await?;

        if let Some(row) = row {
            Ok(Some(TradingPair::new(
                row.get("symbol"),
                row.get("base_asset"),
                row.get("quote_asset"),
                row.get("status"),
                row.get("is_margin_trading"),
                row.get("is_spot_trading"),
                row.get("exchange"),
                row.get("sync_start_time"),
                row.get("sync_end_time"),
            )))
        } else {
            Ok(None)
        }
    }

    async fn find_all(&self) -> Result<Vec<TradingPair>, Box<dyn Error + Send + Sync>> {
        let rows = sqlx::query(
            r#"
            SELECT id, symbol, exchange, base_asset, quote_asset, status, is_margin_trading, is_spot_trading, sync_start_time, sync_end_time, created_at, updated_at
            FROM trading_pairs
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        let trading_pairs = rows
            .into_iter()
            .map(|row| {
                TradingPair::new(
                    row.get("symbol"),
                    row.get("base_asset"),
                    row.get("quote_asset"),
                    row.get("status"),
                    row.get("is_margin_trading"),
                    row.get("is_spot_trading"),
                    row.get("exchange"),
                    row.get("sync_start_time"),
                    row.get("sync_end_time"),
                )
            })
            .collect();

        Ok(trading_pairs)
    }
}
