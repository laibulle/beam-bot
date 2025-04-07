use super::binance_config::BinanceConfig;
use super::postgres_config::PostgresConfig;
use std::env;

#[derive(Debug, Clone)]
pub struct Config {
    pub questdb_host: String,
    pub questdb_port: u16,
    pub questdb_user: String,
    pub questdb_password: String,
    pub questdb_database: String,
    pub binance_api_url: String,
    pub binance_api_key: Option<String>,
    pub binance_api_secret: Option<String>,
    pub binance_requests_per_minute: u64,
    pub postgres_config: PostgresConfig,
}

impl Config {
    pub fn new() -> Self {
        Config {
            questdb_host: env::var("QUESTDB_HOST").unwrap_or_else(|_| "localhost".to_string()),
            questdb_port: env::var("QUESTDB_PORT")
                .unwrap_or_else(|_| "9009".to_string())
                .parse()
                .unwrap_or(9009),
            questdb_user: env::var("QUESTDB_USER").unwrap_or_else(|_| "admin".to_string()),
            questdb_password: env::var("QUESTDB_PASSWORD").unwrap_or_else(|_| "quest".to_string()),
            questdb_database: env::var("QUESTDB_DATABASE").unwrap_or_else(|_| "qdb".to_string()),
            binance_api_url: env::var("BINANCE_API_URL")
                .unwrap_or_else(|_| "https://api.binance.com".to_string()),
            binance_api_key: env::var("BINANCE_API_KEY").ok(),
            binance_api_secret: env::var("BINANCE_API_SECRET").ok(),
            binance_requests_per_minute: env::var("BINANCE_REQUESTS_PER_MINUTE")
                .unwrap_or_else(|_| "1000".to_string())
                .parse()
                .unwrap_or(1000), // 1000 requests per minute (below Binance's 1200 limit)
            postgres_config: PostgresConfig {
                host: env::var("POSTGRES_HOST").unwrap_or_else(|_| "localhost".to_string()),
                port: env::var("POSTGRES_PORT")
                    .unwrap_or_else(|_| "5432".to_string())
                    .parse()
                    .unwrap_or(5432),
                user: env::var("POSTGRES_USER").unwrap_or_else(|_| "postgres".to_string()),
                password: env::var("POSTGRES_PASSWORD").unwrap_or_else(|_| "postgres".to_string()),
                dbname: env::var("POSTGRES_DB").unwrap_or_else(|_| "rustbot".to_string()),
            },
        }
    }
}

impl Default for Config {
    fn default() -> Self {
        Self::new()
    }
}

impl BinanceConfig for Config {
    fn base_url(&self) -> String {
        self.binance_api_url.clone()
    }

    fn api_key(&self) -> Option<String> {
        self.binance_api_key.clone()
    }

    fn api_secret(&self) -> Option<String> {
        self.binance_api_secret.clone()
    }

    fn requests_per_minute(&self) -> u64 {
        self.binance_requests_per_minute
    }
}
