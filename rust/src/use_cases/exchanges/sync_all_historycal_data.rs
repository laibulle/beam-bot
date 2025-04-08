use crate::domain::ports::binance_adapter::{BinanceAdapter, BinanceError, Kline};
use crate::domain::ports::klines_repository::KlinesRepository;
use crate::domain::ports::pub_sub::PubSub;
use crate::domain::ports::trading_pair_repository::TradingPairRepository;
use crate::domain::trading_pairs::trading_pair::TradingPair;
use crate::infrastructure::adapters::rate_limiter::RateLimiter;
use chrono::{DateTime, Duration, TimeZone, Utc};
use futures::future::join_all;
use log::{debug, error};
use serde_json;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;

#[derive(Debug, Clone)]
pub struct IntervalConfig {
    pub interval: String,
    pub duration: Duration,
}

#[derive(Debug, Clone)]
pub struct SyncProgress {
    pub total_tasks: Arc<AtomicUsize>,
    pub completed_tasks: Arc<AtomicUsize>,
    pub current_pair: Arc<tokio::sync::Mutex<String>>,
    pub current_interval: Arc<tokio::sync::Mutex<String>>,
}

pub struct SyncAllHistoricalData<B: BinanceAdapter, K: KlinesRepository, T: TradingPairRepository> {
    binance_client: B,
    klines_repository: K,
    trading_pair_repository: T,
    rate_limiter: Arc<RateLimiter>,
    intervals: Vec<IntervalConfig>,
    progress: SyncProgress,
    pub_sub: Arc<dyn PubSub>,
}

impl<B: BinanceAdapter, K: KlinesRepository, T: TradingPairRepository>
    SyncAllHistoricalData<B, K, T>
{
    pub fn with_rate_limit(
        binance_client: B,
        klines_repository: K,
        trading_pair_repository: T,
        requests_per_second: u64,
        pub_sub: Arc<dyn PubSub>,
    ) -> Self {
        Self {
            binance_client,
            klines_repository,
            trading_pair_repository,
            pub_sub,
            rate_limiter: Arc::new(RateLimiter::new(requests_per_second)),
            intervals: vec![
                IntervalConfig {
                    interval: "1m".to_string(),
                    duration: Duration::days(30),
                },
                IntervalConfig {
                    interval: "1h".to_string(),
                    duration: Duration::days(90),
                },
                IntervalConfig {
                    interval: "4h".to_string(),
                    duration: Duration::days(90),
                },
                IntervalConfig {
                    interval: "1d".to_string(),
                    duration: Duration::days(365),
                },
            ],
            progress: SyncProgress {
                total_tasks: Arc::new(AtomicUsize::new(0)),
                completed_tasks: Arc::new(AtomicUsize::new(0)),
                current_pair: Arc::new(tokio::sync::Mutex::new(String::new())),
                current_interval: Arc::new(tokio::sync::Mutex::new(String::new())),
            },
        }
    }

    pub fn get_progress(&self) -> SyncProgress {
        self.progress.clone()
    }

    pub async fn execute(&self) -> Result<(), BinanceError> {
        debug!("Starting historical data sync for all trading pairs");

        let trading_pairs = self.binance_client.get_trading_pairs().await?;
        debug!("Found {} trading pairs", trading_pairs.len());

        self.initialize_progress(trading_pairs.len());

        let client = Arc::new(&self.binance_client);
        let repository = Arc::new(&self.klines_repository);
        let trading_pair_repo = Arc::new(&self.trading_pair_repository);

        let futures = trading_pairs.into_iter().flat_map(|pair| {
            let client = Arc::clone(&client);
            let repository = Arc::clone(&repository);
            let trading_pair_repo = Arc::clone(&trading_pair_repo);

            self.intervals.iter().map(move |interval_config| {
                self.sync_trading_pair_interval(
                    pair.clone(),
                    interval_config.clone(),
                    Arc::clone(&client),
                    Arc::clone(&repository),
                    Arc::clone(&trading_pair_repo),
                )
            })
        });

        let results = join_all(futures).await;
        let errors: Vec<_> = results.into_iter().filter_map(|r| r.err()).collect();

        if !errors.is_empty() {
            error!("Some trading pairs failed to sync: {:?}", errors);
            return Err(BinanceError::RequestError(
                "Some trading pairs failed to sync".to_string(),
            ));
        }

        debug!("Historical data sync completed");
        Ok(())
    }

    fn initialize_progress(&self, trading_pairs_count: usize) {
        let total_tasks = trading_pairs_count * self.intervals.len();
        self.progress.completed_tasks.store(0, Ordering::SeqCst);
        self.progress
            .total_tasks
            .store(total_tasks, Ordering::SeqCst);
    }

    async fn sync_trading_pair_interval(
        &self,
        pair: TradingPair,
        interval_config: IntervalConfig,
        client: Arc<&B>,
        repository: Arc<&K>,
        trading_pair_repo: Arc<&T>,
    ) -> Result<(), BinanceError> {
        {
            let mut current_pair = self.progress.current_pair.lock().await;
            *current_pair = pair.symbol.clone();
            let mut current_interval = self.progress.current_interval.lock().await;
            *current_interval = interval_config.interval.clone();
        }

        let sync_end_time = Utc::now();
        let sync_start_time = self
            .determine_sync_start_time(
                &pair,
                sync_end_time,
                interval_config.duration,
                trading_pair_repo.as_ref(),
            )
            .await;

        if sync_start_time >= sync_end_time {
            debug!(
                "Skipping sync for {} ({}) - already up to date",
                pair.symbol, interval_config.interval
            );
            self.progress.completed_tasks.fetch_add(1, Ordering::SeqCst);
            return Ok(());
        }

        self.fetch_and_save_klines(
            &pair,
            &interval_config.interval,
            sync_start_time,
            sync_end_time,
            client.as_ref(),
            repository.as_ref(),
            trading_pair_repo.as_ref(),
        )
        .await
    }

    async fn determine_sync_start_time(
        &self,
        pair: &TradingPair,
        sync_end_time: DateTime<Utc>,
        duration: Duration,
        trading_pair_repo: &T,
    ) -> DateTime<Utc> {
        let mut sync_start_time = sync_end_time - duration;

        if let Ok(Some(latest_pair)) = trading_pair_repo.find_by_symbol(&pair.symbol).await {
            if let Some(latest_end_time) = latest_pair.sync_end_time {
                if latest_end_time > sync_start_time {
                    sync_start_time = latest_end_time;
                }
            }
        }

        sync_start_time
    }

    async fn fetch_and_save_klines(
        &self,
        pair: &TradingPair,
        interval: &str,
        sync_start_time: DateTime<Utc>,
        sync_end_time: DateTime<Utc>,
        client: &B,
        repository: &K,
        trading_pair_repo: &T,
    ) -> Result<(), BinanceError> {
        debug!(
            "Syncing {} data for trading pair: {} ({} to {})",
            interval, pair.symbol, sync_start_time, sync_end_time
        );

        self.rate_limiter.acquire().await;

        let klines = client
            .get_klines(
                &pair.symbol,
                interval,
                Some(sync_start_time.timestamp_millis()),
                Some(sync_end_time.timestamp_millis()),
                None,
            )
            .await?;

        debug!(
            "Successfully fetched {} klines for {} ({})",
            klines.len(),
            pair.symbol,
            interval
        );

        self.save_klines_and_update_pair(
            pair,
            interval,
            klines,
            sync_start_time,
            sync_end_time,
            repository,
            trading_pair_repo,
        )
        .await
    }

    async fn save_klines_and_update_pair(
        &self,
        pair: &TradingPair,
        interval: &str,
        klines: Vec<Kline>,
        sync_start_time: DateTime<Utc>,
        sync_end_time: DateTime<Utc>,
        repository: &K,
        trading_pair_repo: &T,
    ) -> Result<(), BinanceError> {
        if let Err(e) = repository
            .save_klines(&pair.symbol, interval, &klines)
            .await
        {
            error!(
                "Failed to save klines for {} ({}): {:?}",
                pair.symbol, interval, e
            );
            return Err(BinanceError::RequestError(format!(
                "Failed to save klines: {}",
                e
            )));
        }

        // Publish message when klines are saved
        let klines_message = serde_json::json!({
            "symbol": pair.symbol,
            "interval": interval
        });
        if let Err(e) = self
            .pub_sub
            .publish(
                "klines:initialized",
                &serde_json::to_vec(&klines_message).unwrap_or_default(),
            )
            .await
        {
            error!(
                "Failed to publish klines saved message for {} ({}): {:?}",
                pair.symbol, interval, e
            );
        }

        // Update trading pair sync times
        let mut updated_pair = pair.clone();
        if let Some(last_kline) = klines.last() {
            updated_pair.sync_end_time =
                Some(Utc.timestamp_millis_opt(last_kline.close_time).unwrap());
            if updated_pair.sync_start_time.is_none() {
                updated_pair.sync_start_time = Some(sync_start_time);
            }
        } else {
            // If no klines were received, set default values
            updated_pair.sync_start_time = Some(sync_start_time);
            updated_pair.sync_end_time = Some(sync_end_time);
        }

        if let Err(e) = trading_pair_repo.save(updated_pair.clone()).await {
            error!(
                "Failed to update sync times for {} ({}): {:?}",
                pair.symbol, interval, e
            );
        } else {
            // Publish message when trading pair is updated
            if let Err(e) = self
                .pub_sub
                .publish(
                    "trading_pairs:initialized",
                    &serde_json::to_vec(&updated_pair).unwrap_or_default(),
                )
                .await
            {
                error!(
                    "Failed to publish trading pair update for {}: {:?}",
                    pair.symbol, e
                );
            }
        }

        self.progress.completed_tasks.fetch_add(1, Ordering::SeqCst);
        Ok(())
    }
}
