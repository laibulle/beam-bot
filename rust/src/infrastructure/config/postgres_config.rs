use serde::Deserialize;
use url::Url;

#[derive(Debug, Deserialize, Clone)]
pub struct PostgresConfig {
    pub host: String,
    pub port: u16,
    pub user: String,
    pub password: String,
    pub dbname: String,
}

impl PostgresConfig {
    pub fn from_url(url: &str) -> Result<Self, String> {
        let parsed = Url::parse(url).map_err(|e| e.to_string())?;

        if parsed.scheme() != "postgres" && parsed.scheme() != "postgresql" {
            return Err("Invalid scheme. Must be postgres:// or postgresql://".to_string());
        }

        let host = parsed.host_str().ok_or("Missing host")?.to_string();
        let port = parsed.port().unwrap_or(5432);
        let user = parsed.username().to_string();
        let password = parsed.password().unwrap_or("").to_string();
        let dbname = parsed.path().trim_start_matches('/').to_string();

        Ok(Self {
            host,
            port,
            user,
            password,
            dbname,
        })
    }

    pub fn connection_string(&self) -> String {
        format!(
            "postgres://{}:{}@{}:{}/{}",
            self.user, self.password, self.host, self.port, self.dbname
        )
    }
}

impl Default for PostgresConfig {
    fn default() -> Self {
        Self {
            host: "localhost".to_string(),
            port: 5432,
            user: "postgres".to_string(),
            password: "postgres".to_string(),
            dbname: "rustbot".to_string(),
        }
    }
}
