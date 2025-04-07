use crate::{
    domain::ports::binance_adapter::{BinanceAdapter, BinanceError, Kline},
    domain::trading_pairs::trading_pair::TradingPair,
    infrastructure::config::binance_config::BinanceConfig,
};
use reqwest::Client;
use serde_json::Value;

pub struct BinanceClient {
    client: Client,
    base_url: String,
}

impl BinanceClient {
    pub fn new<C: BinanceConfig>(config: C) -> Self {
        Self {
            client: Client::new(),
            base_url: config.base_url(),
        }
    }
}

impl BinanceAdapter for BinanceClient {
    fn get_klines(
        &self,
        symbol: &str,
        interval: &str,
        start_time: Option<i64>,
        end_time: Option<i64>,
        limit: Option<u32>,
    ) -> impl std::future::Future<Output = Result<Vec<Kline>, BinanceError>> + Send {
        let url = format!(
            "{}/api/v3/klines?symbol={}&interval={}",
            self.base_url, symbol, interval
        );

        let mut url = url;
        if let Some(start) = start_time {
            url.push_str(&format!("&startTime={}", start));
        }

        if let Some(end) = end_time {
            url.push_str(&format!("&endTime={}", end));
        }

        if let Some(limit) = limit {
            url.push_str(&format!("&limit={}", limit));
        }

        let client = self.client.clone();
        async move {
            let response = client.get(&url).send().await;

            match response {
                Ok(response) => {
                    if !response.status().is_success() {
                        let error_text = response.text().await.unwrap_or_default();
                        return Err(BinanceError::RequestError(error_text));
                    }

                    let json: Vec<Value> = response
                        .json()
                        .await
                        .map_err(|e| BinanceError::ParseError(e.to_string()))?;

                    let mut klines = Vec::new();
                    for kline in json {
                        let kline = parse_kline(kline)?;
                        klines.push(kline);
                    }

                    Ok(klines)
                }
                Err(e) => Err(BinanceError::RequestError(e.to_string())),
            }
        }
    }

    fn get_trading_pairs(
        &self,
    ) -> impl std::future::Future<Output = Result<Vec<TradingPair>, BinanceError>> + Send {
        let url = format!("{}/api/v3/exchangeInfo", self.base_url);
        let client = self.client.clone();

        async move {
            let response = client.get(&url).send().await;

            match response {
                Ok(response) => {
                    if !response.status().is_success() {
                        let error_text = response.text().await.unwrap_or_default();
                        return Err(BinanceError::RequestError(error_text));
                    }

                    let json: Value = response
                        .json()
                        .await
                        .map_err(|e| BinanceError::ParseError(e.to_string()))?;

                    let symbols = json["symbols"].as_array().ok_or_else(|| {
                        BinanceError::ParseError("Expected symbols array".to_string())
                    })?;

                    let trading_pairs: Vec<TradingPair> = symbols
                        .iter()
                        .map(|symbol| {
                            TradingPair::new(
                                symbol["symbol"].as_str().unwrap().to_string(),
                                symbol["baseAsset"].as_str().unwrap().to_string(),
                                symbol["quoteAsset"].as_str().unwrap().to_string(),
                                symbol["status"].as_str().unwrap().to_string(),
                                symbol["isMarginTradingAllowed"].as_bool().unwrap_or(false),
                                symbol["isSpotTradingAllowed"].as_bool().unwrap_or(false),
                                1,
                                None,
                                None,
                            )
                        })
                        .collect();

                    Ok(trading_pairs)
                }
                Err(e) => Err(BinanceError::RequestError(e.to_string())),
            }
        }
    }
}

fn parse_kline(value: Value) -> Result<Kline, BinanceError> {
    let arr = value
        .as_array()
        .ok_or_else(|| BinanceError::ParseError("Expected array".to_string()))?;

    if arr.len() < 12 {
        return Err(BinanceError::ParseError("Invalid kline data".to_string()));
    }

    Ok(Kline {
        open_time: arr[0].as_i64().unwrap_or(0),
        open: arr[1].as_str().unwrap_or("0").parse().unwrap_or(0.0),
        high: arr[2].as_str().unwrap_or("0").parse().unwrap_or(0.0),
        low: arr[3].as_str().unwrap_or("0").parse().unwrap_or(0.0),
        close: arr[4].as_str().unwrap_or("0").parse().unwrap_or(0.0),
        volume: arr[5].as_str().unwrap_or("0").parse().unwrap_or(0.0),
        close_time: arr[6].as_i64().unwrap_or(0),
        quote_asset_volume: arr[7].as_str().unwrap_or("0").parse().unwrap_or(0.0),
        number_of_trades: arr[8].as_u64().unwrap_or(0),
        taker_buy_base_asset_volume: arr[9].as_str().unwrap_or("0").parse().unwrap_or(0.0),
        taker_buy_quote_asset_volume: arr[10].as_str().unwrap_or("0").parse().unwrap_or(0.0),
    })
}
