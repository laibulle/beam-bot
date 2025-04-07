use async_trait::async_trait;

#[async_trait]
pub trait PubSub {
    async fn publish(
        &self,
        subject: &str,
        payload: &[u8],
    ) -> Result<(), Box<dyn std::error::Error>>;
}
