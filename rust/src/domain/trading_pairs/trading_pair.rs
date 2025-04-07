use chrono::{DateTime, Utc};
use std::fmt;

#[derive(Debug, Clone)]
pub struct TradingPair {
    pub id: Option<i64>,
    pub symbol: String,
    pub base_asset: String,
    pub quote_asset: String,
    pub min_price: Option<f64>,
    pub max_price: Option<f64>,
    pub tick_size: Option<f64>,
    pub min_qty: Option<f64>,
    pub max_qty: Option<f64>,
    pub step_size: Option<f64>,
    pub min_notional: Option<f64>,
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
    ) -> Self {
        Self {
            id: None,
            symbol,
            base_asset,
            quote_asset,
            min_price: None,
            max_price: None,
            tick_size: None,
            min_qty: None,
            max_qty: None,
            step_size: None,
            min_notional: None,
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
