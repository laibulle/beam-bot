use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, Instant};
use tokio::time::sleep;

pub struct RateLimiter {
    tokens: AtomicU64,
    last_refill: AtomicU64,
    refill_interval: Duration,
    tokens_per_refill: u64,
}

impl RateLimiter {
    pub fn new(requests_per_minute: u64) -> Self {
        let refill_interval = Duration::from_secs(60);
        let tokens_per_refill = requests_per_minute;

        Self {
            tokens: AtomicU64::new(requests_per_minute),
            last_refill: AtomicU64::new(Instant::now().elapsed().as_secs()),
            refill_interval,
            tokens_per_refill,
        }
    }

    pub async fn acquire(&self) {
        loop {
            let now = Instant::now().elapsed().as_secs();
            let last_refill = self.last_refill.load(Ordering::Relaxed);
            let time_passed = now - last_refill;

            if time_passed >= self.refill_interval.as_secs() {
                // Refill tokens
                let new_tokens = self.tokens_per_refill;
                self.tokens.store(new_tokens, Ordering::Relaxed);
                self.last_refill.store(now, Ordering::Relaxed);
            }

            let current_tokens = self.tokens.load(Ordering::Relaxed);
            if current_tokens > 0 {
                if self
                    .tokens
                    .compare_exchange(
                        current_tokens,
                        current_tokens - 1,
                        Ordering::Relaxed,
                        Ordering::Relaxed,
                    )
                    .is_ok()
                {
                    return;
                }
            }

            // Wait for next refill
            sleep(Duration::from_millis(100)).await;
        }
    }
}
