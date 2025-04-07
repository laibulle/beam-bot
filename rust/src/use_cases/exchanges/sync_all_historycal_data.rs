use crate::domain::ports::binance_adapter::{BinanceAdapter, BinanceError};
use crate::domain::ports::klines_repository::KlinesRepository;
use crate::domain::ports::trading_pair_repository::TradingPairRepository;
use crate::infrastructure::adapters::rate_limiter::RateLimiter;

use chrono::{Duration, Utc};
use futures::future::join_all;
use log::{debug, error};
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
}

impl<B: BinanceAdapter, K: KlinesRepository, T: TradingPairRepository>
    SyncAllHistoricalData<B, K, T>
{
    pub fn with_rate_limit(
        binance_client: B,
        klines_repository: K,
        trading_pair_repository: T,
        requests_per_second: u64,
    ) -> Self {
        Self {
            binance_client,
            klines_repository,
            trading_pair_repository,
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

        let total_tasks = trading_pairs.len() * self.intervals.len();
        self.progress.completed_tasks.store(0, Ordering::SeqCst);
        self.progress
            .total_tasks
            .store(total_tasks, Ordering::SeqCst);

        let client = Arc::new(&self.binance_client);
        let repository = Arc::new(&self.klines_repository);
        let trading_pair_repo = Arc::new(&self.trading_pair_repository);

        let futures = trading_pairs.into_iter().flat_map(|pair| {
            let client = Arc::clone(&client);
            let repository = Arc::clone(&repository);
            let trading_pair_repo = Arc::clone(&trading_pair_repo);
            let progress = self.progress.clone();
            let rate_limiter = Arc::clone(&self.rate_limiter);

            self.intervals.iter().map(move |interval_config| {
                let pair = pair.clone();
                let interval = interval_config.interval.clone();
                let client = Arc::clone(&client);
                let repository = Arc::clone(&repository);
                let trading_pair_repo = Arc::clone(&trading_pair_repo);
                let progress = progress.clone();
                let rate_limiter = Arc::clone(&rate_limiter);

                async move {
                    {
                        let mut current_pair = progress.current_pair.lock().await;
                        *current_pair = pair.symbol.clone();
                        let mut current_interval = progress.current_interval.lock().await;
                        *current_interval = interval.clone();
                    }

                    let sync_end_time = Utc::now().timestamp_millis();
                    let mut sync_start_time =
                        sync_end_time - interval_config.duration.num_milliseconds();

                    // Check if we have a previous sync and adjust sync_start_time if needed
                    if let Ok(Some(latest_pair)) =
                        trading_pair_repo.find_by_symbol(&pair.symbol).await
                    {
                        if let Some(latest_end_time) = latest_pair.sync_end_time {
                            if latest_end_time > sync_start_time {
                                sync_start_time = latest_end_time;
                            }
                        }
                    }

                    if sync_start_time >= sync_end_time {
                        debug!(
                            "Skipping sync for {} ({}) - already up to date",
                            pair.symbol, interval
                        );
                        progress.completed_tasks.fetch_add(1, Ordering::SeqCst);
                        return Ok(());
                    }

                    debug!(
                        "Syncing {} data for trading pair: {} ({} to {})",
                        interval, pair.symbol, sync_start_time, sync_end_time
                    );

                    rate_limiter.acquire().await;

                    let result = match client
                        .get_klines(
                            &pair.symbol,
                            &interval,
                            Some(sync_start_time),
                            Some(sync_end_time),
                            None,
                        )
                        .await
                    {
                        Ok(klines) => {
                            debug!(
                                "Successfully fetched {} klines for {} ({})",
                                klines.len(),
                                pair.symbol,
                                interval
                            );
                            if let Err(e) = repository.save_klines(&pair.symbol, &klines).await {
                                error!(
                                    "Failed to save klines for {} ({}): {:?}",
                                    pair.symbol, interval, e
                                );
                                Err(BinanceError::RequestError(format!(
                                    "Failed to save klines: {}",
                                    e
                                )))
                            } else {
                                // Update trading pair sync times
                                let mut updated_pair = pair.clone();
                                if let Some(last_kline) = klines.last() {
                                    updated_pair.sync_end_time = Some(last_kline.close_time);
                                    if updated_pair.sync_start_time.is_none() {
                                        updated_pair.sync_start_time = Some(sync_start_time);
                                    }
                                } else {
                                    // If no klines were received, set default values
                                    updated_pair.sync_start_time = Some(sync_start_time);
                                    updated_pair.sync_end_time = Some(sync_end_time);
                                }
                                if let Err(e) = trading_pair_repo.save(updated_pair).await {
                                    error!(
                                        "Failed to update sync times for {} ({}): {:?}",
                                        pair.symbol, interval, e
                                    );
                                }
                                Ok(())
                            }
                        }
                        Err(e) => {
                            error!(
                                "Failed to fetch klines for {} ({}): {:?}",
                                pair.symbol, interval, e
                            );
                            Err(e)
                        }
                    };

                    progress.completed_tasks.fetch_add(1, Ordering::SeqCst);
                    result
                }
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
}
