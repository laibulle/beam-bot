/// Trait defining the configuration interface for Binance API
pub trait BinanceConfig {
    /// Get the base URL for the Binance API
    fn base_url(&self) -> String;

    /// Get the API key for authentication (if required)
    fn api_key(&self) -> Option<String>;

    /// Get the API secret for authentication (if required)
    fn api_secret(&self) -> Option<String>;

    /// Get the maximum number of requests per minute allowed
    fn requests_per_minute(&self) -> u64;
}
