use std::env;
use tokio::io::BufWriter;
use tokio::net::TcpStream;

pub struct QuestDbConfig {
    pub host: String,
    pub port: u16,
}

impl QuestDbConfig {
    pub fn from_env() -> Self {
        Self {
            host: env::var("QUESTDB_HOST").unwrap_or_else(|_| "localhost".to_string()),
            port: env::var("QUESTDB_PORT")
                .unwrap_or_else(|_| "8812".to_string())
                .parse()
                .unwrap_or(8812),
        }
    }
}

pub async fn connect() -> Result<BufWriter<TcpStream>, std::io::Error> {
    let config = QuestDbConfig::from_env();
    let stream = TcpStream::connect(format!("{}:{}", config.host, config.port)).await?;
    Ok(BufWriter::new(stream))
}
