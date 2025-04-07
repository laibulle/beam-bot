use crate::domain::ports::trading_pair_repository::TradingPairRepository;
use crate::domain::trading_pairs::trading_pair::TradingPair;
use chrono::{DateTime, NaiveDateTime, TimeZone, Utc};
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
        let now = Utc::now().naive_utc();
        sqlx::query(
            r#"
            INSERT INTO trading_pairs (
                symbol, exchange_id, base_asset, quote_asset, min_price, max_price, 
                tick_size, min_qty, max_qty, step_size, min_notional, is_active,
                status, is_margin_trading, is_spot_trading, sync_start_time, sync_end_time,
                inserted_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19)
            ON CONFLICT (symbol, exchange_id) DO UPDATE SET
                base_asset = EXCLUDED.base_asset,
                quote_asset = EXCLUDED.quote_asset,
                min_price = EXCLUDED.min_price,
                max_price = EXCLUDED.max_price,
                tick_size = EXCLUDED.tick_size,
                min_qty = EXCLUDED.min_qty,
                max_qty = EXCLUDED.max_qty,
                step_size = EXCLUDED.step_size,
                min_notional = EXCLUDED.min_notional,
                is_active = EXCLUDED.is_active,
                status = EXCLUDED.status,
                is_margin_trading = EXCLUDED.is_margin_trading,
                is_spot_trading = EXCLUDED.is_spot_trading,
                sync_start_time = EXCLUDED.sync_start_time,
                sync_end_time = EXCLUDED.sync_end_time,
                inserted_at = EXCLUDED.inserted_at,
                updated_at = CURRENT_TIMESTAMP
            "#,
        )
        .bind(&trading_pair.symbol)
        .bind(&trading_pair.exchange_id)
        .bind(&trading_pair.base_asset)
        .bind(&trading_pair.quote_asset)
        .bind(&trading_pair.min_price)
        .bind(&trading_pair.max_price)
        .bind(&trading_pair.tick_size)
        .bind(&trading_pair.min_qty)
        .bind(&trading_pair.max_qty)
        .bind(&trading_pair.step_size)
        .bind(&trading_pair.min_notional)
        .bind(trading_pair.is_active)
        .bind(&trading_pair.status)
        .bind(trading_pair.is_margin_trading)
        .bind(trading_pair.is_spot_trading)
        .bind(trading_pair.sync_start_time.map(|dt| dt.naive_utc()))
        .bind(trading_pair.sync_end_time.map(|dt| dt.naive_utc()))
        .bind(now)
        .bind(now)
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
            SELECT id, symbol, exchange_id, base_asset, quote_asset, min_price, max_price,
                   tick_size, min_qty, max_qty, step_size, min_notional, is_active,
                   status, is_margin_trading, is_spot_trading, sync_start_time, sync_end_time
            FROM trading_pairs
            WHERE symbol = $1
            "#,
        )
        .bind(symbol)
        .fetch_optional(&self.pool)
        .await?;

        if let Some(row) = row {
            Ok(Some(TradingPair {
                id: row.get("id"),
                symbol: row.get("symbol"),
                base_asset: row.get("base_asset"),
                quote_asset: row.get("quote_asset"),
                min_price: row.get("min_price"),
                max_price: row.get("max_price"),
                tick_size: row.get("tick_size"),
                min_qty: row.get("min_qty"),
                max_qty: row.get("max_qty"),
                step_size: row.get("step_size"),
                min_notional: row.get("min_notional"),
                is_active: row.get("is_active"),
                status: row.get("status"),
                is_margin_trading: row.get("is_margin_trading"),
                is_spot_trading: row.get("is_spot_trading"),
                exchange_id: row.get("exchange_id"),
                sync_start_time: row
                    .get::<Option<NaiveDateTime>, _>("sync_start_time")
                    .map(|ndt| Utc.from_utc_datetime(&ndt)),
                sync_end_time: row
                    .get::<Option<NaiveDateTime>, _>("sync_end_time")
                    .map(|ndt| Utc.from_utc_datetime(&ndt)),
            }))
        } else {
            Ok(None)
        }
    }

    async fn find_all(&self) -> Result<Vec<TradingPair>, Box<dyn Error + Send + Sync>> {
        let rows = sqlx::query(
            r#"
            SELECT id, symbol, exchange_id, base_asset, quote_asset, min_price, max_price,
                   tick_size, min_qty, max_qty, step_size, min_notional, is_active,
                   status, is_margin_trading, is_spot_trading, sync_start_time, sync_end_time
            FROM trading_pairs
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        let trading_pairs = rows
            .into_iter()
            .map(|row| TradingPair {
                id: row.get("id"),
                symbol: row.get("symbol"),
                base_asset: row.get("base_asset"),
                quote_asset: row.get("quote_asset"),
                min_price: row.get("min_price"),
                max_price: row.get("max_price"),
                tick_size: row.get("tick_size"),
                min_qty: row.get("min_qty"),
                max_qty: row.get("max_qty"),
                step_size: row.get("step_size"),
                min_notional: row.get("min_notional"),
                is_active: row.get("is_active"),
                status: row.get("status"),
                is_margin_trading: row.get("is_margin_trading"),
                is_spot_trading: row.get("is_spot_trading"),
                exchange_id: row.get("exchange_id"),
                sync_start_time: row
                    .get::<Option<NaiveDateTime>, _>("sync_start_time")
                    .map(|ndt| Utc.from_utc_datetime(&ndt)),
                sync_end_time: row
                    .get::<Option<NaiveDateTime>, _>("sync_end_time")
                    .map(|ndt| Utc.from_utc_datetime(&ndt)),
            })
            .collect();

        Ok(trading_pairs)
    }
}
