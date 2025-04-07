use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use std::fmt;

#[derive(Debug, Clone)]
pub struct TradingPair {
    pub id: Option<i64>,
    pub symbol: String,
    pub base_asset: String,
    pub quote_asset: String,
    pub min_price: Option<Decimal>,
    pub max_price: Option<Decimal>,
    pub tick_size: Option<Decimal>,
    pub min_qty: Option<Decimal>,
    pub max_qty: Option<Decimal>,
    pub step_size: Option<Decimal>,
    pub min_notional: Option<Decimal>,
    pub is_active: bool,
    pub status: String,
    pub is_margin_trading: bool,
    pub is_spot_trading: bool,
    pub exchange_id: i64,
    pub sync_start_time: Option<DateTime<Utc>>,
    pub sync_end_time: Option<DateTime<Utc>>,
}

impl fmt::Display for TradingPair {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.symbol)
    }
}

impl TradingPair {
    pub fn new(
        symbol: String,
        base_asset: String,
        quote_asset: String,
        status: String,
        is_margin_trading: bool,
        is_spot_trading: bool,
        exchange_id: i64,
        sync_start_time: Option<DateTime<Utc>>,
        sync_end_time: Option<DateTime<Utc>>,
        min_price: Option<Decimal>,
        max_price: Option<Decimal>,
        tick_size: Option<Decimal>,
        min_qty: Option<Decimal>,
        max_qty: Option<Decimal>,
        step_size: Option<Decimal>,
        min_notional: Option<Decimal>,
    ) -> Self {
        Self {
            id: None,
            symbol,
            base_asset,
            quote_asset,
            min_price,
            max_price,
            tick_size,
            min_qty,
            max_qty,
            step_size,
            min_notional,
            is_active: true,
            status,
            is_margin_trading,
            is_spot_trading,
            exchange_id,
            sync_start_time,
            sync_end_time,
        }
    }
}
