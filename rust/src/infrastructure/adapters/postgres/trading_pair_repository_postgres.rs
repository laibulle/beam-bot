use crate::domain::ports::trading_pair_repository::TradingPairRepository;
use crate::domain::trading_pairs::trading_pair::TradingPair;
use chrono::{NaiveDateTime, TimeZone, Utc};
use log::{debug, error, info};
use rust_decimal::prelude::*;
use sqlx::postgres::PgPool;
use sqlx::Row;
use std::error::Error;
use std::str::FromStr;

pub struct TradingPairRepositoryPostgres {
    pool: PgPool,
}

impl TradingPairRepositoryPostgres {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    fn decimal_to_numeric(decimal: &Option<Decimal>) -> Option<String> {
        debug!("Converting decimal to numeric: {:?}", decimal);
        decimal.as_ref().map(|d| d.to_string())
    }

    fn numeric_to_decimal(numeric: Option<String>) -> Option<Decimal> {
        debug!("Converting numeric to decimal: {:?}", numeric);
        numeric.and_then(|n| Decimal::from_str(&n).ok())
    }

    fn convert_datetime(ndt: Option<NaiveDateTime>) -> Option<chrono::DateTime<Utc>> {
        ndt.map(|ndt| Utc.from_utc_datetime(&ndt))
    }
}

#[async_trait::async_trait]
impl TradingPairRepository for TradingPairRepositoryPostgres {
    async fn save(&self, trading_pair: TradingPair) -> Result<(), Box<dyn Error + Send + Sync>> {
        debug!("Saving trading pair: {:?}", trading_pair);
        let now = Utc::now().naive_utc();

        let result = sqlx::query(
            r#"
            INSERT INTO trading_pairs (
                symbol, exchange_id, base_asset, quote_asset, min_price, max_price, 
                tick_size, min_qty, max_qty, step_size, min_notional, is_active,
                status, is_margin_trading, is_spot_trading, sync_start_time, sync_end_time,
                inserted_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5::numeric, $6::numeric, $7::numeric, $8::numeric, 
                   $9::numeric, $10::numeric, $11::numeric, $12, $13, $14, $15, $16, $17, $18, $19)
            ON CONFLICT (symbol, exchange_id) DO UPDATE SET
                base_asset = EXCLUDED.base_asset,
                quote_asset = EXCLUDED.quote_asset,
                min_price = EXCLUDED.min_price::numeric,
                max_price = EXCLUDED.max_price::numeric,
                tick_size = EXCLUDED.tick_size::numeric,
                min_qty = EXCLUDED.min_qty::numeric,
                max_qty = EXCLUDED.max_qty::numeric,
                step_size = EXCLUDED.step_size::numeric,
                min_notional = EXCLUDED.min_notional::numeric,
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
        .bind(Self::decimal_to_numeric(&trading_pair.min_price))
        .bind(Self::decimal_to_numeric(&trading_pair.max_price))
        .bind(Self::decimal_to_numeric(&trading_pair.tick_size))
        .bind(Self::decimal_to_numeric(&trading_pair.min_qty))
        .bind(Self::decimal_to_numeric(&trading_pair.max_qty))
        .bind(Self::decimal_to_numeric(&trading_pair.step_size))
        .bind(Self::decimal_to_numeric(&trading_pair.min_notional))
        .bind(trading_pair.is_active)
        .bind(&trading_pair.status)
        .bind(trading_pair.is_margin_trading)
        .bind(trading_pair.is_spot_trading)
        .bind(trading_pair.sync_start_time.map(|dt| dt.naive_utc()))
        .bind(trading_pair.sync_end_time.map(|dt| dt.naive_utc()))
        .bind(now)
        .bind(now)
        .execute(&self.pool)
        .await;

        match result {
            Ok(_) => {
                debug!("Successfully saved trading pair: {}", trading_pair.symbol);
                Ok(())
            }
            Err(e) => {
                error!(
                    "Failed to save trading pair {}: {:?}",
                    trading_pair.symbol, e
                );
                Err(Box::new(e))
            }
        }
    }

    async fn save_all(
        &self,
        trading_pairs: Vec<TradingPair>,
    ) -> Result<(), Box<dyn Error + Send + Sync>> {
        debug!("Saving {} trading pairs", trading_pairs.len());
        for trading_pair in trading_pairs {
            if let Err(e) = self.save(trading_pair).await {
                error!("Failed to save trading pair: {:?}", e);
                return Err(e);
            }
        }
        debug!("Successfully saved all trading pairs");
        Ok(())
    }

    async fn find_by_symbol(
        &self,
        symbol: &str,
    ) -> Result<Option<TradingPair>, Box<dyn Error + Send + Sync>> {
        debug!("Finding trading pair by symbol: {}", symbol);
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
            debug!("Found trading pair for symbol: {}", symbol);
            let trading_pair = TradingPair {
                id: row.get("id"),
                symbol: row.get("symbol"),
                base_asset: row.get("base_asset"),
                quote_asset: row.get("quote_asset"),
                min_price: Self::numeric_to_decimal(row.get::<Option<String>, _>("min_price")),
                max_price: Self::numeric_to_decimal(row.get::<Option<String>, _>("max_price")),
                tick_size: Self::numeric_to_decimal(row.get::<Option<String>, _>("tick_size")),
                min_qty: Self::numeric_to_decimal(row.get::<Option<String>, _>("min_qty")),
                max_qty: Self::numeric_to_decimal(row.get::<Option<String>, _>("max_qty")),
                step_size: Self::numeric_to_decimal(row.get::<Option<String>, _>("step_size")),
                min_notional: Self::numeric_to_decimal(
                    row.get::<Option<String>, _>("min_notional"),
                ),
                is_active: row.get("is_active"),
                status: row.get("status"),
                is_margin_trading: row.get("is_margin_trading"),
                is_spot_trading: row.get("is_spot_trading"),
                exchange_id: row.get("exchange_id"),
                sync_start_time: Self::convert_datetime(
                    row.get::<Option<NaiveDateTime>, _>("sync_start_time"),
                ),
                sync_end_time: Self::convert_datetime(
                    row.get::<Option<NaiveDateTime>, _>("sync_end_time"),
                ),
            };
            debug!("Constructed trading pair: {:?}", trading_pair);
            Ok(Some(trading_pair))
        } else {
            debug!("No trading pair found for symbol: {}", symbol);
            Ok(None)
        }
    }

    async fn find_all(&self) -> Result<Vec<TradingPair>, Box<dyn Error + Send + Sync>> {
        debug!("Fetching all trading pairs");
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

        debug!("Found {} trading pairs", rows.len());
        let trading_pairs = rows
            .into_iter()
            .map(|row| {
                let trading_pair = TradingPair {
                    id: row.get("id"),
                    symbol: row.get("symbol"),
                    base_asset: row.get("base_asset"),
                    quote_asset: row.get("quote_asset"),
                    min_price: Self::numeric_to_decimal(row.get::<Option<String>, _>("min_price")),
                    max_price: Self::numeric_to_decimal(row.get::<Option<String>, _>("max_price")),
                    tick_size: Self::numeric_to_decimal(row.get::<Option<String>, _>("tick_size")),
                    min_qty: Self::numeric_to_decimal(row.get::<Option<String>, _>("min_qty")),
                    max_qty: Self::numeric_to_decimal(row.get::<Option<String>, _>("max_qty")),
                    step_size: Self::numeric_to_decimal(row.get::<Option<String>, _>("step_size")),
                    min_notional: Self::numeric_to_decimal(
                        row.get::<Option<String>, _>("min_notional"),
                    ),
                    is_active: row.get("is_active"),
                    status: row.get("status"),
                    is_margin_trading: row.get("is_margin_trading"),
                    is_spot_trading: row.get("is_spot_trading"),
                    exchange_id: row.get("exchange_id"),
                    sync_start_time: Self::convert_datetime(
                        row.get::<Option<NaiveDateTime>, _>("sync_start_time"),
                    ),
                    sync_end_time: Self::convert_datetime(
                        row.get::<Option<NaiveDateTime>, _>("sync_end_time"),
                    ),
                };
                debug!("Constructed trading pair: {:?}", trading_pair);
                trading_pair
            })
            .collect();

        debug!("Successfully retrieved all trading pairs");
        Ok(trading_pairs)
    }
}
