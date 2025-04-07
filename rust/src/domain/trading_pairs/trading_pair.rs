use std::fmt;

#[derive(Debug, Clone)]
pub struct TradingPair {
    pub symbol: String,
    pub base_asset: String,
    pub quote_asset: String,
    pub status: String,
    pub is_margin_trading: bool,
    pub is_spot_trading: bool,
    pub exchange: String,
    pub sync_start_time: Option<i64>,
    pub sync_end_time: Option<i64>,
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
        exchange: String,
        sync_start_time: Option<i64>,
        sync_end_time: Option<i64>,
    ) -> Self {
        Self {
            symbol,
            base_asset,
            quote_asset,
            status,
            is_margin_trading,
            is_spot_trading,
            exchange,
            sync_start_time,
            sync_end_time,
        }
    }
}
