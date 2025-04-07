use rustbot::infrastructure::config::binance_config::BinanceConfig;

struct MockBinanceConfig {
    base_url: String,
    api_key: Option<String>,
    api_secret: Option<String>,
    requests_per_minute: u64,
}

impl BinanceConfig for MockBinanceConfig {
    fn base_url(&self) -> String {
        self.base_url.clone()
    }

    fn api_key(&self) -> Option<String> {
        self.api_key.clone()
    }

    fn api_secret(&self) -> Option<String> {
        self.api_secret.clone()
    }

    fn requests_per_minute(&self) -> u64 {
        self.requests_per_minute
    }
}

#[test]
fn test_binance_config() {
    let config = MockBinanceConfig {
        base_url: "https://api.binance.com".to_string(),
        api_key: Some("test_key".to_string()),
        api_secret: Some("test_secret".to_string()),
        requests_per_minute: 10,
    };

    assert_eq!(config.base_url(), "https://api.binance.com");
    assert_eq!(config.api_key(), Some("test_key".to_string()));
    assert_eq!(config.api_secret(), Some("test_secret".to_string()));
    assert_eq!(config.requests_per_minute(), 10);
}

#[test]
fn test_binance_config_without_auth() {
    let config = MockBinanceConfig {
        base_url: "https://api.binance.com".to_string(),
        api_key: None,
        api_secret: None,
        requests_per_minute: 5,
    };

    assert_eq!(config.base_url(), "https://api.binance.com");
    assert_eq!(config.api_key(), None);
    assert_eq!(config.api_secret(), None);
    assert_eq!(config.requests_per_minute(), 5);
}
