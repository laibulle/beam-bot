use crate::domain::ports::pub_sub::PubSub;
use async_nats::Client;
use futures::StreamExt;
use std::error::Error;
use std::sync::Arc;
use tokio::task;

pub struct NatsPubSub {
    client: Client,
}

impl NatsPubSub {
    pub async fn new(url: &str) -> Result<Self, Box<dyn Error>> {
        let client = async_nats::connect(url).await?;
        Ok(Self { client })
    }
}

#[async_trait::async_trait]
impl PubSub for NatsPubSub {
    async fn publish(&self, subject: &str, payload: &[u8]) -> Result<(), Box<dyn Error>> {
        // Convert the references to owned values before passing to NATS
        let subject = subject.to_string();
        let payload = payload.to_vec();

        self.client.publish(subject, payload.into()).await?;
        Ok(())
    }

    async fn subscribe(
        &self,
        subject: &str,
        handler: Arc<dyn Fn(Vec<u8>) -> Result<(), Box<dyn Error>> + Send + Sync>,
    ) -> Result<(), Box<dyn Error>> {
        let subject = subject.to_string();
        let mut subscription = self.client.subscribe(subject).await?;

        // Spawn a task to handle incoming messages
        task::spawn(async move {
            while let Some(message) = subscription.next().await {
                let payload = message.payload.to_vec();
                if let Err(e) = handler(payload) {
                    eprintln!("Error handling message: {}", e);
                }
            }
        });

        Ok(())
    }
}
