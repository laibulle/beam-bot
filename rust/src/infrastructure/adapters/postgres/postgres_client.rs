use crate::infrastructure::config::postgres_config::PostgresConfig;
use log::error;
use std::sync::Arc;
use tokio_postgres::{Client, NoTls};

pub struct PostgresClient {
    client: Arc<Client>,
}

impl PostgresClient {
    pub async fn new(config: PostgresConfig) -> Result<Self, tokio_postgres::Error> {
        let (client, connection) =
            tokio_postgres::connect(&config.connection_string(), NoTls).await?;

        // Spawn the connection in the background
        tokio::spawn(async move {
            if let Err(e) = connection.await {
                error!("PostgreSQL connection error: {}", e);
            }
        });

        Ok(Self {
            client: Arc::new(client),
        })
    }

    pub fn get_client(&self) -> Arc<Client> {
        self.client.clone()
    }
}
