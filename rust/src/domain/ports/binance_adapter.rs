use crate::domain::trading_pairs::trading_pair::TradingPair;
use serde::{Deserialize, Serialize};
use std::error::Error;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Kline {
    pub platform: String,
    pub interval: String,
    pub symbol: String,
    pub open_time: i64,  // Unix timestamp in milliseconds
    pub close_time: i64, // Unix timestamp in milliseconds
    pub open: f64,
    pub high: f64,
    pub low: f64,
    pub close: f64,
    pub volume: f64,
    pub quote_asset_volume: f64,
    pub taker_buy_base_asset_volume: f64,
    pub taker_buy_quote_asset_volume: f64,
    pub number_of_trades: u64,
}

#[derive(Debug)]
pub enum BinanceError {
    RequestError(String),
    ParseError(String),
    InvalidInterval(String),
}

impl std::fmt::Display for BinanceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            BinanceError::RequestError(msg) => write!(f, "Request error: {}", msg),
            BinanceError::ParseError(msg) => write!(f, "Parse error: {}", msg),
            BinanceError::InvalidInterval(msg) => write!(f, "Invalid interval: {}", msg),
        }
    }
}

impl Error for BinanceError {}

pub trait BinanceAdapter: Send + Sync {
    fn get_klines(
        &self,
        symbol: &str,
        interval: &str,
        start_time: Option<i64>,
        end_time: Option<i64>,
        limit: Option<u32>,
    ) -> impl std::future::Future<Output = Result<Vec<Kline>, BinanceError>> + Send;

    fn get_trading_pairs(
        &self,
    ) -> impl std::future::Future<Output = Result<Vec<TradingPair>, BinanceError>> + Send;
}
