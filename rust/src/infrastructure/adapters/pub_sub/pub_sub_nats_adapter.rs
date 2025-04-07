use crate::domain::ports::pub_sub::PubSub;
use async_nats::Client;
use std::error::Error;

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
}
