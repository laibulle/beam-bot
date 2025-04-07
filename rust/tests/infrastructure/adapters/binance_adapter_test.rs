use chrono::{Duration, Utc};
use rustbot::domain::ports::binance_adapter::{BinanceAdapter, BinanceError};
use rustbot::infrastructure::adapters::binance_adapter::BinanceClient;
use rustbot::infrastructure::config::binance_config::BinanceConfig;

// Test configuration for Binance API
struct TestBinanceConfig;

impl BinanceConfig for TestBinanceConfig {
    fn base_url(&self) -> String {
        "https://api.binance.com".to_string()
    }

    fn api_key(&self) -> Option<String> {
        None
    }

    fn api_secret(&self) -> Option<String> {
        None
    }

    fn requests_per_minute(&self) -> u64 {
        10
    }
}

#[tokio::test]
async fn test_get_klines() {
    // Create a new Binance client with test configuration
    let config = TestBinanceConfig;
    let client = BinanceClient::new(config);

    // Test parameters
    let symbol = "BTCUSDT";
    let interval = "1h";
    let end_time = Utc::now().timestamp_millis();
    let start_time = end_time - Duration::hours(24).num_milliseconds();
    let limit = Some(100);

    // Call the API
    let result = client
        .get_klines(symbol, interval, Some(start_time), Some(end_time), limit)
        .await;

    // Assert the result
    assert!(result.is_ok(), "Failed to get klines: {:?}", result.err());

    let klines = result.unwrap();
    assert!(!klines.is_empty(), "No klines returned");
    assert!(klines.len() <= 100, "More klines returned than limit");

    // Verify the structure of the first kline
    let first_kline = &klines[0];
    assert!(first_kline.open > 0.0, "Invalid open price");
    assert!(first_kline.high > 0.0, "Invalid high price");
    assert!(first_kline.low > 0.0, "Invalid low price");
    assert!(first_kline.close > 0.0, "Invalid close price");
    assert!(first_kline.volume > 0.0, "Invalid volume");
    assert!(
        first_kline.open_time <= first_kline.close_time,
        "Invalid time range"
    );
}

#[tokio::test]
async fn test_get_klines_invalid_symbol() {
    let config = TestBinanceConfig;
    let client = BinanceClient::new(config);

    // Test with an invalid symbol
    let result = client
        .get_klines("INVALIDPAIR", "1h", None, None, None)
        .await;

    // Should return a request error
    assert!(result.is_err());
    if let Err(e) = result {
        assert!(matches!(e, BinanceError::RequestError(_)));
    }
}

#[tokio::test]
async fn test_get_klines_invalid_interval() {
    let config = TestBinanceConfig;
    let client = BinanceClient::new(config);

    // Test with an invalid interval
    let result = client
        .get_klines("BTCUSDT", "invalid", None, None, None)
        .await;

    // Should return a request error
    assert!(result.is_err());
    if let Err(e) = result {
        assert!(matches!(e, BinanceError::RequestError(_)));
    }
}
