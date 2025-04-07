use async_trait::async_trait;
use std::sync::Arc;

#[async_trait]
pub trait PubSub {
    async fn publish(
        &self,
        subject: &str,
        payload: &[u8],
    ) -> Result<(), Box<dyn std::error::Error>>;

    async fn subscribe(
        &self,
        subject: &str,
        handler: Arc<dyn Fn(Vec<u8>) -> Result<(), Box<dyn std::error::Error>> + Send + Sync>,
    ) -> Result<(), Box<dyn std::error::Error>>;
}
