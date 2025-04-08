use chrono::Utc;
use rust_decimal::Decimal;
use sqlx::postgres::PgPoolOptions;
use std::str::FromStr;

use rustbot::domain::ports::trading_pair_repository::TradingPairRepository;
use rustbot::domain::trading_pairs::trading_pair::TradingPair;
use rustbot::infrastructure::adapters::postgres::trading_pair_repository_postgres::TradingPairRepositoryPostgres;

async fn setup_db() -> sqlx::PgPool {
    if let Err(e) = dotenv::dotenv().or_else(|_| dotenv::from_filename("../.env")) {
        panic!("Failed to load .env file: {:?}", e);
    }
    let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set for tests");
    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await
        .expect("Failed to create connection pool");

    // Clear the test database before each test
    sqlx::query("DELETE FROM trading_pairs WHERE 1=1")
        .execute(&pool)
        .await
        .expect("Failed to clear test database");

    pool
}

#[tokio::test]
async fn test_save_and_find_by_symbol() {
    let pool = setup_db().await;
    let repo = TradingPairRepositoryPostgres::new(pool);

    // Create a test trading pair
    let trading_pair = TradingPair::new(
        "BTCUSDT".to_string(),
        "BTC".to_string(),
        "USDT".to_string(),
        "TRADING".to_string(),
        true,
        true,
        1,
        Some(Utc::now()),
        None,
        Some(Decimal::from_str("0.01").unwrap()),
        Some(Decimal::from_str("100000").unwrap()),
        Some(Decimal::from_str("0.01").unwrap()),
        Some(Decimal::from_str("0.00001").unwrap()),
        Some(Decimal::from_str("9000").unwrap()),
        Some(Decimal::from_str("0.00001").unwrap()),
        Some(Decimal::from_str("10").unwrap()),
    );

    // Save the trading pair
    repo.save(trading_pair.clone()).await.unwrap();

    // Find the trading pair by symbol
    let found = repo.find_by_symbol("BTCUSDT").await.unwrap();
    assert!(found.is_some());

    let found_pair = found.unwrap();
    assert_eq!(found_pair.symbol, "BTCUSDT");
    assert_eq!(found_pair.base_asset, "BTC");
    assert_eq!(found_pair.quote_asset, "USDT");
    assert_eq!(
        found_pair.min_price,
        Some(Decimal::from_str("0.01").unwrap())
    );
    assert_eq!(
        found_pair.max_price,
        Some(Decimal::from_str("100000").unwrap())
    );
    assert_eq!(found_pair.is_active, true);
    assert_eq!(found_pair.is_margin_trading, true);
    assert_eq!(found_pair.is_spot_trading, true);
    assert_eq!(found_pair.exchange_id, 1);
}

#[tokio::test]
async fn test_save_all_and_find_all() {
    let pool = setup_db().await;
    let repo = TradingPairRepositoryPostgres::new(pool);

    // Create multiple test trading pairs
    let pair1 = TradingPair::new(
        "BTCUSDT".to_string(),
        "BTC".to_string(),
        "USDT".to_string(),
        "TRADING".to_string(),
        true,
        true,
        1,
        Some(Utc::now()),
        None,
        Some(Decimal::from_str("0.01").unwrap()),
        Some(Decimal::from_str("100000").unwrap()),
        Some(Decimal::from_str("0.01").unwrap()),
        Some(Decimal::from_str("0.00001").unwrap()),
        Some(Decimal::from_str("9000").unwrap()),
        Some(Decimal::from_str("0.00001").unwrap()),
        Some(Decimal::from_str("10").unwrap()),
    );

    let pair2 = TradingPair::new(
        "ETHUSDT".to_string(),
        "ETH".to_string(),
        "USDT".to_string(),
        "TRADING".to_string(),
        true,
        true,
        1,
        Some(Utc::now()),
        None,
        Some(Decimal::from_str("0.01").unwrap()),
        Some(Decimal::from_str("10000").unwrap()),
        Some(Decimal::from_str("0.01").unwrap()),
        Some(Decimal::from_str("0.0001").unwrap()),
        Some(Decimal::from_str("1000").unwrap()),
        Some(Decimal::from_str("0.0001").unwrap()),
        Some(Decimal::from_str("10").unwrap()),
    );

    // Save all trading pairs
    repo.save_all(vec![pair1, pair2]).await.unwrap();

    // Find all trading pairs
    let all_pairs = repo.find_all().await.unwrap();
    assert_eq!(all_pairs.len(), 2);

    // Verify we have both pairs
    let symbols: Vec<String> = all_pairs.iter().map(|p| p.symbol.clone()).collect();
    assert!(symbols.contains(&"BTCUSDT".to_string()));
    assert!(symbols.contains(&"ETHUSDT".to_string()));
}

#[tokio::test]
async fn test_update_existing_trading_pair() {
    let pool = setup_db().await;
    let repo = TradingPairRepositoryPostgres::new(pool);

    // Create a test trading pair
    let mut trading_pair = TradingPair::new(
        "BTCUSDT".to_string(),
        "BTC".to_string(),
        "USDT".to_string(),
        "TRADING".to_string(),
        true,
        true,
        1,
        Some(Utc::now()),
        None,
        Some(Decimal::from_str("0.01").unwrap()),
        Some(Decimal::from_str("100000").unwrap()),
        Some(Decimal::from_str("0.01").unwrap()),
        Some(Decimal::from_str("0.00001").unwrap()),
        Some(Decimal::from_str("9000").unwrap()),
        Some(Decimal::from_str("0.00001").unwrap()),
        Some(Decimal::from_str("10").unwrap()),
    );

    // Save the trading pair
    repo.save(trading_pair.clone()).await.unwrap();

    // Update the trading pair and save again
    let mut updated_pair = trading_pair.clone();
    updated_pair.status = "BREAK".to_string();
    updated_pair.is_active = false;
    updated_pair.min_price = Some(Decimal::from_str("0.05").unwrap());

    repo.save(updated_pair).await.unwrap();

    // Find the updated trading pair
    let found = repo.find_by_symbol("BTCUSDT").await.unwrap();
    assert!(found.is_some());

    let found_pair = found.unwrap();
    assert_eq!(found_pair.symbol, "BTCUSDT");
    assert_eq!(found_pair.status, "BREAK");
    assert_eq!(found_pair.is_active, false);
    assert_eq!(
        found_pair.min_price,
        Some(Decimal::from_str("0.05").unwrap())
    );
}

#[tokio::test]
async fn test_find_by_nonexistent_symbol() {
    let pool = setup_db().await;
    let repo = TradingPairRepositoryPostgres::new(pool);

    // Attempt to find a trading pair that doesn't exist
    let result = repo.find_by_symbol("NONEXISTENTPAIR").await.unwrap();
    assert!(result.is_none());
}
