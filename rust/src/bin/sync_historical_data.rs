use log::{debug, error, info};
use rustbot::infrastructure::adapters::binance_adapter::BinanceClient;
use rustbot::infrastructure::adapters::postgres::trading_pair_repository_postgres::TradingPairRepositoryPostgres;
use rustbot::infrastructure::adapters::questdb::klines_repository_questdb::KlinesRepositoryQuestDb;
use rustbot::infrastructure::config::binance_config::BinanceConfig;
use rustbot::infrastructure::config::config::Config;
use rustbot::infrastructure::timeseriesdb::connect;
use rustbot::use_cases::exchanges::sync_all_historycal_data::SyncAllHistoricalData;
use rustbot::use_cases::exchanges::sync_trading_pairs::SyncTradingPairsUseCase;
use sqlx::postgres::PgPoolOptions;
use std::io::Write;
use std::sync::atomic::Ordering;
use tokio::time::{sleep, Duration};

#[tokio::main]
async fn main() {
    // Try to load environment variables from .env file, but don't fail if it doesn't exist
    if let Err(e) = dotenv::dotenv().or_else(|_| dotenv::from_filename("../.env")) {
        info!("Failed to load .env file: {:?}", e);
    }

    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    let config = Config::new();

    // Initialize dependencies
    let binance_client = BinanceClient::new(config.clone());
    let questdb_client = match connect().await {
        Ok(client) => client,
        Err(e) => {
            error!("Failed to connect to QuestDB: {:?}", e);
            return;
        }
    };
    let klines_repository = KlinesRepositoryQuestDb::new(questdb_client);

    // Initialize PostgreSQL connection
    let postgres_pool = match PgPoolOptions::new()
        .max_connections(5)
        .connect(&config.postgres_config.connection_string())
        .await
    {
        Ok(pool) => pool,
        Err(e) => {
            error!("Failed to connect to PostgreSQL: {:?}", e);
            return;
        }
    };

    let trading_pair_repository = TradingPairRepositoryPostgres::new(postgres_pool.clone());
    let trading_pair_repository2 = TradingPairRepositoryPostgres::new(postgres_pool);

    // First sync trading pairs
    let sync_trading_pairs_use_case =
        SyncTradingPairsUseCase::new(trading_pair_repository, BinanceClient::new(config.clone()));
    match sync_trading_pairs_use_case.execute().await {
        Ok(_) => info!("Trading pairs sync completed successfully"),
        Err(e) => {
            error!("Error during trading pairs sync: {:?}", e);
            return;
        }
    }

    // Create the use case with rate limiting (1000 requests per minute)
    let sync_use_case = SyncAllHistoricalData::with_rate_limit(
        binance_client,
        klines_repository,
        trading_pair_repository2,
        config.requests_per_minute(),
    );

    // Get progress tracker
    let progress = sync_use_case.get_progress();

    // Start progress display task
    let progress_task = tokio::spawn(async move {
        let mut last_completed = 0;
        let mut last_time = std::time::Instant::now();
        let mut last_speed = 0.0;

        // Wait for the first task to be set
        while progress.total_tasks.load(Ordering::SeqCst) == 0 {
            sleep(Duration::from_millis(100)).await;
        }

        loop {
            let completed = progress.completed_tasks.load(Ordering::SeqCst);
            let total = progress.total_tasks.load(Ordering::SeqCst);
            let current_pair = progress.current_pair.lock().await;
            let current_interval = progress.current_interval.lock().await;

            // Calculate speed
            let now = std::time::Instant::now();
            let time_diff = now.duration_since(last_time).as_secs_f64();
            if time_diff > 0.0 {
                let completed_diff = completed - last_completed;
                last_speed = completed_diff as f64 / time_diff;
                last_completed = completed;
                last_time = now;
            }

            print!(
                "\rProgress: {}/{} ({}%) - Current: {} {} - Speed: {:.2} tasks/s",
                completed,
                total,
                (completed as f64 / total as f64 * 100.0) as u32,
                current_pair,
                current_interval,
                last_speed
            );
            std::io::stdout().flush().unwrap();

            if completed >= total && total > 0 {
                break;
            }

            sleep(Duration::from_millis(100)).await;
        }
        println!("\nSync completed!");
    });

    // Execute the sync
    match sync_use_case.execute().await {
        Ok(_) => info!("Historical data sync completed successfully"),
        Err(e) => error!("Error during historical data sync: {:?}", e),
    }

    // Wait for progress display to complete
    progress_task.await.unwrap();
}
